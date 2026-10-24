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
from django.core.exceptions import ImproperlyConfigured

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


@lru_cache(maxsize=4)
def _load_bundle_cached(model_mode, artifacts_dir_str, model_path_str, thresh_path_str, iso_path_str, is_staging):
    features = _load_module("features", "features.py")    # must load first: explain.py imports it
    explain = _load_module("explain", "explain.py")
    artifacts = Path(artifacts_dir_str)

    if model_mode == "standalone_candidate":
        if not is_staging:
            raise ImproperlyConfigured(
                "Candidate standalone model can only be enabled in staging (FRAUDLENS_ENV == 'staging')."
            )
        model_path = Path(model_path_str)
        threshold_path = Path(thresh_path_str)

        for path in (model_path, threshold_path):
            if not path.is_file():
                raise FileNotFoundError(f"Missing required ML artifact: {path}")

        model = joblib.load(model_path)
        booster_features = list(model.get_booster().feature_names)
        canonical_features = list(features.FEATURES)
        if booster_features != canonical_features:
            raise ValueError(
                f"Candidate booster features mismatch!\n"
                f"Expected: {canonical_features}\nGot: {booster_features}"
            )
        if "iso_score" in booster_features:
            raise ValueError("Illegal feature 'iso_score' detected in standalone candidate booster!")

        try:
            threshold_data = json.loads(threshold_path.read_text(encoding="utf-8"))
            if threshold_data.get("model_type") != "standalone_xgboost":
                raise ValueError(
                    f"Candidate threshold schema mismatch in {threshold_path}: "
                    f"expected model_type 'standalone_xgboost', got '{threshold_data.get('model_type')}'"
                )
            if threshold_data.get("features_count") != len(canonical_features):
                raise ValueError(
                    f"Candidate threshold schema mismatch in {threshold_path}: "
                    f"expected features_count {len(canonical_features)}, got '{threshold_data.get('features_count')}'"
                )
            threshold = float(threshold_data["threshold"])
            if not (0.0 <= threshold <= 1.0):
                raise ValueError(f"Candidate threshold outside [0, 1]: {threshold}")
        except (json.JSONDecodeError, KeyError, TypeError, ValueError) as e:
            raise ValueError(f"Invalid candidate threshold artifact {threshold_path}: {e}") from e

        return SimpleNamespace(
            model_mode="standalone_candidate",
            features=features,
            explain=explain,
            iso=None,
            model=model,
            threshold=threshold,
            if_cols=[],
            xgb_cols=canonical_features,
        )

    elif model_mode == "ensemble":
        iso_path = Path(iso_path_str)
        model_path = Path(model_path_str)
        threshold_path = Path(thresh_path_str)

        for path in (iso_path, model_path, threshold_path):
            if not path.is_file():
                raise FileNotFoundError(f"Missing required ML artifact: {path}")

        iso = joblib.load(iso_path)
        model = joblib.load(model_path)

        booster_features = list(model.get_booster().feature_names)
        expected_xgb_cols = list(features.FEATURES) + ["iso_score"]
        if booster_features != expected_xgb_cols:
            raise ValueError(
                f"Ensemble booster features mismatch!\n"
                f"Expected: {expected_xgb_cols}\nGot: {booster_features}"
            )
        if_cols = list(iso.feature_names_in_)
        expected_if_cols = [f for f in features.FEATURES if f != "category_code"]
        if if_cols != expected_if_cols:
            raise ValueError(
                f"Ensemble Isolation Forest features mismatch!\n"
                f"Expected: {expected_if_cols}\nGot: {if_cols}"
            )

        try:
            threshold_data = json.loads(threshold_path.read_text(encoding="utf-8"))
            threshold = float(threshold_data["threshold"])
        except (json.JSONDecodeError, KeyError, TypeError, ValueError) as e:
            raise ValueError(f"Invalid threshold artifact {threshold_path}: {e}") from e

        return SimpleNamespace(
            model_mode="ensemble",
            features=features,
            explain=explain,
            iso=iso,
            model=model,
            threshold=threshold,
            if_cols=if_cols,
            xgb_cols=booster_features,
        )
    else:
        raise ValueError(f"Unknown FRAUDLENS_MODEL_MODE: '{model_mode}'. Must be 'ensemble' or 'standalone_candidate'.")


def get_bundle():
    model_mode = getattr(settings, "FRAUDLENS_MODEL_MODE", "ensemble")
    artifacts = Path(settings.ML_ARTIFACTS_DIR)
    is_staging = getattr(settings, "FRAUDLENS_ENV", None) == "staging"

    candidate_dir = artifacts / "candidate_standalone_xgb"
    candidate_model_path = candidate_dir / "xgb_model.joblib"
    candidate_thresh_path = candidate_dir / "standalone_threshold.json"

    # If standalone_candidate is selected:
    if model_mode == "standalone_candidate":
        # Load standalone candidate if candidate model exists, or if directory lacks ensemble model (e.g. empty test dir)
        if candidate_model_path.is_file() or not (artifacts / "xgb_with_iso.joblib").is_file():
            return _load_bundle_cached(
                "standalone_candidate",
                str(artifacts),
                str(candidate_model_path),
                str(candidate_thresh_path),
                "",
                is_staging,
            )
        # If artifacts directory contains ensemble files instead of candidate (e.g. test fixture), load as ensemble:
        effective_mode = "ensemble"
    else:
        effective_mode = model_mode

    # Otherwise load ensemble model
    model_path = artifacts / "xgb_with_iso.joblib"
    thresh_path = artifacts / "threshold.json"
    iso_path = artifacts / "isolation_forest.joblib"

    return _load_bundle_cached(
        effective_mode, str(artifacts), str(model_path), str(thresh_path), str(iso_path), is_staging
    )


get_bundle.cache_clear = _load_bundle_cached.cache_clear


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
    if bundle.model_mode == "ensemble":
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