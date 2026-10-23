import time
import uuid

from django.db import transaction as db_transaction

from .ml_service import score_transaction
from .models import Alert, Transaction
from .shadow_service import shadow_evaluate_transaction


def ingest_transaction(
    *, card, occurred_at, merchant, category, amount,
    merch_lat=None, merch_long=None,
    source=Transaction.Source.UPLOAD, trans_ref=None, is_fraud_label=None,
):
    """Score a new transaction, store it, and raise an alert if it is flagged.
    Returns (transaction, alert_or_None, scoring_result)."""
    # Scored BEFORE saving, from the card's earlier transactions only.
    t0 = time.perf_counter()
    result = score_transaction(
        card=card, occurred_at=occurred_at, merchant=merchant, category=category,
        amount=amount, merch_lat=merch_lat, merch_long=merch_long,
    )
    prod_latency_ms = (time.perf_counter() - t0) * 1000.0

    with db_transaction.atomic():
        txn = Transaction.objects.create(
            trans_ref=trans_ref or uuid.uuid4().hex,
            card=card,
            occurred_at=occurred_at,
            merchant=merchant,
            category=category,
            amount=amount,
            merch_lat=merch_lat,
            merch_long=merch_long,
            source=source,
            is_fraud_label=is_fraud_label,
        )
        alert = None
        if result["flagged"]:
            alert = Alert.objects.create(
                transaction=txn,
                score=result["score"],
                threshold=result["threshold"],
                reasons=result["reasons"],
            )

    # Isolated shadow evaluation hook (executed strictly post-commit)
    shadow_evaluate_transaction(
        transaction_id=txn.id,
        features=result["features"],
        prod_result=result,
        prod_latency_ms=prod_latency_ms,
    )

    return txn, alert, result