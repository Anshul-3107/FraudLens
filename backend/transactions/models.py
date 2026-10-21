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


class Transaction(models.Model):
    class Source(models.TextChoices):
        SIMULATED = "simulated", "Simulated (Sparkov dataset)"
        UPLOAD = "upload", "User upload"
        AA_SANDBOX = "aa_sandbox", "Account Aggregator sandbox"

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