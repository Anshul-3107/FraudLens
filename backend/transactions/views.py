import logging
import math
import secrets

from django.conf import settings
from django.contrib.auth import get_user_model
from django.db import IntegrityError, transaction as db_transaction
from django.db.models import Count, Exists, OuterRef, Sum
from django.db.models.functions import TruncMonth
from django.utils import timezone
from django.utils.dateparse import parse_date
from rest_framework import mixins, permissions, status, viewsets
from rest_framework.authtoken.models import Token
from rest_framework.authtoken.views import ObtainAuthToken
from rest_framework.decorators import action
from rest_framework.exceptions import ParseError, ValidationError
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView

from .ingest import ingest_transaction
from .models import Alert, Card, Investigation, PhoneVerification, Transaction, UserBehaviorProfile
from .permissions import IsOwnerOrStaff
from .sms_service import generate_otp_code, hash_otp, send_live_sms
from .serializers import (
    AlertSerializer, CardSerializer, InvestigationCreateSerializer,
    InvestigationSerializer, RegisterSerializer, TransactionCreateSerializer,
    TransactionSerializer,
)

User = get_user_model()
logger = logging.getLogger("fraudlens.security")


# ---------------------------------------------------------------- helpers
def get_client_ip(request):
    """Extract client IP safely from request headers or remote address."""
    xff = request.META.get("HTTP_X_FORWARDED_FOR")
    if xff:
        return xff.split(",")[0].strip()
    return request.META.get("REMOTE_ADDR", "unknown")


def visible_cards(user, request=None):
    """Users only ever see cards that they explicitly own.
    Staff members can view all cards across the system for security auditing and management.
    """
    if not user or not user.is_authenticated:
        return Card.objects.none()
    if user.is_staff:
        return Card.objects.all()
    return Card.objects.filter(owner=user)


def param_int(params, key):
    value = params.get(key)
    if value in (None, ""):
        return None
    try:
        return int(value)
    except ValueError:
        raise ParseError(f"'{key}' must be a whole number.")


def param_float(params, key):
    value = params.get(key)
    if value in (None, ""):
        return None
    try:
        val = float(value)
    except ValueError:
        raise ParseError(f"'{key}' must be a number.")
    if not math.isfinite(val):
        raise ParseError(f"'{key}' must be a finite number.")
    return val


def param_date(params, key):
    value = params.get(key)
    if value in (None, ""):
        return None
    try:
        parsed = parse_date(value)
    except ValueError:
        parsed = None
    if parsed is None:
        raise ParseError(f"'{key}' must be a date like 2020-08-31.")
    return parsed


# ---------------------------------------------------------------- auth
class SendOtpView(APIView):
    """Generates and sends a 6-digit verification code via live SMS."""
    permission_classes = [permissions.AllowAny]
    authentication_classes = []
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "auth_otp_send"

    def post(self, request):
        phone = str(request.data.get("phone", "")).strip()
        if not phone or len(phone) < 10:
            return Response({"error": "A valid mobile phone number is required."}, status=status.HTTP_400_BAD_REQUEST)

        # Invalidate any prior unverified OTPs for this phone number
        PhoneVerification.objects.filter(phone_number=phone, is_verified=False).delete()

        otp = generate_otp_code(6)
        otp_hashed = hash_otp(phone, otp)
        expires_at = timezone.now() + timezone.timedelta(minutes=5)

        PhoneVerification.objects.create(
            phone_number=phone,
            otp_hash=otp_hashed,
            expires_at=expires_at,
        )

        # Dispatch real SMS via configured gateway
        delivery_res = send_live_sms(phone, otp)

        logger.info(
            "OTP dispatched for phone %s from IP %s (channel: %s)",
            phone[:6] + "XXXX",
            get_client_ip(request),
            delivery_res.get("channel"),
        )
        response_data = {
            "detail": "Verification code sent to registered mobile number.",
            "phone": phone,
            "expires_in_seconds": 300,
            "delivery_channel": delivery_res.get("channel", "sms"),
        }
        if getattr(settings, "DEBUG", False):
            response_data["dev_otp"] = otp
            response_data["gateway_message"] = delivery_res.get("message")

        return Response(response_data, status=status.HTTP_200_OK)


