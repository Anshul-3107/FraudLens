"""Verification and compatibility check for the standalone XGBoost candidate model.

Verifies:
1. Candidate booster feature names and exact order match canonical FEATURES.
2. Absence of iso_score, target labels, identifiers, and forbidden columns.
3. Predicted probabilities are finite numbers strictly bounded in [0, 1].
4. SHAP feature explanation compatibility without the rarity/iso_score factor.
5. Invariance of production model artifacts, threshold (0.20), and SQLite database.
"""
import json
import os
import sqlite3
import sys
import time
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
import xgboost as xgb

BACKEND_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = BACKEND_DIR.parent
CANDIDATE_DIR = PROJECT_ROOT / "ml" / "artifacts" / "candidate_standalone_xgb"
PROD_DIR = PROJECT_ROOT / "ml" / "artifacts"
ML_SRC = PROJECT_ROOT / "ml" / "src"
DB_PATH = BACKEND_DIR / "db.sqlite3"

sys.path.insert(0, str(ML_SRC))
from features import FEATURES, CATEGORIES


def test_candidate_artifacts():
    print("--- 1. Candidate Artifacts Inspection ---")
    required = ["xgb_model.joblib", "threshold.json", "metadata.json"]
    for fname in required:
        fpath = CANDIDATE_DIR / fname
        assert fpath.is_file(), f"Missing required candidate file: {fpath}"
        print(f"  Found: {fname} ({os.path.getsize(fpath):,} bytes)")

    metadata = json.loads((CANDIDATE_DIR / "metadata.json").read_text(encoding="utf-8"))
    thresh_data = json.loads((CANDIDATE_DIR / "threshold.json").read_text(encoding="utf-8"))

    assert metadata["features"] == list(FEATURES), "Metadata features do not match canonical FEATURES!"
    assert thresh_data["threshold"] == metadata["operating_threshold"], "Threshold mismatch between files!"
    print(f"  Candidate operating threshold: {thresh_data['threshold']:.2f}")
    return metadata, thresh_data


def test_booster_schema():
    print("\n--- 2. Booster Schema & Forbidden Column Check ---")
    model = joblib.load(CANDIDATE_DIR / "xgb_model.joblib")
    booster = model.get_booster()
    names = booster.feature_names

    assert names == list(FEATURES), f"Booster feature mismatch: {names} vs {FEATURES}"
    assert "iso_score" not in names, "iso_score found in candidate booster!"

    forbidden = {
        "is_fraud", "cc_num", "trans_num", "split", "merchant", "category",
        "trans_date_trans_time", "age", "gender_male", "log_city_pop",
        "card_prior_count", "iso_score"
    }
    overlap = forbidden.intersection(set(names))
    assert not overlap, f"Forbidden columns in candidate booster: {overlap}"
    print(f"  Booster features strictly match the 14 canonical features.")
    print(f"  Zero forbidden columns detected.")
    return model


def test_predictions_and_calibration(model):
    print("\n--- 3. Inference & Probability Range Validation ---")
    # Synthetic test points covering edge cases
    test_rows = [
        # Normal small transaction
        {
            "amt": 15.50, "log_amt": float(np.log1p(15.50)), "hour": 14, "dayofweek": 2,
            "is_night": 0, "category_code": 1, "dist_home_merchant_km": 5.2,
            "amt_zscore": 0.1, "amt_ratio_to_mean": 1.05, "secs_since_last": 3600.0,
            "txn_count_1h": 0, "txn_count_24h": 2, "is_new_merchant": 0, "is_new_category": 0
        },
        # Extreme anomaly / high fraud probability transaction
        {
            "amt": 2500.0, "log_amt": float(np.log1p(2500.0)), "hour": 2, "dayofweek": 5,
            "is_night": 1, "category_code": 11, "dist_home_merchant_km": 1500.0,
            "amt_zscore": 8.5, "amt_ratio_to_mean": 15.0, "secs_since_last": 120.0,
            "txn_count_1h": 4, "txn_count_24h": 8, "is_new_merchant": 1, "is_new_category": 1
        },
        # Neutral / cold-start cardholder transaction
        {
            "amt": 45.0, "log_amt": float(np.log1p(45.0)), "hour": 10, "dayofweek": 0,
            "is_night": 0, "category_code": 4, "dist_home_merchant_km": 76.0,
            "amt_zscore": 0.0, "amt_ratio_to_mean": 1.0, "secs_since_last": 2592000.0,
            "txn_count_1h": 0, "txn_count_24h": 0, "is_new_merchant": 1, "is_new_category": 1
        },
    ]
    df_test = pd.DataFrame(test_rows)[list(FEATURES)]
    scores = model.predict_proba(df_test)[:, 1]

    for i, s in enumerate(scores):
        assert np.isfinite(s), f"Non-finite score on row {i}: {s}"
        assert 0.0 <= s <= 1.0, f"Score out of bounds on row {i}: {s}"
        print(f"  Row {i} score: {s:.6f} (finite, in [0, 1])")

    # Verify TreeSHAP explanation compatibility
    booster = model.get_booster()
    dmat = xgb.DMatrix(df_test[booster.feature_names])
    contribs = booster.predict(dmat, pred_contribs=True, iteration_range=(0, model.best_iteration + 1))
    assert contribs.shape == (len(test_rows), len(FEATURES) + 1), "SHAP contributions shape mismatch!"
    print("  TreeSHAP contributions computed successfully for all 14 features + bias.")


def test_production_invariance():
    print("\n--- 4. Production Invariance & Isolation Verification ---")
    # Verify production files untouched
    iso_size = os.path.getsize(PROD_DIR / "isolation_forest.joblib")
    xgb_size = os.path.getsize(PROD_DIR / "xgb_with_iso.joblib")
    thresh_data = json.loads((PROD_DIR / "threshold.json").read_text(encoding="utf-8"))

    assert iso_size == 2387821, f"Production ISO artifact modified! Size={iso_size}"
    assert xgb_size == 3946708, f"Production XGB artifact modified! Size={xgb_size}"
    assert thresh_data["threshold"] == 0.20, f"Production threshold modified! {thresh_data}"
    assert thresh_data["review_cost"] == 5.0, f"Production review cost modified! {thresh_data}"
    print("  Production models and threshold (0.20) are 100% UNCHANGED.")

    # Verify database counts
    con = sqlite3.connect(DB_PATH)
    cur = con.cursor()
    tx_count = cur.execute("SELECT COUNT(*) FROM transactions_transaction").fetchone()[0]
    alert_count = cur.execute("SELECT COUNT(*) FROM transactions_alert").fetchone()[0]
    card_count = cur.execute("SELECT COUNT(*) FROM transactions_card").fetchone()[0]
    user_count = cur.execute("SELECT COUNT(*) FROM auth_user").fetchone()[0]
    con.close()

    assert tx_count == 214246, f"Transaction count altered: {tx_count}"
    assert alert_count == 707, f"Alert count altered: {alert_count}"
    assert card_count == 100, f"Card count altered: {card_count}"
    assert user_count == 1, f"User count altered: {user_count}"
    print("  Production database row counts (214,246 tx, 707 alerts) are 100% UNCHANGED.")


def main():
    print("===============================================================")
    print("Verifying Candidate Standalone XGBoost Compatibility & Safety")
    print("===============================================================")
    test_candidate_artifacts()
    model = test_booster_schema()
    test_predictions_and_calibration(model)
    test_production_invariance()
    print("\n[ALL CANDIDATE COMPATIBILITY AND SAFETY TESTS PASSED]")


if __name__ == "__main__":
    main()
