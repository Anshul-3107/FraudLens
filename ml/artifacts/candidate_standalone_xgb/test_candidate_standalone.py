"""Comprehensive Isolated Test Suite for FraudLens Standalone XGBoost Candidate Path.

Tests:
- Canonical feature names, ordering, and absence of iso_score.
- Unit interval [0, 1] bounds and finite score assertion.
- Threshold boundary conditions (>= semantics, configurable values).
- Flagged and unflagged contract structure compatibility.
- Safe handling of extra features, missing features, and non-finite inputs.
- Empty DataFrame handling (with and without columns) in scoring & explanations.
- Edge-case TreeSHAP attributions (empty, low-contrib, non-finite).
- Invariance of production model artifacts and zero database mutation.
- Score correlation and decision agreement against the production model.
"""
import copy
import hashlib
import json
import sqlite3
import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

import numpy as np
import pandas as pd
import joblib

# Setup paths
CANDIDATE_DIR = Path(__file__).resolve().parent
ML_SRC = CANDIDATE_DIR.parent.parent / "src"
BACKEND_DIR = CANDIDATE_DIR.parent.parent.parent / "backend"
DB_PATH = BACKEND_DIR / "db.sqlite3"

if str(ML_SRC) not in sys.path:
    sys.path.insert(0, str(ML_SRC))
if str(CANDIDATE_DIR) not in sys.path:
    sys.path.insert(0, str(CANDIDATE_DIR))

from features import FEATURES, CATEGORIES
from config import ARTIFACTS, FEATURES_PARQUET
from candidate_service import get_candidate_bundle, score_candidate_features
from candidate_explain import explain_candidate, shap_contribs, CANDIDATE_GROUPS


def get_sha256(filepath):
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()


