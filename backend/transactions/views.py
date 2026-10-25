import logging
import math

from django.contrib.auth import get_user_model
from django.db import IntegrityError, transaction as db_transaction
from django.db.models import Count, Exists, OuterRef, Sum
from django.db.models.functions import TruncMonth
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
from .models import Alert, Card, Investigation, Transaction
from .permissions import IsOwnerOrStaff
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


def visible_cards(user):
    """Staff see every card; everyone else only their own."""
    cards = Card.objects.all()
    return cards if user.is_staff else cards.filter(owner=user)


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
        return Response(
            {
                "transaction": TransactionSerializer(txn).data,
                "scoring": {
                    "score": round(result["score"], 6),
                    "flagged": result["flagged"],
                    "threshold": result["threshold"],
                    "reasons": result["reasons"],
                },
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

        return Response({
            "total_spend": float(totals["total"] or 0),
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