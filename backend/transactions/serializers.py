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
            username=validated_data["username"],
            password=validated_data["password"],
            email=validated_data.get("email", ""),
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
            "merchant", "category", "amount", "source", "has_alert",
        ]


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