"""Candidate Standalone ML Service Module for FraudLens.

Implements standalone single-stage scoring for the XGBoost candidate model
without Isolation Forest or stacking dependencies.

Key Properties:
1. Canonical 14 raw features strictly ordered and validated.
2. Extra features in input dictionary are safely ignored (no leakage).
3. Configurable decision threshold with strict schema validation.
   Validates 'model_type' == 'standalone_xgboost' and 'features_count' == 14.
4. Strictly isolated: does NOT load or modify production artifacts/thresholds.
5. Returns the exact interface expected by backend transaction ingestion:
   {"score": float, "flagged": bool, "threshold": float, "reasons": list, "features": dict}
"""
import json
from functools import lru_cache
from pathlib import Path
import sys
from types import SimpleNamespace

import joblib
import numpy as np
import pandas as pd

CANDIDATE_DIR = Path(__file__).resolve().parent
ML_SRC = CANDIDATE_DIR.parent.parent / "src"
if str(ML_SRC) not in sys.path:
    sys.path.insert(0, str(ML_SRC))
if str(CANDIDATE_DIR) not in sys.path:
    sys.path.insert(0, str(CANDIDATE_DIR))

import candidate_explain
from features import FEATURES, CATEGORIES, haversine_km

DEFAULT_PROPOSED_THRESHOLD = 0.20
MODEL_PATH = CANDIDATE_DIR / "xgb_model.joblib"
STANDALONE_THRESHOLD_PATH = CANDIDATE_DIR / "standalone_threshold.json"


def validate_threshold_config(threshold_data, filepath=None):
    """Validate threshold configuration schema, model_type, and feature count."""
    if not isinstance(threshold_data, dict):
        raise TypeError(f"Threshold configuration must be a JSON object, got {type(threshold_data)}")
        
    if "threshold" not in threshold_data:
        raise KeyError(f"Invalid threshold file schema (missing 'threshold') in {filepath}")
        
    # Strictly validate model_type is present and matches
    model_type = threshold_data.get("model_type")
    if model_type != "standalone_xgboost":
        raise ValueError(
            f"Threshold/model mismatch in {filepath}: expected model_type 'standalone_xgboost', got '{model_type}'"
        )
        
    # Strictly validate features_count is present and matches
    features_count = threshold_data.get("features_count")
    if features_count != len(FEATURES):
        raise ValueError(
            f"Feature count mismatch in {filepath}: expected {len(FEATURES)}, got '{features_count}'"
        )
        
    threshold = float(threshold_data["threshold"])
    if not (0.0 <= threshold <= 1.0):
        raise ValueError(f"Configured threshold outside valid range [0, 1]: {threshold}")
        
    return threshold


@lru_cache(maxsize=1)
def get_candidate_bundle(default_threshold=DEFAULT_PROPOSED_THRESHOLD, custom_threshold_path=None):
    """Load the standalone candidate model and configure operating threshold.
    
    Safety guardrail: Never reads or writes production ml/artifacts/threshold.json.
    """
    if not MODEL_PATH.is_file():
        raise FileNotFoundError(f"Missing candidate model artifact: {MODEL_PATH}")
        
    model = joblib.load(MODEL_PATH)
    booster_features = list(model.get_booster().feature_names)
    
    # Assert feature count and ordering
    if booster_features != FEATURES:
        raise ValueError(
            f"Candidate booster features do not match canonical 14 features!\n"
            f"Booster: {booster_features}\nExpected: {FEATURES}"
        )
    if "iso_score" in booster_features:
        raise ValueError("Illegal feature 'iso_score' detected in candidate booster! Mismatched stacked model.")
    
    threshold = float(default_threshold)
    if custom_threshold_path is not None:
        p = Path(custom_threshold_path)
        if not p.is_file():
            raise FileNotFoundError(f"Custom threshold file not found: {p}")
        try:
            data = json.loads(p.read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            raise ValueError(f"Malformed JSON in threshold file {p}: {e}") from e
        threshold = validate_threshold_config(data, filepath=p)
    elif STANDALONE_THRESHOLD_PATH.is_file():
        try:
            data = json.loads(STANDALONE_THRESHOLD_PATH.read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            raise ValueError(f"Malformed JSON in threshold file {STANDALONE_THRESHOLD_PATH}: {e}") from e
        threshold = validate_threshold_config(data, filepath=STANDALONE_THRESHOLD_PATH)
        
    return SimpleNamespace(
        model=model,
        explain=candidate_explain,
        features_list=list(FEATURES),
        threshold=threshold,
    )


def score_candidate_features(features_input, threshold=None, bundle=None):
    """Score a 14-feature dictionary using standalone candidate XGBoost.
    
    Parameters
    ----------
    features_input : dict or pd.DataFrame
        Dictionary containing at least the 14 canonical features, or DataFrame.
        Extra keys in dict (e.g. metadata or iso_score) are safely ignored.
    threshold : float, optional
        Custom operating threshold. If None, uses bundle.threshold (default 0.20).
    bundle : SimpleNamespace, optional
        Cached candidate bundle.
        
    Returns
    -------
    dict
        {"score": float, "flagged": bool, "threshold": float, "reasons": list, "features": dict}
    """
    if bundle is None:
        bundle = get_candidate_bundle()
        
    effective_threshold = float(threshold if threshold is not None else bundle.threshold)
    if not (0.0 <= effective_threshold <= 1.0):
        raise ValueError(f"Operating threshold outside [0, 1]: {effective_threshold}")
        
    if isinstance(features_input, pd.DataFrame):
        if len(features_input) == 0:
            raise ValueError("Cannot score an empty DataFrame in single-transaction scoring interface.")
        features_dict = features_input.iloc[0].to_dict()
    elif isinstance(features_input, dict):
        features_dict = features_input
    else:
        raise TypeError(f"Expected feature dict or DataFrame, got {type(features_input)}")
        
    # Check for missing features
    missing = [f for f in bundle.features_list if f not in features_dict]
    if missing:
        raise ValueError(f"Features input missing required canonical keys: {missing}")
        
    # Extract strictly the canonical 14 features in exact order (safely ignores any extra features)
    canonical_vals = {f: features_dict[f] for f in bundle.features_list}
    row_df = pd.DataFrame([canonical_vals])
    
    # Assert finite values
    arr = row_df.to_numpy().astype(float)
    if not np.all(np.isfinite(arr)):
        raise ValueError("Non-finite values (NaN/Inf) detected in feature vector!")
        
    # Model scoring
    score = float(bundle.model.predict_proba(row_df[bundle.features_list])[0, 1])
    
    if not np.isfinite(score) or not (0.0 <= score <= 1.0):
        raise ValueError(f"Model prediction score is invalid or outside [0, 1]: {score}")
        
    # Threshold comparison semantics: >= boundary
    flagged = bool(score >= effective_threshold)
    reasons = bundle.explain.explain_candidate(bundle.model, row_df)[0] if flagged else []
    
    return {
        "score": score,
        "flagged": flagged,
        "threshold": effective_threshold,
        "reasons": reasons,
        "features": features_dict,
    }
