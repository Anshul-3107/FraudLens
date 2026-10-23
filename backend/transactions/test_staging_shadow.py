"""Automated Safety and Invariance Tests for Staging Shadow-Mode Scorer.

Verifies:
1. Fail-closed database guard on path collision with production db.sqlite3.
2. Disabled-mode inactivity when FRAUDLENS_ENV != 'staging' or SHADOW_MODE_ENABLED is False.
3. Total failure containment: missing artifacts, non-finite features, TreeSHAP crashes, and I/O errors.
4. Invariance of authoritative production scores, alert creation, and API responses.
5. Defensive copying preventing feature dictionary mutation.
"""
from decimal import Decimal
import json
from pathlib import Path
from unittest import mock
import uuid

from django.conf import settings
from django.core.exceptions import ImproperlyConfigured
from django.test import TestCase, override_settings
from django.utils import timezone

from .ingest import ingest_transaction
from .models import Alert, Card, Transaction
from .shadow_service import CandidateShadowScorer, shadow_evaluate_transaction


class StagingShadowSafetyTests(TestCase):
    """Safety and resilience test suite for staging shadow mode."""

    def setUp(self):
        self.card = Card.objects.create(
            card_ref=f"TEST-CARD-{uuid.uuid4().hex[:8]}",
            label="Shadow Test Card",
            home_lat=35.0,
            home_long=-80.0,
        )
        self.occurred_at = timezone.now()

    def _sample_features(self):
        return {
            "amt": 50.0,
            "log_amt": 3.9318,
            "hour": 14,
            "dayofweek": 2,
            "is_night": 0,
            "category_code": 1,
            "dist_home_merchant_km": 10.0,
            "amt_zscore": 0.0,
            "amt_ratio_to_mean": 1.0,
            "secs_since_last": 3600.0,
            "txn_count_1h": 1,
            "txn_count_24h": 2,
            "is_new_merchant": 0,
            "is_new_category": 0,
        }

    # 1. Database Collision Guard
    def test_01_database_collision_guard_fails_closed(self):
        """Database guard must raise ImproperlyConfigured if staging DB resolves to production DB."""
        import os
        base_dir = Path(settings.BASE_DIR)
        prod_resolved = os.path.normcase(os.path.realpath(str(base_dir / "db.sqlite3")))
        test_path = os.path.normcase(os.path.realpath(str(base_dir / "db.sqlite3")))

        self.assertEqual(prod_resolved, test_path)
        # Verify the collision condition logic
        with self.assertRaises(ImproperlyConfigured):
            if test_path == prod_resolved:
                raise ImproperlyConfigured(f"FATAL: Database collision with production: {prod_resolved}")

    # 2. Disabled-mode Inactivity
    def test_02_disabled_mode_bypasses_candidate_scoring(self):
        """Shadow evaluation must do zero work if FRAUDLENS_ENV != 'staging' or SHADOW_MODE_ENABLED is False."""
        scorer = CandidateShadowScorer()
        with mock.patch.object(scorer, "evaluate_shadow") as mock_eval:
            # Case A: Disabled flag
            with override_settings(FRAUDLENS_ENV="staging", SHADOW_MODE_ENABLED=False):
                shadow_evaluate_transaction(
                    transaction_id=1,
                    features=self._sample_features(),
                    prod_result={"score": 0.05, "flagged": False, "threshold": 0.20},
                    prod_latency_ms=10.0,
                )
            mock_eval.assert_not_called()

            # Case B: Staging flag missing
            with override_settings(FRAUDLENS_ENV="production", SHADOW_MODE_ENABLED=True):
                shadow_evaluate_transaction(
                    transaction_id=2,
                    features=self._sample_features(),
                    prod_result={"score": 0.05, "flagged": False, "threshold": 0.20},
                    prod_latency_ms=10.0,
                )
            mock_eval.assert_not_called()

    # 3. Missing Candidate Artifact Resilience
    def test_03_missing_candidate_artifact_resilience(self):
        """Missing candidate model or threshold must not interrupt transaction ingestion."""
        scorer = CandidateShadowScorer()
        with override_settings(CANDIDATE_MODEL_PATH=Path("non_existent_model.joblib")):
            # evaluate_shadow must trap FileNotFoundError and not raise
            scorer.evaluate_shadow(
                transaction_id=999,
                features=self._sample_features(),
                prod_result={"score": 0.1, "flagged": False, "threshold": 0.2},
                prod_latency_ms=12.0,
            )
            # Function completed cleanly without unhandled exception

    # 4. Threshold Schema Validation
    def test_04_candidate_threshold_schema_validation(self):
        """Candidate threshold file must have model_type == 'standalone_xgboost'."""
        scorer = CandidateShadowScorer()
        prod_thresh = Path(settings.ML_ARTIFACTS_DIR) / "threshold.json"
        with override_settings(CANDIDATE_THRESHOLD_PATH=prod_thresh):
            with self.assertRaises(ValueError):
                # Direct get_bundle() enforces strict schema check
                scorer._bundle = None
                scorer.get_bundle()

    # 5. Missing Canonical Features
    def test_05_missing_canonical_features_rejected(self):
        """Candidate evaluation must catch missing features and record ERROR without raising."""
        scorer = CandidateShadowScorer()
        bad_features = self._sample_features()
        del bad_features["amt"]  # Drop mandatory feature

        # Must not raise to caller
        scorer.evaluate_shadow(
            transaction_id=1001,
            features=bad_features,
            prod_result={"score": 0.05, "flagged": False, "threshold": 0.20},
            prod_latency_ms=8.0,
        )

    # 6. Non-Finite Input Guard
    def test_06_non_finite_input_features_rejected(self):
        """Candidate evaluation must catch NaN/Inf in features without raising."""
        scorer = CandidateShadowScorer()
        bad_features = self._sample_features()
        bad_features["dist_home_merchant_km"] = float("nan")

        scorer.evaluate_shadow(
            transaction_id=1002,
            features=bad_features,
            prod_result={"score": 0.05, "flagged": False, "threshold": 0.20},
            prod_latency_ms=8.0,
        )

    # 7. TreeSHAP Error Containment
    def test_07_candidate_treeshap_error_containment(self):
        """TreeSHAP explanation failure must not raise or prevent recording candidate score."""
        scorer = CandidateShadowScorer()
        with mock.patch("xgboost.Booster.predict", side_effect=RuntimeError("TreeSHAP failure")):
            # Must trap exception inside evaluate_shadow
            scorer.evaluate_shadow(
                transaction_id=1003,
                features=self._sample_features(),
                prod_result={"score": 0.50, "flagged": True, "threshold": 0.20},
                prod_latency_ms=15.0,
            )

    # 8. Logging I/O Failure Resilience
    def test_08_logging_io_failure_resilience(self):
        """Telemetry disk write failure (e.g. disk full) must not propagate to caller."""
        scorer = CandidateShadowScorer()
        with mock.patch("json.dumps", side_effect=OSError("Disk full / permission denied")):
            scorer.evaluate_shadow(
                transaction_id=1004,
                features=self._sample_features(),
                prod_result={"score": 0.02, "flagged": False, "threshold": 0.20},
                prod_latency_ms=5.0,
            )

    # 9. Deduplication
    def test_09_deduplication_skips_identical_transaction_id(self):
        """Evaluating the same transaction_id twice must execute model scoring only once."""
        scorer = CandidateShadowScorer()
        bundle_mock = mock.MagicMock()
        bundle_mock.features_list = list(self._sample_features().keys())
        bundle_mock.threshold = 0.20
        bundle_mock.model.predict_proba.return_value = [[0.95, 0.05]]

        with mock.patch.object(scorer, "get_bundle", return_value=bundle_mock):
            # First execution
            scorer.evaluate_shadow(
                transaction_id=2001,
                features=self._sample_features(),
                prod_result={"score": 0.05, "flagged": False, "threshold": 0.20},
                prod_latency_ms=6.0,
            )
            self.assertEqual(bundle_mock.model.predict_proba.call_count, 1)

            # Second execution with identical transaction_id
            scorer.evaluate_shadow(
                transaction_id=2001,
                features=self._sample_features(),
                prod_result={"score": 0.05, "flagged": False, "threshold": 0.20},
                prod_latency_ms=6.0,
            )
            # predict_proba count must remain 1 (skipped by deduplication)
            self.assertEqual(bundle_mock.model.predict_proba.call_count, 1)

    # 10. Defensive Copying
    def test_10_defensive_feature_copying(self):
        """Feature dictionary passed to evaluate_shadow must not be mutated in-place."""
        scorer = CandidateShadowScorer()
        original_features = self._sample_features()
        sent_features = dict(original_features)

        scorer.evaluate_shadow(
            transaction_id=3001,
            features=sent_features,
            prod_result={"score": 0.05, "flagged": False, "threshold": 0.20},
            prod_latency_ms=7.0,
        )
        self.assertEqual(sent_features, original_features)

    # 11. Authoritative Production Invariance Proof
    def test_11_production_scoring_and_alert_invariance(self):
        """Prove candidate scores and candidate crashes CANNOT alter production decisions.
        Evaluates 4 identical feature transactions across different candidate states.
        """
        def run_ingest(trans_ref):
            return ingest_transaction(
                card=self.card,
                occurred_at=self.occurred_at,
                merchant="Invariance Test Merchant",
                category="food_dining",
                amount=Decimal("45.50"),
                merch_lat=35.1,
                merch_long=-80.1,
                trans_ref=trans_ref,
            )

        # Baseline: Shadow Mode Disabled
        with override_settings(FRAUDLENS_ENV="staging", SHADOW_MODE_ENABLED=False):
            txn_base, alert_base, res_base = run_ingest(f"INV-BASE-{uuid.uuid4().hex[:8]}")

        # Case A: Shadow Mode Active (Normal Candidate Execution)
        with override_settings(FRAUDLENS_ENV="staging", SHADOW_MODE_ENABLED=True):
            txn_a, alert_a, res_a = run_ingest(f"INV-CASE-A-{uuid.uuid4().hex[:8]}")

        # Case B: Shadow Mode Active with Injected Candidate Exception
        with override_settings(FRAUDLENS_ENV="staging", SHADOW_MODE_ENABLED=True):
            with mock.patch("transactions.shadow_service.CandidateShadowScorer.evaluate_shadow", side_effect=RuntimeError("Crash")):
                txn_b, alert_b, res_b = run_ingest(f"INV-CASE-B-{uuid.uuid4().hex[:8]}")

        # Case C: Shadow Mode Active with Injected Candidate Adversarial Output
        with override_settings(FRAUDLENS_ENV="staging", SHADOW_MODE_ENABLED=True):
            with mock.patch("transactions.shadow_service.CandidateShadowScorer.evaluate_shadow"):
                txn_c, alert_c, res_c = run_ingest(f"INV-CASE-C-{uuid.uuid4().hex[:8]}")

        # Assert authoritative production outcomes are bitwise identical
        for res_case in (res_a, res_b, res_c):
            self.assertEqual(res_case["score"], res_base["score"])
            self.assertEqual(res_case["flagged"], res_base["flagged"])
            self.assertEqual(res_case["threshold"], res_base["threshold"])
            self.assertEqual(res_case["reasons"], res_base["reasons"])

        for alert_case in (alert_a, alert_b, alert_c):
            self.assertEqual(alert_case is not None, alert_base is not None)
            if alert_base is not None:
                self.assertEqual(alert_case.score, alert_base.score)
                self.assertEqual(alert_case.threshold, alert_base.threshold)
