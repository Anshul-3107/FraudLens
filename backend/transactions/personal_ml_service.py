"""Personal Adaptive Behavioral Modeling for FraudLens.

Implements progressive graduation from universal pre-trained model to personalized
behavioral profile based on individual user transaction history:

Graduation Phases:
- Phase 1 (Txn 1–15): 100% Pretrained Global Model (Cold-start).
- Phase 2 (Txn 16–50): 85% Global Model + 15% Early Behavioral Statistics Drift.
- Phase 3 (Txn 51–100): 50% Global Model + 50% Personal Isolation Forest.
- Phase 4 (Txn 101+): 30% Global Model + 70% Mature Personal Behavioral Model.
"""
import logging
from collections import Counter
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from django.conf import settings
from django.utils import timezone
from sklearn.ensemble import IsolationForest

from .models import Transaction, UserBehaviorProfile

logger = logging.getLogger("fraudlens.personal_ml")

# Features used for personal Isolation Forest training
PERSONAL_IF_FEATURES = [
    "amt",
    "log_amt",
    "hour",
    "dayofweek",
    "is_night",
    "dist_home_merchant_km",
    "amt_zscore",
    "amt_ratio_to_mean",
    "secs_since_last",
    "txn_count_1h",
    "txn_count_24h",
    "is_new_merchant",
    "is_new_category",
]


def determine_graduation_phase(txn_count: int, has_trained_model: bool) -> tuple[int, float, float]:
    """Returns (phase_number, global_weight, personal_weight) based on transaction count."""
    if txn_count < 16:
        return 1, 1.0, 0.0
    elif txn_count <= 50:
        return 2, 0.85, 0.15
    elif txn_count <= 100:
        if has_trained_model:
            return 3, 0.50, 0.50
        else:
            return 2, 0.85, 0.15
    else:  # txn_count > 100
        if has_trained_model:
            return 4, 0.30, 0.70
        else:
            return 2, 0.85, 0.15


def compute_early_drift_score(profile: UserBehaviorProfile, feats: dict) -> float:
    """Computes anomaly heuristic score (0.0 to 1.0) using early personal statistics (Phase 2)."""
    penalty = 0.0

    # 1. Amount deviation
    amt = feats.get("amt", 0.0)
    if profile.avg_amount > 0:
        ratio = amt / profile.avg_amount
        if ratio > 4.0:
            penalty += 0.4
        elif ratio > 2.5:
            penalty += 0.2
        elif ratio < 0.1 and amt > 100:
            penalty += 0.1

    # 2. Unusual timing
    hour = feats.get("hour", 12)
    if profile.active_hours and hour not in profile.active_hours:
        penalty += 0.25

    # 3. Completely novel merchant / category
    if feats.get("is_new_merchant", 0) == 1:
        penalty += 0.15
    if feats.get("is_new_category", 0) == 1:
        penalty += 0.15

    # 4. Unusual frequency
    if feats.get("txn_count_1h", 0) > 3:
        penalty += 0.2

    return min(max(penalty, 0.0), 1.0)


def score_personal_transaction(card, feats: dict, global_score: float) -> dict:
    """Scores transaction considering both global pre-trained model and user behavioral profile.

    Returns:
        dict: {
            "final_score": float,
            "global_score": float,
            "personal_score": float,
            "global_weight": float,
            "personal_weight": float,
            "phase": int,
            "reasons": list[str]
        }
    """
    profile, _ = UserBehaviorProfile.objects.get_or_create(card=card)
    txn_count = profile.total_txns
    has_model = profile.is_model_trained and bool(profile.model_artifact_path)

    phase, global_weight, personal_weight = determine_graduation_phase(txn_count, has_model)
    personal_score = 0.0
    personal_reasons = []

    # Phase 1: Pure global
    if phase == 1:
        final_score = global_score
    # Phase 2: Early behavioral drift heuristic
    elif phase == 2:
        personal_score = compute_early_drift_score(profile, feats)
        final_score = (global_score * global_weight) + (personal_score * personal_weight)
        if personal_score >= 0.5:
            personal_reasons.append("Deviation from early personal spending baseline")
    # Phase 3 & 4: Personal Isolation Forest model
    else:
        try:
            model_path = Path(profile.model_artifact_path)
            if model_path.is_file():
                personal_iso = joblib.load(model_path)
                df_row = pd.DataFrame([{col: feats[col] for col in PERSONAL_IF_FEATURES}])
                raw_score = -float(personal_iso.score_samples(df_row)[0])
                # Normalize typical isolation score range [-0.2, 0.8] to [0.0, 1.0]
                personal_score = float(np.clip((raw_score - 0.35) / 0.45, 0.0, 1.0))
                final_score = (global_score * global_weight) + (personal_score * personal_weight)
                if personal_score >= 0.6:
                    personal_reasons.append(f"Anomalous pattern detected by personal behavioral model (Phase {phase})")
            else:
                # Model artifact missing, fallback to phase 2
                personal_score = compute_early_drift_score(profile, feats)
                final_score = (global_score * 0.85) + (personal_score * 0.15)
        except Exception as e:
            logger.error("Error executing personal isolation forest: %s", e)
            personal_score = global_score
            final_score = global_score

    final_score = float(np.clip(final_score, 0.0, 1.0))

    return {
        "final_score": final_score,
        "global_score": global_score,
        "personal_score": personal_score,
        "global_weight": global_weight,
        "personal_weight": personal_weight,
        "phase": phase,
        "personal_reasons": personal_reasons,
    }


