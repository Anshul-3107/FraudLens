from decimal import Decimal
import math

from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework import serializers

from .models import Alert, Card, Investigation, Transaction

User = get_user_model()


class RegisterSerializer(serializers.Serializer):
    username = serializers.CharField(max_length=150)
    password = serializers.CharField(write_only=True)
    email = serializers.EmailField(required=False, allow_blank=True)

    def validate_username(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError("Username cannot be blank.")
        if len(value) < 3:
            raise serializers.ValidationError("Username must be at least 3 characters long.")
        if User.objects.filter(username__iexact=value).exists():
            raise serializers.ValidationError("That username is already taken.")
        return value

    def validate_password(self, value):
        try:
            validate_password(value)
        except DjangoValidationError as e:
            raise serializers.ValidationError(list(e.messages))
        return value

    def create(self, validated_data):
        return User.objects.create_user(
            username=validated_data["username"].strip(),
            password=validated_data["password"],
            email=validated_data.get("email", "").strip(),
        )


class CardSerializer(serializers.ModelSerializer):
    class Meta:
        model = Card
        fields = ["id", "label"]


class TransactionSerializer(serializers.ModelSerializer):
    card_label = serializers.CharField(source="card.label", read_only=True)
    has_alert = serializers.BooleanField(read_only=True)

    class Meta:
        model = Transaction
        fields = [
            "id", "trans_ref", "card", "card_label", "occurred_at",
            "merchant", "category", "amount", "source", "currency",
            "txn_type", "has_alert", "merch_lat", "merch_long",
        ]


class TransactionCreateSerializer(serializers.Serializer):
    """Input for POST /api/transactions/. Whether the card belongs to the user is
    checked in the view."""
    card = serializers.IntegerField(required=False, allow_null=True)
    occurred_at = serializers.DateTimeField()
    merchant = serializers.CharField(max_length=255)
    category = serializers.ChoiceField(choices=Transaction.Category.choices)
    amount = serializers.DecimalField(max_digits=12, decimal_places=2, min_value=Decimal("0.01"), max_value=Decimal("10000000.00"))
    merch_lat = serializers.FloatField(required=False, allow_null=True, min_value=-90, max_value=90)
    merch_long = serializers.FloatField(required=False, allow_null=True, min_value=-180, max_value=180)
    trans_ref = serializers.CharField(max_length=64, required=False)
    source = serializers.ChoiceField(
        choices=[
            (Transaction.Source.UPLOAD.value, "User upload"),
            (Transaction.Source.AA_SANDBOX.value, "Account Aggregator sandbox"),
        ],
        default=Transaction.Source.UPLOAD.value,
    )

    def validate_merchant(self, value):
        val = value.strip()
        if not val:
            raise serializers.ValidationError("Merchant cannot be empty.")
        return val

    def validate_merch_lat(self, value):
        import math
        if value is not None and not math.isfinite(value):
            raise serializers.ValidationError("merch_lat must be a finite number.")
        return value

    def validate_merch_long(self, value):
        import math
        if value is not None and not math.isfinite(value):
            raise serializers.ValidationError("merch_long must be a finite number.")
        return value

    def validate_trans_ref(self, value):
        if not value:
            return value
        if Transaction.objects.filter(trans_ref=value).exists():
            raise serializers.ValidationError("A transaction with this reference already exists.")
        return value


class AlertTransactionSerializer(serializers.ModelSerializer):
    card_label = serializers.CharField(source="card.label", read_only=True)

    class Meta:
        model = Transaction
        fields = ["id", "card", "card_label", "occurred_at", "merchant", "category", "amount"]


class AlertSerializer(serializers.ModelSerializer):
    transaction = AlertTransactionSerializer(read_only=True)
    latest_verdict = serializers.SerializerMethodField()

    class Meta:
        model = Alert
        fields = [
            "id", "score", "threshold", "reasons", "status",
            "created_at", "transaction", "latest_verdict",
        ]

    def get_latest_verdict(self, obj):
        investigations = list(obj.investigations.all())   # prefetched, newest first
        return investigations[0].verdict if investigations else None


class InvestigationCreateSerializer(serializers.Serializer):
    verdict = serializers.ChoiceField(choices=Investigation.Verdict.choices)
    notes = serializers.CharField(required=False, allow_blank=True, max_length=2000)


class InvestigationSerializer(serializers.ModelSerializer):
    analyst_name = serializers.CharField(source="analyst.username", read_only=True, default=None)
    merchant = serializers.CharField(source="alert.transaction.merchant", read_only=True)
    amount = serializers.DecimalField(
        source="alert.transaction.amount", max_digits=12, decimal_places=2, read_only=True
    )
    occurred_at = serializers.DateTimeField(source="alert.transaction.occurred_at", read_only=True)

    class Meta:
        model = Investigation
        fields = [
            "id", "alert", "analyst_name", "verdict", "notes", "created_at",
            "merchant", "amount", "occurred_at",
        ]


def _validate_finite_coord(value, name):
    if value is not None and not math.isfinite(value):
        raise serializers.ValidationError(f"{name} must be a finite number.")
    return value


class LinkBankAccountSerializer(serializers.Serializer):
    bank_name = serializers.CharField(required=False, allow_blank=True, default="Primary Bank", max_length=80)
    account_number = serializers.CharField(min_length=4, max_length=32)
    home_lat = serializers.FloatField(required=False, allow_null=True, min_value=-90, max_value=90)
    home_long = serializers.FloatField(required=False, allow_null=True, min_value=-180, max_value=180)

    def validate_bank_name(self, value):
        cleaned = (value or "").strip()
        return cleaned or "Primary Bank"

    def validate_account_number(self, value):
        cleaned = (value or "").strip()
        if len(cleaned) < 4:
            raise serializers.ValidationError("A valid account or card number (at least 4 digits) is required.")
        return cleaned

    def validate_home_lat(self, value):
        return _validate_finite_coord(value, "home_lat")

    def validate_home_long(self, value):
        return _validate_finite_coord(value, "home_long")


class ProcessNotificationSerializer(serializers.Serializer):
    amount = serializers.FloatField(min_value=0.01, max_value=10000000.0)
    merchant = serializers.CharField(required=False, allow_blank=True, default="UPI Merchant", max_length=255)
    category = serializers.CharField(required=False, allow_blank=True, default="misc_pos", max_length=32)
    last4 = serializers.CharField(required=False, allow_blank=True, default="", max_length=16)
    bank_name = serializers.CharField(required=False, allow_blank=True, default="UPI Bank", max_length=60)
    package_name = serializers.CharField(required=False, allow_blank=True, default="", max_length=120)
    occurred_at = serializers.CharField(required=False, allow_null=True, allow_blank=True, max_length=64)
    merch_lat = serializers.FloatField(required=False, allow_null=True, min_value=-90, max_value=90)
    merch_long = serializers.FloatField(required=False, allow_null=True, min_value=-180, max_value=180)
    source = serializers.CharField(required=False, allow_blank=True, default="notification", max_length=20)
    txn_type = serializers.CharField(required=False, allow_blank=True, default="sent", max_length=20)
    currency = serializers.CharField(required=False, allow_blank=True, default="INR", max_length=10)

    def validate_amount(self, value):
        if not math.isfinite(value) or value <= 0:
            raise serializers.ValidationError("A positive numerical amount is required.")
        return value

    def validate_merchant(self, value):
        cleaned = (value or "").strip()
        return cleaned or "UPI Merchant"

    def validate_bank_name(self, value):
        cleaned = (value or "").strip()
        return cleaned or "UPI Bank"

    def validate_last4(self, value):
        digits = "".join(ch for ch in (value or "").strip() if ch.isdigit())
        if digits:
            return digits[-4:]
        return (value or "").strip()[:4]

    def validate_merch_lat(self, value):
        return _validate_finite_coord(value, "merch_lat")

    def validate_merch_long(self, value):
        return _validate_finite_coord(value, "merch_long")

    def validate_currency(self, value):
        cleaned = (value or "INR").strip().upper()
        return cleaned[:10] or "INR"


class RichieChatSerializer(serializers.Serializer):
    message = serializers.CharField(max_length=1000, trim_whitespace=True)
    history = serializers.ListField(required=False, default=list, max_length=12)

    def validate_message(self, value):
        if not value or not value.strip():
            raise serializers.ValidationError("Message cannot be empty.")
        return value.strip()

    def validate_history(self, value):
        sanitized = []
        for turn in value[-6:]:
            if not isinstance(turn, dict):
                continue
            sender = "user" if turn.get("sender") == "user" else "richie"
            text = str(turn.get("text") or "").strip()[:1000]
            if text:
                sanitized.append({"sender": sender, "text": text})
        return sanitized