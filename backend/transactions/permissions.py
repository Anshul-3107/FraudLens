"""DRF object-level authorization permissions for FraudLens entities."""
from rest_framework.permissions import BasePermission

from .models import Alert, Card, Investigation, Transaction


class IsOwnerOrStaff(BasePermission):
    """Defense-in-depth object-level permission for FraudLens entities.

    Validates that the authenticated user owns the object through its
    explicit domain relationship, or has staff privileges.
    Fails closed for unsupported types or records without an owner.
    """

    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated)

    def has_object_permission(self, request, view, obj):
        user = getattr(request, "user", None)
        if not user or not user.is_authenticated:
            return False

        # Fail closed for any unrecognized or unsupported model/object type
        if not isinstance(obj, (Card, Transaction, Alert, Investigation)):
            return False

        # Staff users have full operational visibility across all supported records
        if user.is_staff:
            return True

        # Resolve the card owner through explicit model relationships
        if isinstance(obj, Card):
            owner = getattr(obj, "owner", None)
        elif isinstance(obj, Transaction):
            card = getattr(obj, "card", None)
            owner = getattr(card, "owner", None) if card else None
        elif isinstance(obj, Alert):
            txn = getattr(obj, "transaction", None)
            card = getattr(txn, "card", None) if txn else None
            owner = getattr(card, "owner", None) if card else None
        elif isinstance(obj, Investigation):
            alert = getattr(obj, "alert", None)
            txn = getattr(alert, "transaction", None) if alert else None
            card = getattr(txn, "card", None) if txn else None
            owner = getattr(card, "owner", None) if card else None
        else:
            # Fail closed for any unrecognized or unsupported model/object type
            return False

        # If the card is orphaned or has no owner, non-staff users cannot access it
        if owner is None:
            return False

        return owner == user


# Aliases for compatibility
IsRecordOwnerOrStaff = IsOwnerOrStaff
IsCardOwnerOrStaff = IsOwnerOrStaff