def update_behavior_profile_online(card, amount: float, occurred_at, merchant: str, category: str):
    """Incrementally updates rolling summary statistics for the card's behavior profile."""
    profile, _ = UserBehaviorProfile.objects.get_or_create(card=card)
    profile.total_txns += 1
    n = profile.total_txns
    amt = float(amount)

    # Welford's algorithm / rolling update for mean and variance
    old_avg = profile.avg_amount
    new_avg = old_avg + (amt - old_avg) / n
    profile.avg_amount = new_avg

    if n == 1:
        profile.min_amount = amt
        profile.max_amount = amt
        profile.std_amount = 1.0
    else:
        profile.min_amount = min(profile.min_amount, amt)
        profile.max_amount = max(profile.max_amount, amt)
        # Approximate std update
        diff_sq = (amt - old_avg) * (amt - new_avg)
        old_var = (profile.std_amount ** 2)
        new_var = ((n - 2) * old_var + diff_sq) / (n - 1) if n > 1 else 1.0
        profile.std_amount = max(float(np.sqrt(max(new_var, 0.0))), 1.0)

    # Active hours
    h = occurred_at.hour
    if h not in profile.active_hours:
        profile.active_hours = sorted(profile.active_hours + [h])

    # Active days
    d = occurred_at.weekday()
    if d not in profile.active_days:
        profile.active_days = sorted(profile.active_days + [d])

    # Frequent merchants
    merchants = profile.frequent_merchants or []
    merchants.append(merchant)
    profile.frequent_merchants = [m for m, _ in Counter(merchants).most_common(20)]

    # Top categories
    categories = profile.top_categories or []
    categories.append(category)
    profile.top_categories = [c for c, _ in Counter(categories).most_common(10)]

    # Update phase status
    has_model = profile.is_model_trained and bool(profile.model_artifact_path)
    phase, _, _ = determine_graduation_phase(profile.total_txns, has_model)
    profile.graduation_phase = phase
    profile.save()


def train_personal_model_for_card(card_id: int) -> dict:
    """Trains a personalized Isolation Forest on the card's historical non-fraud transactions.

    Requires at least 20 historical transactions to train.
    Saves artifact under ml/artifacts/personal/card_<id>_iso.joblib.
    """
    from .ml_service import compute_features
    from .models import Card

    card = Card.objects.get(id=card_id)
    txns = list(
        Transaction.objects.filter(card_id=card.id)
        .exclude(alert__investigations__verdict="confirmed_fraud")
        .order_by("occurred_at")
    )

    if len(txns) < 20:
        return {
            "success": False,
            "error": f"Card has only {len(txns)} transactions. At least 20 are required to train a personal behavioral model.",
        }

    # Extract personal features
    feature_rows = []
    for t in txns:
        f = compute_features(
            card=card,
            occurred_at=t.occurred_at,
            merchant=t.merchant,
            category=t.category,
            amount=t.amount,
            merch_lat=t.merch_lat,
            merch_long=t.merch_long,
        )
        feature_rows.append({col: f[col] for col in PERSONAL_IF_FEATURES})

    df = pd.DataFrame(feature_rows)

    # Train personal Isolation Forest
    iso = IsolationForest(
        n_estimators=100,
        contamination=0.03,
        random_state=42,
        n_jobs=-1,
    )
    iso.fit(df)

    # Save artifact
    artifacts_dir = Path(settings.ML_ARTIFACTS_DIR) / "personal"
    artifacts_dir.mkdir(parents=True, exist_ok=True)
    artifact_path = artifacts_dir / f"card_{card.id}_iso.joblib"
    joblib.dump(iso, artifact_path)

    # Update profile
    profile, _ = UserBehaviorProfile.objects.get_or_create(card=card)
    profile.is_model_trained = True
    profile.model_artifact_path = str(artifact_path)
    profile.last_trained_at = timezone.now()
    profile.graduation_phase = 3 if profile.total_txns <= 100 else 4
    profile.save()

    logger.info("Personal behavioral model trained for card %s (%d txns)", card.label, len(txns))
    return {
        "success": True,
        "card_id": card.id,
        "card_label": card.label,
        "txns_trained": len(txns),
        "artifact_path": str(artifact_path),
        "graduation_phase": profile.graduation_phase,
    }
