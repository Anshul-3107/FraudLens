from django.contrib import admin

from .models import Alert, Card, Investigation, Transaction


@admin.register(Card)
class CardAdmin(admin.ModelAdmin):
    list_display = ("id", "card_ref", "label", "owner", "created_at")
    search_fields = ("card_ref", "label")


@admin.register(Transaction)
class TransactionAdmin(admin.ModelAdmin):
    list_display = ("trans_ref", "card", "occurred_at", "merchant", "category", "amount", "source")
    list_filter = ("category", "source", "is_fraud_label")
    search_fields = ("trans_ref", "merchant")
    date_hierarchy = "occurred_at"


@admin.register(Alert)
class AlertAdmin(admin.ModelAdmin):
    list_display = ("id", "transaction", "score", "status", "created_at")
    list_filter = ("status",)


@admin.register(Investigation)
class InvestigationAdmin(admin.ModelAdmin):
    list_display = ("id", "alert", "analyst", "verdict", "created_at")
    list_filter = ("verdict",)