class VerifyOtpView(APIView):
    """Verifies the 6-digit OTP and logs in / registers the user."""
    permission_classes = [permissions.AllowAny]
    authentication_classes = []
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "auth_otp_verify"

    def post(self, request):
        phone = str(request.data.get("phone", "")).strip()
        code = str(request.data.get("code", "")).strip()

        if not phone or not code or len(code) != 6:
            return Response({"error": "Phone number and 6-digit code are required."}, status=status.HTTP_400_BAD_REQUEST)

        now = timezone.now()
        record = PhoneVerification.objects.filter(
            phone_number=phone,
            is_verified=False,
            expires_at__gte=now,
        ).first()

        if not record:
            return Response({"error": "Expired or invalid verification code. Please request a new one."}, status=status.HTTP_400_BAD_REQUEST)

        if record.attempts >= 5:
            record.delete()
            return Response({"error": "Too many failed attempts. Code invalidated."}, status=status.HTTP_429_TOO_MANY_REQUESTS)

        expected_hash = hash_otp(phone, code)
        if record.otp_hash != expected_hash:
            record.attempts += 1
            record.save(update_fields=["attempts"])
            return Response({"error": "Incorrect verification code. Please check and retry."}, status=status.HTTP_400_BAD_REQUEST)

        # Mark verified
        record.is_verified = True
        record.save(update_fields=["is_verified"])

        # Authenticate or create user account linked to this phone
        sanitized_username = f"user_{phone.replace('+', '').replace(' ', '')}"[-30:]
        user, created = User.objects.get_or_create(
            username=sanitized_username,
            defaults={"is_active": True},
        )
        token, _ = Token.objects.get_or_create(user=user)

        logger.info(
            "Phone verified successfully: %s -> User '%s' (created=%s)",
            phone[:6] + "XXXX",
            user.username,
            created,
        )

        return Response({
            "token": token.key,
            "username": user.username,
            "phone": phone,
            "is_new_user": created,
        }, status=status.HTTP_200_OK)


