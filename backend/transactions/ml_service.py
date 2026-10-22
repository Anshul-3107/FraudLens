"""Live scoring: rebuild one transaction's features from the card's stored history,
score it with the trained models, and explain it if it crosses the threshold.

The feature logic mirrors ml/src/features.py (build_features). If you change one,
change the other, then run `python manage.py verify_scoring`.
"""
import importlib.util
import json
import sys
from functools import lru_cache
from pathlib import Path
from types import SimpleNamespace

import joblib
import numpy as np
import pandas as pd
from django.conf import settings

from .models import Transaction

ML_SRC = Path(settings.BASE_DIR).parent / "ml" / "src"
MIN_HISTORY = 5                 # same cut-off as training: fewer earlier transactions -> neutral values
NO_HISTORY_GAP = 30 * 86400     # same default as training for a card's first transaction
DEFAULT_DISTANCE_KM = 76.0      # training average; used only if coordinates are missing


def _load_module(name, filename):
    """Load a file from ml/src without touching sys.path (ml/src has its own config.py,
    which would clash with this project's config package)."""
    if name in sys.modules:
        return sys.modules[name]
    spec = importlib.util.spec_from_file_location(name, ML_SRC / filename)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


@lru_cache(maxsize=1)
def get_bundle():
    features = _load_module("features", "features.py")    # must load first: explain.py imports it
    explain = _load_module("explain", "explain.py")
    artifacts = Path(settings.ML_ARTIFACTS_DIR)

    iso_path = artifacts / "isolation_forest.joblib"
    model_path = artifacts / "xgb_with_iso.joblib"
    threshold_path = artifacts / "threshold.json"

    for path in (iso_path, model_path, threshold_path):
        if not path.is_file():
            raise FileNotFoundError(f"Missing required ML artifact: {path}")

    iso = joblib.load(iso_path)
    model = joblib.load(model_path)
    try:
        threshold_data = json.loads(threshold_path.read_text(encoding="utf-8"))
        threshold = float(threshold_data["threshold"])
    except (json.JSONDecodeError, KeyError, TypeError, ValueError) as e:
        raise ValueError(f"Invalid threshold artifact {threshold_path}: {e}") from e

    return SimpleNamespace(
        features=features,
        explain=explain,
        iso=iso,
        model=model,
        threshold=threshold,
        if_cols=list(iso.feature_names_in_),
        xgb_cols=list(model.get_booster().feature_names),
    )


def compute_features(*, card, occurred_at, merchant, category, amount, merch_lat=None, merch_long=None):
    """Features for one transaction, using only the card's EARLIER stored transactions."""
    bundle = get_bundle()
    ml = bundle.features
    if occurred_at.tzinfo is None:
        raise ValueError("occurred_at must be timezone-aware")
    if category not in ml.CATEGORIES:
        raise ValueError(f"Unknown category: {category}")

    amt = float(amount)
    t = int(occurred_at.timestamp())

    history = list(
        Transaction.objects.filter(card_id=card.id, occurred_at__lt=occurred_at)
        .order_by("occurred_at")
        .values_list("amount", "occurred_at", "merchant", "category")
    )
    n = len(history)
    amounts = np.array([float(h[0]) for h in history])
    times = np.array([int(h[1].timestamp()) for h in history])
    seen_merchants = {h[2] for h in history}
    seen_categories = {h[3] for h in history}

    if n >= MIN_HISTORY:
        mean = float(amounts.mean())
        std = max(float(np.sqrt(amounts.var(ddof=1))), 1.0)
        zscore = (amt - mean) / std
        ratio = amt / max(mean, 1.0)
    else:
        zscore, ratio = 0.0, 1.0

    coords = (card.home_lat, card.home_long, merch_lat, merch_long)
    if all(c is not None and np.isfinite(c) for c in coords):
        h_lat, h_long, m_lat, m_long = coords
        if -90 <= h_lat <= 90 and -180 <= h_long <= 180 and -90 <= m_lat <= 90 and -180 <= m_long <= 180:
            distance = float(ml.haversine_km(h_lat, h_long, m_lat, m_long))
        else:
            distance = DEFAULT_DISTANCE_KM
    else:
        distance = DEFAULT_DISTANCE_KM

    hour = occurred_at.hour
    return {
        "amt": amt,
        "log_amt": float(np.log1p(amt)),
        "hour": hour,
        "dayofweek": occurred_at.weekday(),
        "is_night": int(hour >= 22 or hour <= 3),
        "category_code": ml.CATEGORIES.index(category),
        "dist_home_merchant_km": distance,
        "amt_zscore": float(zscore),
        "amt_ratio_to_mean": float(ratio),
        "secs_since_last": float(t - times[-1]) if n else float(NO_HISTORY_GAP),
        "txn_count_1h": int((times >= t - 3600).sum()),
        "txn_count_24h": int((times >= t - 86400).sum()),
        "is_new_merchant": int(merchant not in seen_merchants),
        "is_new_category": int(category not in seen_categories),
    }


def score_transaction(*, card, occurred_at, merchant, category, amount, merch_lat=None, merch_long=None):
    """Return {"score", "flagged", "threshold", "reasons", "features"} for one transaction."""
    bundle = get_bundle()
    feats = compute_features(
        card=card, occurred_at=occurred_at, merchant=merchant, category=category,
        amount=amount, merch_lat=merch_lat, merch_long=merch_long,
    )
    row = pd.DataFrame([feats])
    row["iso_score"] = -bundle.iso.score_samples(row[bundle.if_cols])
    X = row[bundle.xgb_cols]
    score = float(bundle.model.predict_proba(X)[0, 1])
    flagged = score >= bundle.threshold
    reasons = bundle.explain.explain(bundle.model, X)[0] if flagged else []
    return {
        "score": score,
        "flagged": flagged,
        "threshold": bundle.threshold,
        "reasons": reasons,
        "features": feats,
    }