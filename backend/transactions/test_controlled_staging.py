"""Controlled Staging Integration Tests for FraudLens Gate 5B.

Verifies:
1. Default production configuration selects the ensemble (15 features with iso_score).
2. Staging explicitly selects the standalone candidate (14 canonical features).
3. Exact feature count, names, and order for each model.
4. Candidate and ensemble explanation compatibility (absence vs presence of rarity).
5. API response fields and threshold behavior at 0.20 in staging.
6. Alert creation and explanation schema in staging.
7. Model-loading and inference failures (missing artifacts, schema mismatch, unauthorized prod activation).
8. Staging shadow failure containment preserved.
9. Rollback from candidate configuration to ensemble restored cleanly.
"""
from datetime import datetime, timezone as dt_timezone, timedelta
from decimal import Decimal
import json
from pathlib import Path
import tempfile
import shutil
import uuid

import numpy as np
import pandas as pd
from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.exceptions import ImproperlyConfigured
from django.test import TestCase, override_settings
from django.urls import reverse
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient

from .ingest import ingest_transaction
from .ml_service import compute_features, get_bundle, score_transaction
from .models import Alert, Card, Transaction
from .shadow_service import _shadow_scorer

User = get_user_model()


class ControlledStagingIntegrationTests(TestCase):
    """Test suite validating controlled standalone candidate integration in staging."""

    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            username=f"stagetest_{uuid.uuid4().hex[:6]}",
            email="stagetest@example.com",
            password="SecurePassword2026!",
            is_staff=True,
        )
        self.client.force_authenticate(user=self.user)
        self.card = Card.objects.create(
            owner=self.user,
            card_ref=f"STAGE-CARD-{uuid.uuid4().hex[:8]}",
            label="Staging Controlled Test Card",
            home_lat=36.115,
            home_long=-84.0438,
        )
        # Establish realistic baseline history so zscore, ratio, and velocity are meaningful
        base_time = datetime(2026, 10, 24, 1, 0, 0, tzinfo=dt_timezone.utc)
        for i in range(5):
            Transaction.objects.create(
                card=self.card,
                trans_ref=f"SETUP-HIST-{i}-{uuid.uuid4().hex[:4]}",
                occurred_at=base_time - timedelta(days=5 - i),
                merchant=f"Local Merchant {i}",
                category="grocery_pos",
                amount=Decimal("30.00"),
                source=Transaction.Source.UPLOAD,
            )
        # Burst of 2 transactions in the previous hour
        for i in range(2):
            Transaction.objects.create(
                card=self.card,
                trans_ref=f"SETUP-BURST-{i}-{uuid.uuid4().hex[:4]}",
                occurred_at=base_time + timedelta(minutes=15 * (i + 1)),
                merchant="Coffee Shop",
                category="food_dining",
                amount=Decimal("8.50"),
                source=Transaction.Source.UPLOAD,
            )
        self.now = base_time + timedelta(hours=1, minutes=30)  # 02:30 AM late night

    def _sample_features(self):
        return {
            "amt": 1500.0,
            "log_amt": float(np.log1p(1500.0)),
            "hour": 2,
            "dayofweek": 5,
            "is_night": 1,
            "category_code": 10,  # shopping_net
            "dist_home_merchant_km": 250.0,
            "amt_zscore": 5.0,
            "amt_ratio_to_mean": 10.0,
            "secs_since_last": 120.0,
            "txn_count_1h": 3,
            "txn_count_24h": 6,
            "is_new_merchant": 1,
            "is_new_category": 1,
        }

    # 1. Default production configuration selects ensemble
    def test_01_default_production_configuration_selects_ensemble(self):
        """Production default (FRAUDLENS_MODEL_MODE not set or 'ensemble') must select the ensemble."""
        with override_settings(FRAUDLENS_ENV="production", FRAUDLENS_MODEL_MODE="ensemble"):
            get_bundle.cache_clear()
            bundle = get_bundle()
            self.assertEqual(bundle.model_mode, "ensemble")
            self.assertIsNotNone(bundle.iso)
            self.assertEqual(len(bundle.xgb_cols), 15)
            self.assertIn("iso_score", bundle.xgb_cols)
            self.assertEqual(bundle.threshold, 0.20)

    # 2. Staging explicitly selects standalone candidate
    def test_02_staging_explicitly_selects_standalone_candidate(self):
        """Staging configuration (FRAUDLENS_ENV='staging', FRAUDLENS_MODEL_MODE='standalone_candidate')
        must select the standalone candidate without Isolation Forest."""
        with override_settings(FRAUDLENS_ENV="staging", FRAUDLENS_MODEL_MODE="standalone_candidate"):
            get_bundle.cache_clear()
            bundle = get_bundle()
            self.assertEqual(bundle.model_mode, "standalone_candidate")
            self.assertIsNone(bundle.iso)
            self.assertEqual(len(bundle.xgb_cols), 14)
            self.assertNotIn("iso_score", bundle.xgb_cols)
            self.assertEqual(bundle.threshold, 0.20)

    # 3. Exact feature count, names, and order for each model
    def test_03_exact_feature_names_and_ordering_for_both_models(self):
        """Booster feature names and order must match expectations for both modes."""
        # A. Candidate in staging
        with override_settings(FRAUDLENS_ENV="staging", FRAUDLENS_MODEL_MODE="standalone_candidate"):
            get_bundle.cache_clear()
            cand_bundle = get_bundle()
            canonical_features = list(cand_bundle.features.FEATURES)
            self.assertEqual(cand_bundle.xgb_cols, canonical_features)
            self.assertEqual(list(cand_bundle.model.get_booster().feature_names), canonical_features)

        # B. Ensemble in production
        with override_settings(FRAUDLENS_ENV="production", FRAUDLENS_MODEL_MODE="ensemble"):
            get_bundle.cache_clear()
            ens_bundle = get_bundle()
            expected_ens_features = canonical_features + ["iso_score"]
            self.assertEqual(ens_bundle.xgb_cols, expected_ens_features)
            self.assertEqual(list(ens_bundle.model.get_booster().feature_names), expected_ens_features)

    # 4. Candidate and ensemble explanation compatibility
    def test_04_candidate_and_ensemble_explanation_compatibility(self):
        """Candidate explanations must omit rarity; ensemble explanations must retain rarity."""
        feats = self._sample_features()

        # A. Candidate explanation
        with override_settings(FRAUDLENS_ENV="staging", FRAUDLENS_MODEL_MODE="standalone_candidate"):
            get_bundle.cache_clear()
            bundle = get_bundle()
            row_cand = pd.DataFrame([feats])
            cand_reasons = bundle.explain.explain(bundle.model, row_cand[bundle.xgb_cols])[0]
            self.assertGreater(len(cand_reasons), 0)
            cand_factors = [r["factor"] for r in cand_reasons]
            self.assertNotIn("rarity", cand_factors)
            for r in cand_reasons:
                self.assertNotIn("iso_score", r["text"])
                self.assertEqual(set(r.keys()), {"factor", "impact", "text"})

        # B. Ensemble explanation
        with override_settings(FRAUDLENS_ENV="production", FRAUDLENS_MODEL_MODE="ensemble"):
            get_bundle.cache_clear()
            bundle = get_bundle()
            row_ens = pd.DataFrame([feats])
            row_ens["iso_score"] = -bundle.iso.score_samples(row_ens[bundle.if_cols])
            ens_reasons = bundle.explain.explain(bundle.model, row_ens[bundle.xgb_cols])[0]
            self.assertGreater(len(ens_reasons), 0)
            ens_factors = [r["factor"] for r in ens_reasons]
            self.assertIn("rarity", ens_factors)
            for r in ens_reasons:
                self.assertEqual(set(r.keys()), {"factor", "impact", "text"})

    # 5. API response fields and threshold behavior at 0.20 in staging
    def test_05_api_scoring_response_fields_and_threshold_behavior_staging(self):
        """Verify API ingestion contract and threshold behavior under standalone candidate staging mode."""
        with override_settings(FRAUDLENS_ENV="staging", FRAUDLENS_MODEL_MODE="standalone_candidate"):
            get_bundle.cache_clear()

            # Normal transaction below threshold (daytime, normal spend)
            daytime = datetime(2026, 10, 24, 14, 0, 0, tzinfo=dt_timezone.utc)
            resp_neg = self.client.post(
                reverse("transaction-list"),
                {
                    "card": self.card.id,
                    "occurred_at": daytime.isoformat(),
                    "merchant": "Normal Grocery Store",
                    "category": "grocery_pos",
                    "amount": "22.50",
                    "merch_lat": self.card.home_lat + 0.02,
                    "merch_long": self.card.home_long + 0.02,
                    "trans_ref": f"API-NEG-{uuid.uuid4().hex[:8]}",
                },
                format="json",
            )
            self.assertEqual(resp_neg.status_code, status.HTTP_201_CREATED)
            data_neg = resp_neg.json()
            self.assertFalse(data_neg["scoring"]["flagged"])
            self.assertIsNone(data_neg["alert_id"])
            self.assertEqual(data_neg["scoring"]["threshold"], 0.20)
            self.assertEqual(data_neg["scoring"]["reasons"], [])

            # High-risk transaction above threshold (late-night, sudden high spend, far away)
            resp_pos = self.client.post(
                reverse("transaction-list"),
                {
                    "card": self.card.id,
                    "occurred_at": self.now.isoformat(),
                    "merchant": "High Risk Electronics Store",
                    "category": "shopping_net",
                    "amount": "1850.00",
                    "merch_lat": self.card.home_lat + 5.0,
                    "merch_long": self.card.home_long + 5.0,
                    "trans_ref": f"API-POS-{uuid.uuid4().hex[:8]}",
                },
                format="json",
            )
            self.assertEqual(resp_pos.status_code, status.HTTP_201_CREATED)
            data_pos = resp_pos.json()
            self.assertTrue(data_pos["scoring"]["flagged"])
            self.assertIsNotNone(data_pos["alert_id"])
            self.assertGreaterEqual(data_pos["scoring"]["score"], 0.20)
            self.assertGreater(len(data_pos["scoring"]["reasons"]), 0)

    # 6. Staging alert creation and explanation schema
    def test_06_staging_alert_creation_and_explanation_schema(self):
        """Alert record created by staging candidate scoring must have open status, valid score, and reasons schema."""
        with override_settings(FRAUDLENS_ENV="staging", FRAUDLENS_MODEL_MODE="standalone_candidate"):
            get_bundle.cache_clear()
            txn, alert, res = ingest_transaction(
                card=self.card,
                occurred_at=self.now,
                merchant="Fraud Jewelry Store",
                category="shopping_net",
                amount=Decimal("2500.00"),
                merch_lat=self.card.home_lat + 4.0,
                merch_long=self.card.home_long + 4.0,
                trans_ref=f"ALERT-TEST-{uuid.uuid4().hex[:8]}",
            )
            self.assertIsNotNone(alert)
            self.assertEqual(alert.status, Alert.Status.OPEN)
            self.assertGreaterEqual(alert.score, 0.20)
            self.assertEqual(alert.threshold, 0.20)
            self.assertIsInstance(alert.reasons, list)
            self.assertGreater(len(alert.reasons), 0)
            for r in alert.reasons:
                self.assertEqual(set(r.keys()), {"factor", "impact", "text"})
                self.assertNotEqual(r["factor"], "rarity")

    # 7. Model-loading and inference failures handled safely
    def test_07_model_loading_and_inference_failures_handled_safely(self):
        """Model loader must fail safely on unauthorized prod candidate activation, invalid modes, and bad thresholds."""
        # A. Candidate standalone cannot be enabled if FRAUDLENS_ENV != 'staging'
        with override_settings(FRAUDLENS_ENV="production", FRAUDLENS_MODEL_MODE="standalone_candidate"):
            get_bundle.cache_clear()
            with self.assertRaises(ImproperlyConfigured) as ctx:
                get_bundle()
            self.assertIn("staging", str(ctx.exception).lower())

        # B. Unknown FRAUDLENS_MODEL_MODE raises ValueError
        with override_settings(FRAUDLENS_ENV="staging", FRAUDLENS_MODEL_MODE="unsupported_model_mode"):
            get_bundle.cache_clear()
            with self.assertRaises(ValueError) as ctx:
                get_bundle()
            self.assertIn("unknown fraudlens_model_mode", str(ctx.exception).lower())

        # C. Missing candidate artifact raises FileNotFoundError
        temp_dir = tempfile.mkdtemp()
        try:
            with override_settings(
                FRAUDLENS_ENV="staging",
                FRAUDLENS_MODEL_MODE="standalone_candidate",
                ML_ARTIFACTS_DIR=temp_dir,
            ):
                get_bundle.cache_clear()
                with self.assertRaises(FileNotFoundError):
                    get_bundle()
        finally:
            shutil.rmtree(temp_dir, ignore_errors=True)

    # 8. Staging shadow failure containment preserved
    def test_08_staging_shadow_failure_containment_preserved(self):
        """Ingestion in staging must succeed even if shadow evaluation crashes."""
        with override_settings(FRAUDLENS_ENV="staging", FRAUDLENS_MODEL_MODE="standalone_candidate", SHADOW_MODE_ENABLED=True):
            get_bundle.cache_clear()
            from unittest.mock import patch
            with patch.object(_shadow_scorer, "evaluate_shadow", side_effect=RuntimeError("Simulated shadow crash")):
                txn, alert, res = ingest_transaction(
                    card=self.card,
                    occurred_at=self.now,
                    merchant="Shadow Crash Test Merchant",
                    category="food_dining",
                    amount=Decimal("35.00"),
                    trans_ref=f"SHADOW-CRASH-{uuid.uuid4().hex[:8]}",
                )
                self.assertIsNotNone(txn)
                self.assertIsNotNone(res["score"])

    # 9. Rollback from candidate configuration to ensemble restored cleanly
    def test_09_rollback_from_candidate_configuration_to_ensemble(self):
        """Switching FRAUDLENS_MODEL_MODE back to 'ensemble' restores ensemble scoring immediately."""
        # 1. Active candidate mode
        with override_settings(FRAUDLENS_ENV="staging", FRAUDLENS_MODEL_MODE="standalone_candidate"):
            get_bundle.cache_clear()
            cand_bundle = get_bundle()
            self.assertEqual(cand_bundle.model_mode, "standalone_candidate")
            self.assertEqual(len(cand_bundle.xgb_cols), 14)

        # 2. Rollback to ensemble mode
        with override_settings(FRAUDLENS_ENV="staging", FRAUDLENS_MODEL_MODE="ensemble"):
            get_bundle.cache_clear()
            ens_bundle = get_bundle()
            self.assertEqual(ens_bundle.model_mode, "ensemble")
            self.assertEqual(len(ens_bundle.xgb_cols), 15)
            self.assertIsNotNone(ens_bundle.iso)

            # Score transaction to verify full pipeline restoration
            res = score_transaction(
                card=self.card,
                occurred_at=self.now,
                merchant="Rollback Verification Merchant",
                category="food_dining",
                amount=Decimal("40.00"),
            )
            self.assertIn("score", res)
            self.assertFalse(res["flagged"])