class LinkBankAccountView(APIView):
    """Links a real bank account / card to the user's profile."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        account_number = str(request.data.get("account_number", "")).strip()
        bank_name = str(request.data.get("bank_name", "Primary Bank")).strip()
        home_lat = request.data.get("home_lat")
        home_long = request.data.get("home_long")

        if not account_number or len(account_number) < 4:
            return Response({"error": "A valid account or card number (at least 4 digits) is required."}, status=status.HTTP_400_BAD_REQUEST)

        last4 = account_number[-4:]
        card_ref = f"bank_{request.user.id}_{last4}_{secrets.token_hex(3)}"
        label = f"{bank_name} A/c •• {last4}"

        card = Card.objects.create(
            owner=request.user,
            card_ref=card_ref,
            label=label,
            home_lat=float(home_lat) if home_lat is not None else None,
            home_long=float(home_long) if home_long is not None else None,
        )

        logger.info("Bank account linked for user '%s': %s", request.user.username, label)
        return Response(CardSerializer(card).data, status=status.HTTP_201_CREATED)


class RegisterView(APIView):
    permission_classes = [permissions.AllowAny]
    authentication_classes = []
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "auth_register"

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        if not serializer.is_valid():
            logger.warning(
                "Registration rejected from IP %s: %s",
                get_client_ip(request),
                list(serializer.errors.keys()),
            )
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        user = serializer.save()
        token, _ = Token.objects.get_or_create(user=user)
        logger.info(
            "New user registered: username='%s', id=%s from IP %s",
            user.username,
            user.id,
            get_client_ip(request),
        )
        return Response({"token": token.key, "username": user.username}, status=status.HTTP_201_CREATED)


class LoginView(ObtainAuthToken):
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "auth_login"

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        if not serializer.is_valid():
            username = request.data.get("username", "") if isinstance(request.data, dict) else ""
            logger.warning(
                "Failed login attempt for username '%s' from IP %s",
                str(username)[:50],
                get_client_ip(request),
            )
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        user = serializer.validated_data["user"]
        token, _ = Token.objects.get_or_create(user=user)
        logger.info(
            "Successful login for user '%s' (id=%s) from IP %s",
            user.username,
            user.id,
            get_client_ip(request),
        )
        return Response({"token": token.key})


class LogoutView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        user = request.user
        token_deleted = False
        if hasattr(request, "auth") and isinstance(request.auth, Token):
            request.auth.delete()
            token_deleted = True
        elif hasattr(user, "auth_token"):
            try:
                user.auth_token.delete()
                token_deleted = True
            except Token.DoesNotExist:
                pass
        if hasattr(request, "session") and request.session:
            request.session.flush()
        logger.info(
            "User '%s' (id=%s) logged out (token_revoked=%s) from IP %s",
            user.username,
            user.id,
            token_deleted,
            get_client_ip(request),
        )
        return Response({"detail": "Successfully logged out. Token revoked."}, status=status.HTTP_200_OK)


class MeView(APIView):
    def get(self, request):
        user = request.user
        return Response({
            "id": user.id,
            "username": user.username,
            "email": user.email,
            "is_staff": user.is_staff,
            "card_count": visible_cards(user).count(),
        })


# ---------------------------------------------------------------- data
class CardViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = CardSerializer
    permission_classes = [permissions.IsAuthenticated, IsOwnerOrStaff]

    def get_queryset(self):
        return visible_cards(self.request.user).order_by("id")

    @action(detail=True, methods=["get"])
    def behavior_profile(self, request, pk=None):
        """Returns the personalized behavioral profile statistics for the card."""
        card = self.get_object()
        profile, _ = UserBehaviorProfile.objects.get_or_create(card=card)
        return Response({
            "card_id": card.id,
            "card_label": card.label,
            "total_txns": profile.total_txns,
            "graduation_phase": profile.graduation_phase,
            "is_model_trained": profile.is_model_trained,
            "avg_amount": round(profile.avg_amount, 2),
            "std_amount": round(profile.std_amount, 2),
            "min_amount": round(profile.min_amount, 2),
            "max_amount": round(profile.max_amount, 2),
            "top_categories": profile.top_categories,
            "frequent_merchants": profile.frequent_merchants,
            "active_hours": profile.active_hours,
            "active_days": profile.active_days,
            "last_trained_at": profile.last_trained_at,
        })


class TransactionViewSet(
    mixins.ListModelMixin, mixins.RetrieveModelMixin, mixins.CreateModelMixin,
    viewsets.GenericViewSet,
):
    """GET filters: card, category, search (merchant), date_from, date_to,
    min_amount, flagged=true.
    POST: score and store a new transaction (see create)."""
    serializer_class = TransactionSerializer
    permission_classes = [permissions.IsAuthenticated, IsOwnerOrStaff]

    def get_queryset(self):
        p = self.request.query_params
        qs = (
            Transaction.objects.filter(card__in=visible_cards(self.request.user))
            .select_related("card")
            .annotate(has_alert=Exists(Alert.objects.filter(transaction=OuterRef("pk"))))
        )
        if (card := param_int(p, "card")) is not None:
            qs = qs.filter(card_id=card)
        if p.get("category"):
            qs = qs.filter(category=p["category"])
        if search_term := p.get("search"):
            if len(search_term) > 100:
                raise ParseError("'search' query parameter cannot exceed 100 characters.")
            qs = qs.filter(merchant__icontains=search_term)
        d_from = param_date(p, "date_from")
        d_to = param_date(p, "date_to")
        if d_from and d_to and d_from > d_to:
            raise ParseError("'date_from' cannot be later than 'date_to'.")
        if d_from is not None:
            qs = qs.filter(occurred_at__date__gte=d_from)
        if d_to is not None:
            qs = qs.filter(occurred_at__date__lte=d_to)
        if (amount := param_float(p, "min_amount")) is not None:
            qs = qs.filter(amount__gte=amount)
        if p.get("flagged", "").lower() == "true":
            qs = qs.filter(has_alert=True)
        return qs.order_by("-occurred_at")

    def create(self, request, *args, **kwargs):
        """Body: card (id), occurred_at (ISO time with zone, e.g. 2021-01-05T23:30:00Z),
        merchant, category, amount; optional merch_lat, merch_long, trans_ref, source."""
        serializer = TransactionCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        card = visible_cards(request.user).filter(id=data["card"]).first()
        if card is None:
            raise ValidationError({"card": "No card with that id on your account."})

        supplied_ref = data.get("trans_ref")
        try:
            txn, alert, result = ingest_transaction(
                card=card,
                occurred_at=data["occurred_at"],
                merchant=data["merchant"],
                category=data["category"],
                amount=data["amount"],
                merch_lat=data.get("merch_lat"),
                merch_long=data.get("merch_long"),
                source=data["source"],
                trans_ref=supplied_ref,
            )
        except IntegrityError:
            if supplied_ref and Transaction.objects.filter(trans_ref=supplied_ref).exists():
                raise ValidationError({"trans_ref": "A transaction with this reference already exists."})
            raise
        txn.has_alert = alert is not None
        scoring_resp = {
            "score": round(result["score"], 6),
            "flagged": result["flagged"],
            "threshold": result["threshold"],
            "reasons": result["reasons"],
        }
        if "graduation_phase" in result:
            scoring_resp["graduation_phase"] = result["graduation_phase"]
            scoring_resp["weights"] = result.get("weights")
            scoring_resp["global_score"] = round(result.get("global_score", result["score"]), 6)
            scoring_resp["personal_score"] = round(result.get("personal_score", 0.0), 6)

        return Response(
            {
                "transaction": TransactionSerializer(txn).data,
                "scoring": scoring_resp,
                "alert_id": alert.id if alert else None,
            },
            status=status.HTTP_201_CREATED,
        )

    @action(detail=False, methods=["post"])
    def process_notification(self, request):
        """Processes an auto-captured payment notification from Google Pay or PhonePe.

        Body: {
            "amount": float / str,
            "merchant": str,
            "category": str (optional, defaults to inferred or 'misc_pos'),
            "last4": str (optional, extracted from SMS/notification e.g. "9719"),
            "bank_name": str (optional, e.g. "HDFC Bank"),
            "package_name": str (e.g. "com.google.android.apps.nbu.paisa.user"),
            "occurred_at": ISO date string (optional, defaults to now),
            "merch_lat": float (optional),
            "merch_long": float (optional),
        }

        Routing Logic:
        1. Account Matching: Checks if user has a card with matching last4.
           - If matched: assigned to user's registered card -> uses adaptive personal model.
           - If not matched: assigned to an "Unregistered Account" card -> evaluated strictly
             via Universal Global Model, preserving the personal profile from pollution.
        2. Visual Routing:
           - Fraud/Alert -> Routed to Review Section ("Needs Action" / Red Card).
           - Legitimate -> Saved into Transaction History (Green Card).
        """
        raw_amt = request.data.get("amount")
        if raw_amt is None:
            raise ValidationError({"amount": "Amount is required."})
        try:
            amount = float(raw_amt)
            if not math.isfinite(amount) or amount <= 0:
                raise ValueError()
        except ValueError:
            raise ValidationError({"amount": "A positive numerical amount is required."})

        merchant = str(request.data.get("merchant", "UPI Merchant")).strip() or "UPI Merchant"
        category = str(request.data.get("category", "misc_pos")).strip().lower()
        if category not in [c[0] for c in Transaction.Category.choices]:
            category = "misc_pos"

        last4 = str(request.data.get("last4", "")).strip()
        bank_name = str(request.data.get("bank_name", "UPI Bank")).strip()

        # Check for card matching this user
        user_cards = visible_cards(request.user)
        matched_card = None
        if last4:
            matched_card = user_cards.filter(label__icontains=last4).first()
            if not matched_card:
                matched_card = user_cards.filter(card_ref__icontains=last4).first()

        # If no last4 provided, try finding the user's primary/first registered card
        if not matched_card and not last4 and user_cards.exists():
            matched_card = user_cards.first()

        is_registered = matched_card is not None
        if not matched_card:
            # Create/assign an "Unregistered Account" card for this user
            unregistered_label = f"Unregistered {bank_name} •• {last4 if last4 else 'UPI'}"
            card_ref = f"unreg_{request.user.id}_{last4 or 'upi'}_{secrets.token_hex(2)}"
            matched_card, _ = Card.objects.get_or_create(
                owner=request.user,
                label=unregistered_label,
                defaults={"card_ref": card_ref},
            )

        occurred_at_str = request.data.get("occurred_at")
        if occurred_at_str:
            occurred_at = parse_date(occurred_at_str)
            if not occurred_at:
                try:
                    occurred_at = timezone.datetime.fromisoformat(occurred_at_str.replace("Z", "+00:00"))
                except Exception:
                    occurred_at = timezone.now()
        else:
            occurred_at = timezone.now()

        if timezone.is_naive(occurred_at):
            occurred_at = timezone.make_aware(occurred_at, timezone.utc)

        merch_lat = request.data.get("merch_lat")
        merch_long = request.data.get("merch_long")
        source_type = request.data.get("source", "notification").lower()
        txn_source = Transaction.Source.SMS if source_type == "sms" else Transaction.Source.NOTIFICATION
        raw_txn_type = request.data.get("txn_type", "sent").lower()
        txn_type = Transaction.TxnType.RECEIVED if raw_txn_type == "received" else Transaction.TxnType.SENT
        currency = str(request.data.get("currency", "INR")).upper()

        # -------------------------------------------------------------
        # Deduplication Window (Idempotency Check)
        # If the same card, amount, and similar merchant occurred within
        # the past 3 minutes (180s), enrich the existing record instead
        # of recording a duplicate charge.
        # -------------------------------------------------------------
        dedup_window_start = occurred_at - timezone.timedelta(seconds=180)
        dedup_window_end = occurred_at + timezone.timedelta(seconds=180)

        existing_txn = (
            Transaction.objects.filter(
                card__in=user_cards if is_registered else Card.objects.filter(id=matched_card.id),
                amount=amount,
                occurred_at__gte=dedup_window_start,
                occurred_at__lte=dedup_window_end,
            )
            .select_related("card")
            .first()
        )

        if existing_txn:
            logger.info(
                "Deduplication matched: existing txn #%s (%s, %.2f) matches incoming %s",
                existing_txn.id,
                existing_txn.merchant,
                existing_txn.amount,
                txn_source,
            )
            if raw_txn_type == "received" and existing_txn.txn_type != Transaction.TxnType.RECEIVED:
                existing_txn.txn_type = Transaction.TxnType.RECEIVED
                existing_txn.save(update_fields=["txn_type"])

            has_alert = Alert.objects.filter(transaction=existing_txn).exists()
            existing_alert = Alert.objects.filter(transaction=existing_txn).first()
            score = existing_alert.score if existing_alert else 0.05
            flagged = has_alert
            status_lbl = "Needs Action" if flagged else ("Money Received" if existing_txn.txn_type == Transaction.TxnType.RECEIVED else "Safe")

            return Response(
                {
                    "transaction": TransactionSerializer(existing_txn).data,
                    "scoring": {
                        "score": round(score, 6),
                        "flagged": flagged,
                        "threshold": 0.5,
                        "reasons": existing_alert.reasons if existing_alert else [],
                        "is_registered_account": is_registered,
                        "is_duplicate_enriched": True,
                        "routing_destination": "review" if flagged else "history",
                        "card_color": "red" if flagged else "green",
                        "status_label": status_lbl,
                    },
                    "alert_id": existing_alert.id if existing_alert else None,
                },
                status=status.HTTP_200_OK,
            )

        txn, alert, result = ingest_transaction(
            card=matched_card,
            occurred_at=occurred_at,
            merchant=merchant,
            category=category,
            amount=amount,
            merch_lat=float(merch_lat) if merch_lat is not None else None,
            merch_long=float(merch_long) if merch_long is not None else None,
            source=txn_source,
            currency=currency,
            txn_type=txn_type,
        )

        txn.has_alert = alert is not None
        status_lbl = "Needs Action" if result["flagged"] else ("Money Received" if txn_type == Transaction.TxnType.RECEIVED else "Safe")
        scoring_resp = {
            "score": round(result["score"], 6),
            "flagged": result["flagged"],
            "threshold": result["threshold"],
            "reasons": result["reasons"],
            "is_registered_account": is_registered,
            "is_duplicate_enriched": False,
            "routing_destination": "review" if result["flagged"] else "history",
            "card_color": "red" if result["flagged"] else "green",
            "status_label": status_lbl,
        }

        return Response(
            {
                "transaction": TransactionSerializer(txn).data,
                "scoring": scoring_resp,
                "alert_id": alert.id if alert else None,
            },
            status=status.HTTP_201_CREATED,
        )


ALERT_ORDERING = {
    "score": "score", "-score": "-score",
    "created_at": "created_at", "-created_at": "-created_at",
    "occurred_at": "transaction__occurred_at", "-occurred_at": "-transaction__occurred_at",
}


class AlertViewSet(viewsets.ReadOnlyModelViewSet):
    """Filters: status, card, min_score. Ordering: score, created_at,
    occurred_at (prefix with - for descending). Default is newest first."""
    serializer_class = AlertSerializer
    permission_classes = [permissions.IsAuthenticated, IsOwnerOrStaff]

    def get_queryset(self):
        p = self.request.query_params
        qs = (
            Alert.objects.filter(transaction__card__in=visible_cards(self.request.user))
            .select_related("transaction__card")
            .prefetch_related("investigations")
        )
        if p.get("status"):
            qs = qs.filter(status=p["status"])
        if (card := param_int(p, "card")) is not None:
            qs = qs.filter(transaction__card_id=card)
        if (score := param_float(p, "min_score")) is not None:
            qs = qs.filter(score__gte=score)
        ordering = ALERT_ORDERING.get(p.get("ordering", ""), "-transaction__occurred_at")
        return qs.order_by(ordering, "-id")

    @action(detail=True, methods=["post"])
    def investigate(self, request, pk=None):
        """Record a verdict. Body: {"verdict": "confirmed_fraud" | "false_positive" |
        "needs_info", "notes": "..."}"""
        alert = self.get_object()   # 404 if the alert is not on one of the user's cards
        serializer = InvestigationCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        with db_transaction.atomic():
            investigation = Investigation.objects.create(
                alert=alert, analyst=request.user, **serializer.validated_data
            )
            needs_info = investigation.verdict == Investigation.Verdict.NEEDS_INFO
            alert.status = Alert.Status.IN_REVIEW if needs_info else Alert.Status.RESOLVED
            alert.save(update_fields=["status"])
        logger.info(
            "Investigation recorded for Alert #%s by user '%s' (verdict=%s, status=%s)",
            alert.id,
            request.user.username,
            investigation.verdict,
            alert.status,
        )
        return Response(InvestigationSerializer(investigation).data, status=status.HTTP_201_CREATED)


class InvestigationViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = InvestigationSerializer
    permission_classes = [permissions.IsAuthenticated, IsOwnerOrStaff]

    def get_queryset(self):
        return (
            Investigation.objects
            .filter(alert__transaction__card__in=visible_cards(self.request.user))
            .select_related("alert__transaction", "analyst")
            .order_by("-created_at")
        )


# ---------------------------------------------------------------- dashboard
class SummaryView(APIView):
    """Numbers for the dashboard. Optional filters: card, date_from, date_to."""

    def get(self, request):
        p = request.query_params
        txns = Transaction.objects.filter(card__in=visible_cards(request.user))
        if (card := param_int(p, "card")) is not None:
            txns = txns.filter(card_id=card)
        d_from = param_date(p, "date_from")
        d_to = param_date(p, "date_to")
        if d_from and d_to and d_from > d_to:
            raise ParseError("'date_from' cannot be later than 'date_to'.")
        if d_from is not None:
            txns = txns.filter(occurred_at__date__gte=d_from)
        if d_to is not None:
            txns = txns.filter(occurred_at__date__lte=d_to)

        totals = txns.aggregate(total=Sum("amount"), count=Count("id"))
        by_category = (
            txns.values("category").annotate(total=Sum("amount"), count=Count("id")).order_by("-total")
        )
        monthly = (
            txns.annotate(month=TruncMonth("occurred_at"))
            .values("month").annotate(total=Sum("amount"), count=Count("id")).order_by("month")
        )
        alert_status = (
            Alert.objects.filter(transaction__in=txns).values("status").annotate(count=Count("id"))
        )

        has_local = txns.filter(source__in=[Transaction.Source.NOTIFICATION, Transaction.Source.SMS]).exists()
        primary_currency = "INR" if has_local else "USD"

        return Response({
            "total_spend": float(totals["total"] or 0),
            "currency": primary_currency,
            "transaction_count": totals["count"],
            "alerts_by_status": {row["status"]: row["count"] for row in alert_status},
            "by_category": [
                {"category": r["category"], "total": float(r["total"]), "count": r["count"]}
                for r in by_category
            ],
            "monthly": [
                {"month": r["month"].strftime("%Y-%m"), "total": float(r["total"]), "count": r["count"]}
                for r in monthly
            ],
        })


# ---------------------------------------------------------------- exchange rates
class ExchangeRatesView(APIView):
    """Provides cached real-time exchange rates against base USD.

    Refreshes from European Central Bank (Frankfurter API) with fallback to
    reliable benchmark rates, cached for 1 hour to handle network resilience.
    """
    permission_classes = [permissions.AllowAny]
    authentication_classes = []
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "anon"

    _FALLBACK_RATES = {
        "INR": 86.50,
        "USD": 1.0,
        "EUR": 0.92,
        "GBP": 0.79,
        "CAD": 1.38,
        "AUD": 1.54,
        "JPY": 152.0,
    }

    _CACHE_KEY = "fraudlens_exchange_rates_usd"
    _CACHE_TTL_SECONDS = 3600  # 1 hour

    def get(self, request):
        from django.core.cache import cache
        import json
        import urllib.request
        from django.utils import timezone

        cached = cache.get(self._CACHE_KEY)
        if cached:
            return Response(cached)

        # Attempt to fetch live rates from ECB (Frankfurter API)
        rates = dict(self._FALLBACK_RATES)
        source = "fallback"

        try:
            req = urllib.request.Request(
                "https://api.frankfurter.dev/v1/latest?base=USD",
                headers={"User-Agent": "FraudLens-Backend/1.0"},
            )
            with urllib.request.urlopen(req, timeout=3.5) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                live_rates = data.get("rates", {})
                for curr in self._FALLBACK_RATES:
                    if curr == "USD":
                        continue
                    if curr in live_rates:
                        rates[curr] = float(live_rates[curr])
                source = "live_ecb"
        except Exception as exc:
            logger.info("External exchange rate fetch failed (%s); using fallback rates.", exc)

        payload = {
            "base": "USD",
            "rates": rates,
            "source": source,
            "updated_at": timezone.now().isoformat(),
        }

        # Cache payload
        cache.set(self._CACHE_KEY, payload, timeout=self._CACHE_TTL_SECONDS)
        return Response(payload)