class CandidateStandaloneTests(unittest.TestCase):
    """Isolated test suite for standalone XGBoost candidate scoring and explanations."""

    @classmethod
    def setUpClass(cls):
        cls.bundle = get_candidate_bundle()
        cls.prod_xgb_path = ARTIFACTS / "xgb_with_iso.joblib"
        cls.prod_iso_path = ARTIFACTS / "isolation_forest.joblib"
        cls.prod_thresh_path = ARTIFACTS / "threshold.json"

        cls.prod_xgb = joblib.load(cls.prod_xgb_path)
        cls.prod_iso = joblib.load(cls.prod_iso_path)

        # Baseline legitimate transaction feature vector
        cls.legit_features = {
            "amt": 42.50,
            "log_amt": float(np.log1p(42.50)),
            "hour": 14,
            "dayofweek": 2,
            "is_night": 0,
            "category_code": CATEGORIES.index("food_dining"),
            "dist_home_merchant_km": 12.4,
            "amt_zscore": 0.15,
            "amt_ratio_to_mean": 1.05,
            "secs_since_last": 18200.0,
            "txn_count_1h": 0,
            "txn_count_24h": 2,
            "is_new_merchant": 0,
            "is_new_category": 0,
        }

        # Baseline suspicious transaction feature vector
        cls.suspicious_features = {
            "amt": 1250.00,
            "log_amt": float(np.log1p(1250.00)),
            "hour": 2,
            "dayofweek": 5,
            "is_night": 1,
            "category_code": CATEGORIES.index("shopping_net"),
            "dist_home_merchant_km": 285.0,
            "amt_zscore": 4.85,
            "amt_ratio_to_mean": 8.50,
            "secs_since_last": 120.0,
            "txn_count_1h": 3,
            "txn_count_24h": 7,
            "is_new_merchant": 1,
            "is_new_category": 1,
        }

    # 1. Feature names and ordering
    def test_01_feature_names_and_ordering(self):
        """Verify booster features match canonical FEATURES in exact order with no iso_score."""
        booster = self.bundle.model.get_booster()
        names = booster.feature_names
        self.assertEqual(len(names), 14)
        self.assertEqual(names, FEATURES)
        self.assertNotIn("iso_score", names)
        self.assertEqual(self.bundle.features_list, FEATURES)

    # 2. Finite scores in unit interval
    def test_02_finite_scores_in_unit_interval(self):
        """Verify scores are finite floats in [0, 1] across normal and extreme feature vectors."""
        for name, feats in [("legit", self.legit_features), ("suspicious", self.suspicious_features)]:
            res = score_candidate_features(feats, bundle=self.bundle)
            score = res["score"]
            self.assertIsInstance(score, float)
            self.assertTrue(np.isfinite(score))
            self.assertGreaterEqual(score, 0.0)
            self.assertLessEqual(score, 1.0)

        # Extreme high spend ($50,000)
        extreme_high = copy.deepcopy(self.suspicious_features)
        extreme_high["amt"] = 50000.0
        extreme_high["log_amt"] = float(np.log1p(50000.0))
        res_high = score_candidate_features(extreme_high, bundle=self.bundle)
        self.assertTrue(0.0 <= res_high["score"] <= 1.0)

    # 3. Threshold behavior and boundary cases
    def test_03_threshold_behavior_and_boundary_cases(self):
        """Verify threshold comparison semantics (>= vs <) and boundary edge cases."""
        # Legit transaction below threshold 0.20
        res_legit = score_candidate_features(self.legit_features, threshold=0.20, bundle=self.bundle)
        self.assertFalse(res_legit["flagged"])
        self.assertEqual(res_legit["reasons"], [])

        # Suspicious transaction exceeds threshold 0.20
        res_susp = score_candidate_features(self.suspicious_features, threshold=0.20, bundle=self.bundle)
        self.assertTrue(res_susp["flagged"])
        self.assertGreater(len(res_susp["reasons"]), 0)

        # Exact boundary: score == threshold must be flagged (>= semantics)
        score_val = res_legit["score"]
        res_exact = score_candidate_features(self.legit_features, threshold=score_val, bundle=self.bundle)
        self.assertTrue(res_exact["flagged"])

        # Boundary: threshold slightly above score must NOT be flagged
        res_above = score_candidate_features(self.legit_features, threshold=score_val + 1e-7, bundle=self.bundle)
        self.assertFalse(res_above["flagged"])

        # Extremes: threshold 0.0 flags everything, threshold 1.0 requires score == 1.0
        res_zero = score_candidate_features(self.legit_features, threshold=0.0, bundle=self.bundle)
        self.assertTrue(res_zero["flagged"])

        res_one = score_candidate_features(self.legit_features, threshold=1.0, bundle=self.bundle)
        self.assertFalse(res_one["flagged"])

        # Invalid threshold outside [0, 1]
        with self.assertRaises(ValueError):
            score_candidate_features(self.legit_features, threshold=1.05, bundle=self.bundle)
        with self.assertRaises(ValueError):
            score_candidate_features(self.legit_features, threshold=-0.01, bundle=self.bundle)

    # 4. Result structures and ingestion interface compatibility
    def test_04_flagged_and_unflagged_result_structures(self):
        """Verify return dictionary matches transaction ingestion requirements exactly."""
        expected_keys = {"score", "flagged", "threshold", "reasons", "features"}

        res_unflagged = score_candidate_features(self.legit_features, threshold=0.20, bundle=self.bundle)
        self.assertEqual(set(res_unflagged.keys()), expected_keys)
        self.assertIsInstance(res_unflagged["score"], float)
        self.assertIs(res_unflagged["flagged"], False)
        self.assertIsInstance(res_unflagged["threshold"], float)
        self.assertEqual(res_unflagged["reasons"], [])
        self.assertIsInstance(res_unflagged["features"], dict)

        res_flagged = score_candidate_features(self.suspicious_features, threshold=0.20, bundle=self.bundle)
        self.assertEqual(set(res_flagged.keys()), expected_keys)
        self.assertIs(res_flagged["flagged"], True)
        self.assertIsInstance(res_flagged["reasons"], list)
        self.assertGreater(len(res_flagged["reasons"]), 0)

        # Structure of each reason dictionary
        for reason in res_flagged["reasons"]:
            self.assertEqual(set(reason.keys()), {"factor", "impact", "text"})
            self.assertIsInstance(reason["factor"], str)
            self.assertIsInstance(reason["impact"], float)
            self.assertIsInstance(reason["text"], str)

    # 5. Explanations without iso_score
    def test_05_explanation_generation_without_iso_score(self):
        """Verify candidate explainability produces only the 6 core business factor groups."""
        reasons_list = explain_candidate(self.bundle.model, self.suspicious_features, top_k=3, min_contrib=0.1)
        self.assertEqual(len(reasons_list), 1)
        reasons = reasons_list[0]

        allowed_factors = set(CANDIDATE_GROUPS.keys())
        self.assertEqual(allowed_factors, {"amount", "time", "category", "velocity", "novelty", "location"})

        for r in reasons:
            self.assertIn(r["factor"], allowed_factors)
            self.assertNotEqual(r["factor"], "rarity")
            self.assertGreaterEqual(r["impact"], 0.1)

    # 6. Empty DataFrames with and without expected columns
    def test_06_empty_dataframe_handling(self):
        """Verify behavior for empty DataFrames both with and without expected columns."""
        # Explanation on empty DataFrame with columns
        df_empty_with_cols = pd.DataFrame(columns=FEATURES)
        self.assertEqual(explain_candidate(self.bundle.model, df_empty_with_cols), [])

        # Explanation on empty DataFrame without columns
        df_empty_no_cols = pd.DataFrame()
        self.assertEqual(explain_candidate(self.bundle.model, df_empty_no_cols), [])

        # Scoring interface on empty DataFrame raises informative ValueError
        with self.assertRaises(ValueError) as ctx1:
            score_candidate_features(df_empty_with_cols, bundle=self.bundle)
        self.assertIn("empty dataframe", str(ctx1.exception).lower())

        with self.assertRaises(ValueError) as ctx2:
            score_candidate_features(df_empty_no_cols, bundle=self.bundle)
        self.assertIn("empty dataframe", str(ctx2.exception).lower())

    # 7. Extra features handling (safe ignore, no leakage)
    def test_07_extra_features_handling(self):
        """Verify extra/metadata columns (e.g. cc_num, trans_num, iso_score) are safely ignored."""
        features_with_extras = copy.deepcopy(self.legit_features)
        features_with_extras["cc_num"] = 1234567890123456
        features_with_extras["trans_num"] = "txn_abc123"
        features_with_extras["iso_score"] = 0.99  # Stacked feature should be safely ignored
        features_with_extras["unrelated_debug_field"] = "debug_value"

        res = score_candidate_features(features_with_extras, bundle=self.bundle)
        self.assertTrue(np.isfinite(res["score"]))
        # Compare with pure features
        res_pure = score_candidate_features(self.legit_features, bundle=self.bundle)
        self.assertAlmostEqual(res["score"], res_pure["score"], places=10)

    # 8. Missing features and non-finite inputs
    def test_08_missing_and_invalid_inputs(self):
        """Verify informative errors on missing features, NaNs, and Infs."""
        # Missing feature
        bad_feats = copy.deepcopy(self.legit_features)
        del bad_feats["amt_zscore"]
        with self.assertRaises(ValueError) as ctx:
            score_candidate_features(bad_feats, bundle=self.bundle)
        self.assertIn("missing required canonical keys", str(ctx.exception).lower())

        # Non-dict/non-DataFrame input
        with self.assertRaises(TypeError):
            score_candidate_features("invalid_string_input", bundle=self.bundle)

        # NaN input
        nan_feats = copy.deepcopy(self.legit_features)
        nan_feats["dist_home_merchant_km"] = np.nan
        with self.assertRaises(ValueError) as ctx:
            score_candidate_features(nan_feats, bundle=self.bundle)
        self.assertIn("non-finite", str(ctx.exception).lower())

        # +Inf input
        inf_feats = copy.deepcopy(self.legit_features)
        inf_feats["amt"] = np.inf
        with self.assertRaises(ValueError) as ctx:
            score_candidate_features(inf_feats, bundle=self.bundle)
        self.assertIn("non-finite", str(ctx.exception).lower())

    # 9. TreeSHAP empty, malformed, or non-finite results
    def test_09_shap_malformed_and_edge_cases(self):
        """Verify explainability handles empty contributions, non-finite values, and malformed outputs."""
        # Non-finite values in explanation input
        nan_df = pd.DataFrame([self.legit_features])
        nan_df.loc[0, "amt"] = np.nan
        with self.assertRaises(ValueError):
            explain_candidate(self.bundle.model, nan_df)

        # High min_contrib threshold filters all reasons cleanly
        reasons_high_filter = explain_candidate(
            self.bundle.model, self.suspicious_features, top_k=3, min_contrib=100.0
        )
        self.assertEqual(reasons_high_filter, [[]])

        # top_k = 0 returns empty list of reasons
        reasons_zero_k = explain_candidate(
            self.bundle.model, self.suspicious_features, top_k=0, min_contrib=0.1
        )
        self.assertEqual(reasons_zero_k, [[]])

        # Mocking booster predict returning non-finite SHAP values
        with patch.object(self.bundle.model.get_booster(), "predict", return_value=np.array([[np.nan] * 15])):
            with self.assertRaises(ValueError) as ctx:
                explain_candidate(self.bundle.model, self.suspicious_features)
            self.assertIn("non-finite", str(ctx.exception).lower())

    # 10. Malformed model output detection
    def test_10_malformed_model_output_detection(self):
        """Verify candidate service raises ValueError if model outputs score outside [0, 1] or NaN."""
        # Mocking model predict_proba to return NaN
        with patch.object(self.bundle.model, "predict_proba", return_value=np.array([[0.5, np.nan]])):
            with self.assertRaises(ValueError) as ctx:
                score_candidate_features(self.legit_features, bundle=self.bundle)
            self.assertIn("invalid or outside [0, 1]", str(ctx.exception).lower())

        # Mocking model predict_proba to return out-of-bounds score (1.25)
        with patch.object(self.bundle.model, "predict_proba", return_value=np.array([[-0.25, 1.25]])):
            with self.assertRaises(ValueError) as ctx:
                score_candidate_features(self.legit_features, bundle=self.bundle)
            self.assertIn("invalid or outside [0, 1]", str(ctx.exception).lower())

    # 11. Zero database mutations and production artifact invariance
    def test_11_zero_database_mutations_and_artifact_invariance(self):
        """Verify candidate scoring executes in-memory without database writes or artifact mutation."""
        # Record pre-execution DB counts
        con = sqlite3.connect(DB_PATH)
        cur = con.cursor()
        tables = ["transactions_transaction", "transactions_alert", "transactions_card", "auth_user"]
        before_counts = {t: cur.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0] for t in tables}
        con.close()

        # Record pre-execution production artifact hashes
        before_hashes = {
            "prod_xgb": get_sha256(self.prod_xgb_path),
            "prod_iso": get_sha256(self.prod_iso_path),
            "prod_thresh": get_sha256(self.prod_thresh_path),
        }

        # Execute multiple scorings
        for _ in range(50):
            _ = score_candidate_features(self.legit_features, bundle=self.bundle)
            _ = score_candidate_features(self.suspicious_features, bundle=self.bundle)

        # Check post-execution DB counts
        con = sqlite3.connect(DB_PATH)
        cur = con.cursor()
        after_counts = {t: cur.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0] for t in tables}
        con.close()
        self.assertEqual(before_counts, after_counts, "Database table row counts mutated during scoring!")

        # Check post-execution production artifact hashes
        after_hashes = {
            "prod_xgb": get_sha256(self.prod_xgb_path),
            "prod_iso": get_sha256(self.prod_iso_path),
            "prod_thresh": get_sha256(self.prod_thresh_path),
        }
        self.assertEqual(before_hashes, after_hashes, "Production model artifacts mutated during candidate scoring!")

    # 12. Score correlation and decision agreement against production model
    def test_12_score_correlation_and_decision_agreement(self):
        """Measure score correlation and decision agreement against production on test fixture."""
        df_test = pd.read_parquet(FEATURES_PARQUET)
        sample = df_test[df_test["split"] == "test"].head(300).copy()

        # Candidate scores
        cand_scores = self.bundle.model.predict_proba(sample[FEATURES])[:, 1]

        # Production scores
        if_cols = [f for f in FEATURES if f != "category_code"]
        iso_scores = -self.prod_iso.score_samples(sample[if_cols])
        sample_prod = sample[FEATURES].copy()
        sample_prod["iso_score"] = iso_scores
        xgb_iso_cols = FEATURES + ["iso_score"]
        prod_scores = self.prod_xgb.predict_proba(sample_prod[xgb_iso_cols])[:, 1]

        # Pearson correlation
        corr = float(np.corrcoef(cand_scores, prod_scores)[0, 1])
        self.assertGreater(corr, 0.95, f"Score correlation between candidate and prod is low: {corr:.4f}")

        # Decision agreement at threshold 0.20
        agree = float(np.mean((cand_scores >= 0.20) == (prod_scores >= 0.20)))
        self.assertGreater(agree, 0.95, f"Decision agreement at 0.20 is below 95%: {agree:.2%}")


if __name__ == "__main__":
    unittest.main()
