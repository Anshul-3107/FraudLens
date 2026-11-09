from django.conf import settings
from django.db import models


class Card(models.Model):
    """A payment card. For the simulated dataset, card_ref is the dataset's card id
    (fake). The owner link is how user accounts see only their own data."""

    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True,
        on_delete=models.SET_NULL, related_name="cards",
    )
    card_ref = models.CharField(max_length=32, unique=True)
    label = models.CharField(max_length=100, blank=True)
    # Home location, used to compute distance-to-merchant at scoring time
    home_lat = models.FloatField(null=True, blank=True)
    home_long = models.FloatField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.label or f"Card {self.card_ref[-4:]}"


class PhoneVerification(models.Model):
    """Stores short-lived hashed OTPs for mobile onboarding."""
    phone_number = models.CharField(max_length=20, db_index=True)
    otp_hash = models.CharField(max_length=128)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_verified = models.BooleanField(default=False)
    attempts = models.IntegerField(default=0)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["phone_number", "is_verified", "expires_at"]),
        ]

    def __str__(self):
        return f"OTP for {self.phone_number} (verified: {self.is_verified})"


class Transaction(models.Model):
    class Source(models.TextChoices):
        SIMULATED = "simulated", "Simulated (Sparkov dataset)"
        UPLOAD = "upload", "User upload"
        AA_SANDBOX = "aa_sandbox", "Account Aggregator sandbox"
        NOTIFICATION = "notification", "Live Notification Auto-capture"

    class Category(models.TextChoices):
        ENTERTAINMENT = "entertainment"
        FOOD_DINING = "food_dining"
        GAS_TRANSPORT = "gas_transport"
        GROCERY_NET = "grocery_net"
        GROCERY_POS = "grocery_pos"
        HEALTH_FITNESS = "health_fitness"
        HOME = "home"
        KIDS_PETS = "kids_pets"
        MISC_NET = "misc_net"
        MISC_POS = "misc_pos"
        PERSONAL_CARE = "personal_care"
        SHOPPING_NET = "shopping_net"
        SHOPPING_POS = "shopping_pos"
        TRAVEL = "travel"

    trans_ref = models.CharField(max_length=64, unique=True)
    card = models.ForeignKey(Card, on_delete=models.CASCADE, related_name="transactions")
    occurred_at = models.DateTimeField(db_index=True)
    merchant = models.CharField(max_length=255)
    category = models.CharField(max_length=20, choices=Category.choices)
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    merch_lat = models.FloatField(null=True, blank=True)
    merch_long = models.FloatField(null=True, blank=True)
    source = models.CharField(max_length=20, choices=Source.choices, default=Source.SIMULATED)
    # Ground truth. Only the simulated dataset has it; real data would not.
    is_fraud_label = models.BooleanField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-occurred_at"]
        indexes = [models.Index(fields=["card", "occurred_at"])]

    def __str__(self):
        return f"{self.merchant} ${self.amount} ({self.trans_ref[:8]})"


class Alert(models.Model):
    class Status(models.TextChoices):
        OPEN = "open", "Open"
        IN_REVIEW = "in_review", "In review"
        RESOLVED = "resolved", "Resolved"

    transaction = models.OneToOneField(Transaction, on_delete=models.CASCADE, related_name="alert")
    score = models.FloatField()
    threshold = models.FloatField()            # threshold in force when the alert was raised
    reasons = models.JSONField(default=list)   # [{"factor", "impact", "text"}, ...]
    status = models.CharField(max_length=12, choices=Status.choices, default=Status.OPEN)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"Alert {self.pk}: score {self.score:.2f} ({self.status})"


class Investigation(models.Model):
    class Verdict(models.TextChoices):
        CONFIRMED_FRAUD = "confirmed_fraud", "Confirmed fraud"
        FALSE_POSITIVE = "false_positive", "False positive"
        NEEDS_INFO = "needs_info", "Needs more information"

    alert = models.ForeignKey(Alert, on_delete=models.CASCADE, related_name="investigations")
    analyst = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL,
        related_name="investigations",
    )
    verdict = models.CharField(max_length=20, choices=Verdict.choices)
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.get_verdict_display()} on alert {self.alert_id}"


class UserBehaviorProfile(models.Model):
    """Stores personalized behavioral statistics and trained isolation model per card.

    Enables progressive graduation:
    - Phase 1 (Txn 1-15): 100% Pretrained Global Model.
    - Phase 2 (Txn 16-50): 85% Global + 15% Early Behavioral Drift.
    - Phase 3 (Txn 51-100): 50% Global + 50% Personal Isolation Forest.
    - Phase 4 (Txn 101+): 30% Global + 70% Mature Personal Model.
    """
    card = models.OneToOneField(Card, on_delete=models.CASCADE, related_name="behavior_profile")
    total_txns = models.IntegerField(default=0)
    avg_amount = models.FloatField(default=0.0)
    std_amount = models.FloatField(default=1.0)
    min_amount = models.FloatField(default=0.0)
    max_amount = models.FloatField(default=0.0)
    top_categories = models.JSONField(default=list)  # list of top category codes/names
    frequent_merchants = models.JSONField(default=list)  # list of frequent merchant strings
    active_hours = models.JSONField(default=list)  # list of active transaction hours [0..23]
    active_days = models.JSONField(default=list)  # [0..6]
    is_model_trained = models.BooleanField(default=False)
    model_artifact_path = models.CharField(max_length=255, blank=True)
    graduation_phase = models.IntegerField(default=1)  # 1, 2, 3, or 4
    last_trained_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"BehaviorProfile for {self.card.label} (txns={self.total_txns}, phase={self.graduation_phase})"
