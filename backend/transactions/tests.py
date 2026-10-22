from copy import copy
from decimal import Decimal
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.db import IntegrityError
from django.test import TestCase
from django.urls import reverse
from django.utils import timezone

from rest_framework import status
from rest_framework.test import APIClient

from .ingest import ingest_transaction
from .ml_service import get_bundle
from .models import Alert, Card, Investigation, Transaction


User = get_user_model()


class FraudLensBackendTests(TestCase):
    """Tests for authentication, transactions, alerts, and investigations."""

    def setUp(self):
        self.client = APIClient()

        self.user = User.objects.create_user(
            username="testuser",
            email="test@example.com",
            password="Test-Password-2026!",
        )
        self.other_user = User.objects.create_user(
            username="otheruser",
            email="other@example.com",
            password="Other-Password-2026!",
        )

        self.card = Card.objects.create(
            owner=self.user,
            card_ref="TEST-CARD-001",
            label="My Test Card",
        )
        self.other_card = Card.objects.create(
            owner=self.other_user,
            card_ref="TEST-CARD-002",
            label="Other Test Card",
        )

    def authenticate(self, user=None):
        self.client.force_authenticate(user=user or self.user)

    def create_transaction(
        self,
        *,
        card,
        trans_ref,
        amount="100.00",
        merchant="Test Merchant",
        occurred_at=None,
    ):
        return Transaction.objects.create(
            trans_ref=trans_ref,
            card=card,
            occurred_at=occurred_at or timezone.now(),
            merchant=merchant,
            category=Transaction.Category.FOOD_DINING,
            amount=Decimal(amount),
            source=Transaction.Source.UPLOAD,
        )

    def create_alert(
        self,
        *,
        card=None,
        trans_ref="ALERT-TXN-001",
        score=0.92,
        threshold=0.20,
        alert_status=Alert.Status.OPEN,
    ):
        transaction = self.create_transaction(
            card=card or self.card,
            trans_ref=trans_ref,
            merchant="Suspicious Online Store",
            amount="850.00",
        )

        return Alert.objects.create(
            transaction=transaction,
            score=score,
            threshold=threshold,
            reasons=[
                {
                    "factor": "amount",
                    "impact": 0.75,
                    "text": "Unusual transaction amount",
                }
            ],
            status=alert_status,
        )

    # ---------------------------------------------------------
    # Health and authentication
    # ---------------------------------------------------------

    def test_health_endpoint_returns_ok(self):
        response = self.client.get("/api/health/")

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
        )
        self.assertEqual(response.json()["status"], "ok")
        self.assertEqual(
            response.json()["service"],
            "fraudlens-backend",
        )

    def test_me_endpoint_requires_authentication(self):
        response = self.client.get("/api/auth/me/")

        self.assertEqual(
            response.status_code,
            status.HTTP_401_UNAUTHORIZED,
        )

    def test_register_creates_user_and_token(self):
        response = self.client.post(
            "/api/auth/register/",
            {
                "username": "newuser",
                "email": "newuser@example.com",
                "password": "S3cure!Random-Password-2026",
            },
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_201_CREATED,
        )
        self.assertTrue(response.data["token"])
        self.assertEqual(response.data["username"], "newuser")
        self.assertTrue(
            User.objects.filter(username="newuser").exists()
        )

    def test_me_returns_authenticated_user_details(self):
        self.authenticate()

        response = self.client.get("/api/auth/me/")

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
        )
        self.assertEqual(response.data["username"], "testuser")
        self.assertEqual(response.data["email"], "test@example.com")
        self.assertEqual(response.data["card_count"], 1)

    # ---------------------------------------------------------
    # Cards and transaction access control
    # ---------------------------------------------------------

    def test_user_sees_only_their_own_cards(self):
        self.authenticate()

        response = self.client.get(reverse("card-list"))

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
        )

        card_ids = [
            item["id"] for item in response.data["results"]
        ]

        self.assertEqual(card_ids, [self.card.id])
        self.assertNotIn(self.other_card.id, card_ids)

    def test_user_sees_only_their_own_transactions(self):
        own = self.create_transaction(
            card=self.card,
            trans_ref="OWN-TXN-001",
        )
        other = self.create_transaction(
            card=self.other_card,
            trans_ref="OTHER-TXN-001",
        )

        self.authenticate()

        response = self.client.get(reverse("transaction-list"))

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
        )

        ids = {
            item["id"] for item in response.data["results"]
        }

        self.assertIn(own.id, ids)
        self.assertNotIn(other.id, ids)

    def test_user_cannot_retrieve_another_users_transaction(self):
        other = self.create_transaction(
            card=self.other_card,
            trans_ref="PRIVATE-TXN-001",
        )

        self.authenticate()

        response = self.client.get(
            reverse("transaction-detail", args=[other.id])
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_404_NOT_FOUND,
        )

    def test_user_cannot_submit_transaction_to_another_users_card(self):
        self.authenticate()

        response = self.client.post(
            reverse("transaction-list"),
            {
                "card": self.other_card.id,
                "occurred_at": timezone.now().isoformat(),
                "merchant": "Test Merchant",
                "category": "food_dining",
                "amount": "250.00",
                "trans_ref": "UNAUTHORIZED-TXN",
            },
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_400_BAD_REQUEST,
        )
        self.assertIn("card", response.data)

        self.assertFalse(
            Transaction.objects.filter(
                trans_ref="UNAUTHORIZED-TXN"
            ).exists()
        )

    # ---------------------------------------------------------
    # Transaction creation and ML integration
    # ---------------------------------------------------------

    @patch("transactions.views.ingest_transaction")
    def test_create_transaction_returns_scoring_result(
        self,
        mock_ingest,
    ):
        occurred_at = timezone.now()

        def fake_ingest(**kwargs):
            transaction = Transaction.objects.create(
                trans_ref=kwargs["trans_ref"],
                card=kwargs["card"],
                occurred_at=kwargs["occurred_at"],
                merchant=kwargs["merchant"],
                category=kwargs["category"],
                amount=kwargs["amount"],
                merch_lat=kwargs.get("merch_lat"),
                merch_long=kwargs.get("merch_long"),
                source=kwargs["source"],
            )

            return (
                transaction,
                None,
                {
                    "score": 0.12,
                    "flagged": False,
                    "threshold": 0.20,
                    "reasons": [],
                    "features": {},
                },
            )

        mock_ingest.side_effect = fake_ingest
        self.authenticate()

        response = self.client.post(
            reverse("transaction-list"),
            {
                "card": self.card.id,
                "occurred_at": occurred_at.isoformat(),
                "merchant": "Online Store",
                "category": "food_dining",
                "amount": "250.00",
                "trans_ref": "API-TXN-001",
            },
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_201_CREATED,
            msg=str(response.data),
        )
        self.assertEqual(
            response.data["transaction"]["trans_ref"],
            "API-TXN-001",
        )
        self.assertAlmostEqual(
            response.data["scoring"]["score"],
            0.12,
        )
        self.assertFalse(response.data["scoring"]["flagged"])
        self.assertIsNone(response.data["alert_id"])

        mock_ingest.assert_called_once()

    # ---------------------------------------------------------
    # Alert access control
    # ---------------------------------------------------------

    def test_user_sees_only_alerts_for_their_own_cards(self):
        own = self.create_alert(
            card=self.card,
            trans_ref="OWN-ALERT-TXN",
        )
        other = self.create_alert(
            card=self.other_card,
            trans_ref="OTHER-ALERT-TXN",
        )

        self.authenticate()

        response = self.client.get(reverse("alert-list"))

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
        )

        alert_ids = {
            item["id"] for item in response.data["results"]
        }

        self.assertIn(own.id, alert_ids)
        self.assertNotIn(other.id, alert_ids)

    def test_user_cannot_retrieve_another_users_alert(self):
        alert = self.create_alert(
            card=self.other_card,
            trans_ref="PRIVATE-ALERT-TXN",
        )

        self.authenticate()

        response = self.client.get(
            reverse("alert-detail", args=[alert.id])
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_404_NOT_FOUND,
        )

    # ---------------------------------------------------------
    # Investigation workflow
    # ---------------------------------------------------------

    def test_needs_info_verdict_moves_alert_into_review(self):
        alert = self.create_alert()
        self.authenticate()

        response = self.client.post(
            reverse("alert-investigate", args=[alert.id]),
            {
                "verdict": Investigation.Verdict.NEEDS_INFO,
                "notes": "Request additional transaction details.",
            },
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_201_CREATED,
            msg=str(response.data),
        )

        alert.refresh_from_db()

        self.assertEqual(
            alert.status,
            Alert.Status.IN_REVIEW,
        )
        self.assertEqual(
            response.data["verdict"],
            Investigation.Verdict.NEEDS_INFO,
        )
        self.assertEqual(
            response.data["notes"],
            "Request additional transaction details.",
        )
        self.assertEqual(
            Investigation.objects.filter(alert=alert).count(),
            1,
        )

    def test_confirmed_fraud_verdict_resolves_alert(self):
        alert = self.create_alert()
        self.authenticate()

        response = self.client.post(
            reverse("alert-investigate", args=[alert.id]),
            {
                "verdict": Investigation.Verdict.CONFIRMED_FRAUD,
                "notes": "Fraud confirmed during review.",
            },
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_201_CREATED,
            msg=str(response.data),
        )

        alert.refresh_from_db()

        self.assertEqual(
            alert.status,
            Alert.Status.RESOLVED,
        )
        self.assertEqual(
            response.data["verdict"],
            Investigation.Verdict.CONFIRMED_FRAUD,
        )
        self.assertEqual(
            Investigation.objects.get(alert=alert).analyst,
            self.user,
        )

    def test_false_positive_verdict_resolves_alert(self):
        alert = self.create_alert()
        self.authenticate()

        response = self.client.post(
            reverse("alert-investigate", args=[alert.id]),
            {
                "verdict": Investigation.Verdict.FALSE_POSITIVE,
                "notes": "Transaction verified by the customer.",
            },
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_201_CREATED,
            msg=str(response.data),
        )

        alert.refresh_from_db()

        self.assertEqual(
            alert.status,
            Alert.Status.RESOLVED,
        )

    def test_user_cannot_investigate_another_users_alert(self):
        alert = self.create_alert(
            card=self.other_card,
            trans_ref="OTHER-INVESTIGATION-TXN",
        )

        self.authenticate()

        response = self.client.post(
            reverse("alert-investigate", args=[alert.id]),
            {
                "verdict": Investigation.Verdict.CONFIRMED_FRAUD,
                "notes": "Attempted unauthorized investigation.",
            },
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_404_NOT_FOUND,
        )
        self.assertFalse(
            Investigation.objects.filter(alert=alert).exists()
        )

    def test_invalid_investigation_verdict_is_rejected(self):
        alert = self.create_alert()
        self.authenticate()

        response = self.client.post(
            reverse("alert-investigate", args=[alert.id]),
            {
                "verdict": "not_a_valid_verdict",
                "notes": "Invalid test verdict.",
            },
            format="json",
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_400_BAD_REQUEST,
        )
        self.assertFalse(
            Investigation.objects.filter(alert=alert).exists()
        )

    # ---------------------------------------------------------
    # Dashboard
    # ---------------------------------------------------------

    def test_summary_contains_only_users_own_transactions(self):
        self.create_transaction(
            card=self.card,
            trans_ref="SUMMARY-OWN-001",
            amount="125.50",
        )
        self.create_transaction(
            card=self.other_card,
            trans_ref="SUMMARY-OTHER-001",
            amount="999.99",
        )

        self.authenticate()

        response = self.client.get("/api/summary/")

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
        )
        self.assertEqual(
            response.data["transaction_count"],
            1,
        )
        self.assertAlmostEqual(
            response.data["total_spend"],
            125.50,
        )

    def test_transaction_list_rejects_invalid_date_filter(self):
        self.authenticate()

        response = self.client.get(
            reverse("transaction-list"),
            {"date_from": "not-a-date"},
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_400_BAD_REQUEST,
        )

    def test_transaction_list_can_search_by_merchant(self):
        matching = self.create_transaction(
            card=self.card,
            trans_ref="SEARCH-001",
            merchant="Coffee House",
        )
        self.create_transaction(
            card=self.card,
            trans_ref="SEARCH-002",
            merchant="Book Store",
        )

        self.authenticate()

        response = self.client.get(
            reverse("transaction-list"),
            {"search": "Coffee"},
        )

        self.assertEqual(
            response.status_code,
            status.HTTP_200_OK,
        )

        returned_ids = {
            item["id"] for item in response.data["results"]
        }

        self.assertEqual(returned_ids, {matching.id})


class RealMLIngestionIntegrationTests(TestCase):
    """Integration tests for real ML scoring and alert persistence."""

    def setUp(self):
        self.user = User.objects.create_user(
            username="realmltestuser",
            email="realmltest@example.com",
            password="Test-Password-2026!",
        )

        self.card = Card.objects.create(
            owner=self.user,
            card_ref="REAL-ML-TEST-CARD",
            label="Real ML Integration Test Card",
        )

    def test_real_model_scoring_persists_transaction_and_alert(self):
        # Use the real trained model, but lower the threshold on a copied
        # bundle so this test reliably exercises alert creation.
        # The production threshold and model artifacts are not modified.
        test_bundle = copy(get_bundle())
        test_bundle.threshold = -1.0

        with patch(
            "transactions.ml_service.get_bundle",
            return_value=test_bundle,
        ):
            transaction, alert, result = ingest_transaction(
                card=self.card,
                occurred_at=timezone.now(),
                merchant="Integration Test Merchant",
                category=Transaction.Category.FOOD_DINING,
                amount=Decimal("125.50"),
                source=Transaction.Source.UPLOAD,
                trans_ref="REAL-ML-INGEST-001",
            )

        # Verify the scoring result.
        self.assertTrue(result["flagged"])
        self.assertGreaterEqual(result["score"], 0.0)
        self.assertLessEqual(result["score"], 1.0)
        self.assertEqual(result["threshold"], -1.0)
        self.assertIsNotNone(alert)

        # Reload objects from the test database.
        transaction.refresh_from_db()
        alert.refresh_from_db()

        # Verify transaction persistence.
        self.assertEqual(
            transaction.trans_ref,
            "REAL-ML-INGEST-001",
        )
        self.assertEqual(Transaction.objects.count(), 1)

        # Verify alert persistence and transaction relationship.
        self.assertEqual(Alert.objects.count(), 1)
        self.assertEqual(alert.transaction_id, transaction.id)

        # Verify that the saved alert matches the scoring result.
        self.assertAlmostEqual(
            alert.score,
            result["score"],
        )
        self.assertEqual(
            alert.threshold,
            result["threshold"],
        )
        self.assertEqual(
            alert.reasons,
            result["reasons"],
        )
        self.assertIsInstance(result["reasons"], list)


import json
import math
import shutil
import tempfile
from datetime import datetime, timedelta, timezone as dt_timezone
from pathlib import Path

import numpy as np
import pandas as pd
from django.conf import settings

from .ml_service import (
    DEFAULT_DISTANCE_KM,
    MIN_HISTORY,
    NO_HISTORY_GAP,
    compute_features,
    score_transaction,
)


class MLFeaturePipelineParityRegressionTests(TestCase):
    """Regression tests covering offline/live feature parity and edge cases."""

    def setUp(self):
        self.user = User.objects.create_user(
            username="paritytestuser",
            email="paritytest@example.com",
            password="Parity-Password-2026!",
        )
        self.card = Card.objects.create(
            owner=self.user,
            card_ref="PARITY-CARD-001",
            label="Parity Test Card",
            home_lat=40.7128,
            home_long=-74.0060,
        )
        self.now = timezone.now()

    # 1. Missing home latitude or longitude
    def test_missing_home_latitude_or_longitude_falls_back_to_default_distance(self):
        # Missing home_long
        card_no_long = Card.objects.create(
            owner=self.user,
            card_ref="NO-HOME-LONG",
            home_lat=40.7128,
            home_long=None,
        )
        feats1 = compute_features(
            card=card_no_long,
            occurred_at=self.now,
            merchant="Merchant A",
            category=Transaction.Category.FOOD_DINING,
            amount=Decimal("50.00"),
            merch_lat=40.7300,
            merch_long=-73.9950,
        )
        self.assertEqual(feats1["dist_home_merchant_km"], DEFAULT_DISTANCE_KM)

        # Missing home_lat
        card_no_lat = Card.objects.create(
            owner=self.user,
            card_ref="NO-HOME-LAT",
            home_lat=None,
            home_long=-74.0060,
        )
        feats2 = compute_features(
            card=card_no_lat,
            occurred_at=self.now,
            merchant="Merchant A",
            category=Transaction.Category.FOOD_DINING,
            amount=Decimal("50.00"),
            merch_lat=40.7300,
            merch_long=-73.9950,
        )
        self.assertEqual(feats2["dist_home_merchant_km"], DEFAULT_DISTANCE_KM)

        # Non-finite coordinate (NaN)
        card_nan = Card.objects.create(
            owner=self.user,
            card_ref="NAN-HOME-LAT",
            home_lat=float("nan"),
            home_long=-74.0060,
        )
        feats3 = compute_features(
            card=card_nan,
            occurred_at=self.now,
            merchant="Merchant A",
            category=Transaction.Category.FOOD_DINING,
            amount=Decimal("50.00"),
            merch_lat=40.7300,
            merch_long=-73.9950,
        )
        self.assertEqual(feats3["dist_home_merchant_km"], DEFAULT_DISTANCE_KM)

    # 2. Missing merchant latitude or longitude
    def test_missing_merchant_latitude_or_longitude_falls_back_to_default_distance(self):
        # Missing merch_long
        feats1 = compute_features(
            card=self.card,
            occurred_at=self.now,
            merchant="Merchant A",
            category=Transaction.Category.FOOD_DINING,
            amount=Decimal("50.00"),
            merch_lat=40.7300,
            merch_long=None,
        )
        self.assertEqual(feats1["dist_home_merchant_km"], DEFAULT_DISTANCE_KM)

        # Missing merch_lat
        feats2 = compute_features(
            card=self.card,
            occurred_at=self.now,
            merchant="Merchant A",
            category=Transaction.Category.FOOD_DINING,
            amount=Decimal("50.00"),
            merch_lat=None,
            merch_long=-73.9950,
        )
        self.assertEqual(feats2["dist_home_merchant_km"], DEFAULT_DISTANCE_KM)

        # Both None
        feats3 = compute_features(
            card=self.card,
            occurred_at=self.now,
            merchant="Merchant A",
            category=Transaction.Category.FOOD_DINING,
            amount=Decimal("50.00"),
            merch_lat=None,
            merch_long=None,
        )
        self.assertEqual(feats3["dist_home_merchant_km"], DEFAULT_DISTANCE_KM)

        # Non-finite merchant coordinate
        feats4 = compute_features(
            card=self.card,
            occurred_at=self.now,
            merchant="Merchant A",
            category=Transaction.Category.FOOD_DINING,
            amount=Decimal("50.00"),
            merch_lat=float("inf"),
            merch_long=-73.9950,
        )
        self.assertEqual(feats4["dist_home_merchant_km"], DEFAULT_DISTANCE_KM)

    # 3. A card with no transaction history
    def test_card_with_no_transaction_history_produces_neutral_values(self):
        feats = compute_features(
            card=self.card,
            occurred_at=self.now,
            merchant="Brand New Merchant",
            category=Transaction.Category.SHOPPING_NET,
            amount=Decimal("120.00"),
        )
        self.assertEqual(feats["amt_zscore"], 0.0)
        self.assertEqual(feats["amt_ratio_to_mean"], 1.0)
        self.assertEqual(feats["secs_since_last"], float(NO_HISTORY_GAP))
        self.assertEqual(feats["txn_count_1h"], 0)
        self.assertEqual(feats["txn_count_24h"], 0)
        self.assertEqual(feats["is_new_merchant"], 1)
        self.assertEqual(feats["is_new_category"], 1)

    # 4. Fewer than five prior transactions
    def test_fewer_than_five_prior_transactions_keeps_neutral_zscore_and_ratio(self):
        base_time = self.now - timedelta(hours=3)
        for i in range(1, 4):  # 3 prior transactions
            Transaction.objects.create(
                card=self.card,
                trans_ref=f"PRIOR-FEW-{i}",
                occurred_at=base_time + timedelta(minutes=30 * i),
                merchant=f"Merchant {i}",
                category=Transaction.Category.FOOD_DINING,
                amount=Decimal(str(10 * i)),
            )

        target_time = base_time + timedelta(hours=2)
        feats = compute_features(
            card=self.card,
            occurred_at=target_time,
            merchant="Merchant Target",
            category=Transaction.Category.FOOD_DINING,
            amount=Decimal("99.00"),
        )
        self.assertEqual(feats["amt_zscore"], 0.0)
        self.assertEqual(feats["amt_ratio_to_mean"], 1.0)
        # 3 prior transactions, latest was at base_time + 90m = 30m before target_time
        self.assertEqual(feats["secs_since_last"], 1800.0)
        self.assertEqual(feats["txn_count_1h"], 2)
        self.assertEqual(feats["txn_count_24h"], 3)

    # 5. Five or more prior transactions
    def test_five_or_more_prior_transactions_computes_exact_zscore_and_ratio(self):
        base_time = self.now - timedelta(days=2)
        prior_amounts = [10.0, 20.0, 30.0, 40.0, 50.0]  # mean=30, var(ddof=1)=250, std=sqrt(250)
        for i, amt in enumerate(prior_amounts):
            Transaction.objects.create(
                card=self.card,
                trans_ref=f"PRIOR-FIVE-{i}",
                occurred_at=base_time + timedelta(hours=i),
                merchant=f"Merchant {i}",
                category=Transaction.Category.FOOD_DINING,
                amount=Decimal(str(amt)),
            )

        target_amt = 60.0
        target_time = base_time + timedelta(hours=10)
        feats = compute_features(
            card=self.card,
            occurred_at=target_time,
            merchant="Target Merchant",
            category=Transaction.Category.FOOD_DINING,
            amount=Decimal(str(target_amt)),
        )

        expected_mean = 30.0
        expected_std = math.sqrt(250.0)  # ~15.8113883
        expected_zscore = (target_amt - expected_mean) / expected_std
        expected_ratio = target_amt / expected_mean

        self.assertAlmostEqual(feats["amt_zscore"], expected_zscore, places=6)
        self.assertAlmostEqual(feats["amt_ratio_to_mean"], expected_ratio, places=6)

    # 6. Transactions exactly one hour and 24 hours before the target transaction
    def test_transactions_exactly_one_hour_and_24_hours_boundary(self):
        target_time = self.now
        # Txn 1: exactly 3600 seconds before target -> included in 1h and 24h
        Transaction.objects.create(
            card=self.card,
            trans_ref="BOUND-1H-EXACT",
            occurred_at=target_time - timedelta(seconds=3600),
            merchant="Merchant 1h Exact",
            category=Transaction.Category.FOOD_DINING,
            amount=Decimal("10.00"),
        )
        # Txn 2: 3601 seconds before target -> excluded from 1h, included in 24h
        Transaction.objects.create(
            card=self.card,
            trans_ref="BOUND-1H-OVER",
            occurred_at=target_time - timedelta(seconds=3601),
            merchant="Merchant 1h Over",
            category=Transaction.Category.FOOD_DINING,
            amount=Decimal("10.00"),
        )
        # Txn 3: exactly 86400 seconds before target -> included in 24h
        Transaction.objects.create(
            card=self.card,
            trans_ref="BOUND-24H-EXACT",
            occurred_at=target_time - timedelta(seconds=86400),
            merchant="Merchant 24h Exact",
            category=Transaction.Category.FOOD_DINING,
            amount=Decimal("10.00"),
        )
        # Txn 4: 86401 seconds before target -> excluded from 24h
        Transaction.objects.create(
            card=self.card,
            trans_ref="BOUND-24H-OVER",
            occurred_at=target_time - timedelta(seconds=86401),
            merchant="Merchant 24h Over",
            category=Transaction.Category.FOOD_DINING,
            amount=Decimal("10.00"),
        )

        feats = compute_features(
            card=self.card,
            occurred_at=target_time,
            merchant="Target Boundary Merchant",
            category=Transaction.Category.FOOD_DINING,
            amount=Decimal("25.00"),
        )

        self.assertEqual(feats["txn_count_1h"], 1)
        self.assertEqual(feats["txn_count_24h"], 3)

    # 7. Multiple transactions sharing the same timestamp
    def test_multiple_transactions_sharing_same_timestamp_are_causally_consistent(self):
        earlier_time = self.now - timedelta(minutes=10)
        Transaction.objects.create(
            card=self.card,
            trans_ref="PRIOR-TIED-BASE",
            occurred_at=earlier_time,
            merchant="Prior Merchant",
            category=Transaction.Category.FOOD_DINING,
            amount=Decimal("20.00"),
        )

        tied_timestamp = self.now

        # Transaction A at tied_timestamp
        feats_a_before = compute_features(
            card=self.card,
            occurred_at=tied_timestamp,
            merchant="Merchant A",
            category=Transaction.Category.ENTERTAINMENT,
            amount=Decimal("50.00"),
        )

        # Save Transaction A to DB
        Transaction.objects.create(
            card=self.card,
            trans_ref="TIED-TXN-A",
            occurred_at=tied_timestamp,
            merchant="Merchant A",
            category=Transaction.Category.ENTERTAINMENT,
            amount=Decimal("50.00"),
        )

        # Score Transaction B at the EXACT SAME tied_timestamp
        feats_b = compute_features(
            card=self.card,
            occurred_at=tied_timestamp,
            merchant="Merchant B",
            category=Transaction.Category.SHOPPING_POS,
            amount=Decimal("75.00"),
        )

        # Transaction B must NOT include Transaction A in its causal history (occurred_at < T)
        self.assertEqual(feats_b["secs_since_last"], 600.0)  # 10 minutes from earlier_time
        self.assertEqual(feats_b["txn_count_1h"], 1)  # only PRIOR-TIED-BASE
        self.assertEqual(feats_b["is_new_merchant"], 1)

        # Re-score Transaction A: it must produce the exact same features
        feats_a_after = compute_features(
            card=self.card,
            occurred_at=tied_timestamp,
            merchant="Merchant A",
            category=Transaction.Category.ENTERTAINMENT,
            amount=Decimal("50.00"),
        )
        self.assertEqual(feats_a_before, feats_a_after)

    # 8. A new versus previously seen merchant
    def test_new_versus_previously_seen_merchant(self):
        Transaction.objects.create(
            card=self.card,
            trans_ref="SEEN-MERCH-TXN",
            occurred_at=self.now - timedelta(hours=1),
            merchant="Local Grocery",
            category=Transaction.Category.GROCERY_POS,
            amount=Decimal("45.00"),
        )

        feats_seen = compute_features(
            card=self.card,
            occurred_at=self.now,
            merchant="Local Grocery",
            category=Transaction.Category.GROCERY_POS,
            amount=Decimal("30.00"),
        )
        self.assertEqual(feats_seen["is_new_merchant"], 0)

        feats_new = compute_features(
            card=self.card,
            occurred_at=self.now,
            merchant="Never Seen Store",
            category=Transaction.Category.GROCERY_POS,
            amount=Decimal("30.00"),
        )
        self.assertEqual(feats_new["is_new_merchant"], 1)

    # 9. A new versus previously seen category
    def test_new_versus_previously_seen_category(self):
        Transaction.objects.create(
            card=self.card,
            trans_ref="SEEN-CAT-TXN",
            occurred_at=self.now - timedelta(hours=1),
            merchant="Airline Desk",
            category=Transaction.Category.TRAVEL,
            amount=Decimal("350.00"),
        )

        feats_seen = compute_features(
            card=self.card,
            occurred_at=self.now,
            merchant="Hotel Room",
            category=Transaction.Category.TRAVEL,
            amount=Decimal("120.00"),
        )
        self.assertEqual(feats_seen["is_new_category"], 0)

        feats_new = compute_features(
            card=self.card,
            occurred_at=self.now,
            merchant="Cinema",
            category=Transaction.Category.ENTERTAINMENT,
            amount=Decimal("15.00"),
        )
        self.assertEqual(feats_new["is_new_category"], 1)

    # 10. Consistent offline versus live features for representative transactions
    def test_offline_versus_live_feature_parity_on_representative_data(self):
        bundle = get_bundle()
        feature_names = bundle.features.FEATURES

        # Build a representative sequence of 7 transactions
        base_dt = datetime(2026, 5, 1, 10, 0, 0, tzinfo=dt_timezone.utc)
        records = [
            {"offset_h": 0, "amt": 25.00, "merchant": "Coffee Co", "cat": "food_dining", "lat": 40.71, "lon": -74.00, "mlat": 40.72, "mlon": -74.01},
            {"offset_h": 2, "amt": 50.00, "merchant": "Metro Subway", "cat": "gas_transport", "lat": 40.71, "lon": -74.00, "mlat": 40.75, "mlon": -73.98},
            {"offset_h": 5, "amt": 15.50, "merchant": "Coffee Co", "cat": "food_dining", "lat": 40.71, "lon": -74.00, "mlat": 40.72, "mlon": -74.01},
            {"offset_h": 20, "amt": 120.00, "merchant": "Supermarket", "cat": "grocery_pos", "lat": 40.71, "lon": -74.00, "mlat": 40.70, "mlon": -74.02},
            {"offset_h": 26, "amt": 85.00, "merchant": "Online Tech", "cat": "shopping_net", "lat": 40.71, "lon": -74.00, "mlat": 40.68, "mlon": -73.95},
            {"offset_h": 30, "amt": 200.00, "merchant": "Steakhouse", "cat": "food_dining", "lat": 40.71, "lon": -74.00, "mlat": 40.76, "mlon": -73.97},
            {"offset_h": 35, "amt": 45.00, "merchant": "Bookstore", "cat": "shopping_pos", "lat": 40.71, "lon": -74.00, "mlat": 40.73, "mlon": -73.99},
        ]

        # 1. Create offline DataFrame
        offline_rows = []
        for i, r in enumerate(records):
            dt = base_dt + timedelta(hours=r["offset_h"])
            offline_rows.append({
                "trans_num": f"PARITY-REP-{i}",
                "cc_num": 99991111,
                "unix_time": int(dt.timestamp()),
                "trans_date_trans_time": dt,
                "amt": r["amt"],
                "merchant": r["merchant"],
                "category": r["cat"],
                "lat": r["lat"],
                "long": r["lon"],
                "merch_lat": r["mlat"],
                "merch_long": r["mlon"],
                "dob": "1990-01-01",
                "gender": "F",
                "city_pop": 50000,
            })

        offline_df = bundle.features.build_features(pd.DataFrame(offline_rows))

        # 2. Ingest transactions in live Django test DB and score sequentially
        card_parity = Card.objects.create(
            owner=self.user,
            card_ref="PARITY-CARD-REP",
            label="Parity Representative Card",
            home_lat=40.71,
            home_long=-74.00,
        )

        for i, r in enumerate(records):
            dt = base_dt + timedelta(hours=r["offset_h"])
            live_feats = compute_features(
                card=card_parity,
                occurred_at=dt,
                merchant=r["merchant"],
                category=r["cat"],
                amount=Decimal(str(r["amt"])),
                merch_lat=r["mlat"],
                merch_long=r["mlon"],
            )

            # Save to DB so subsequent transactions see it in history
            Transaction.objects.create(
                card=card_parity,
                trans_ref=f"PARITY-REP-{i}",
                occurred_at=dt,
                merchant=r["merchant"],
                category=r["cat"],
                amount=Decimal(str(r["amt"])),
                merch_lat=r["mlat"],
                merch_long=r["mlon"],
                source=Transaction.Source.UPLOAD,
            )

            # Compare all 14 features against offline_df row
            off_row = offline_df.iloc[i]
            for feat in feature_names:
                off_val = float(off_row[feat])
                live_val = float(live_feats[feat])
                self.assertAlmostEqual(
                    off_val,
                    live_val,
                    places=5,
                    msg=f"Mismatch on row {i} feature '{feat}': offline={off_val}, live={live_val}",
                )


class MLArtifactsAndSecurityRegressionTests(TestCase):
    """Regression tests for artifact error handling and backend security validation."""

    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            username="sectestuser",
            email="sectest@example.com",
            password="Security-Password-2026!",
        )
        self.card = Card.objects.create(
            owner=self.user,
            card_ref="SEC-CARD-001",
            label="Security Test Card",
        )
        self.client.force_authenticate(user=self.user)

    # 11. Missing or invalid ML artifacts
    def test_missing_ml_artifacts_raise_clear_file_not_found_error(self):
        temp_dir = tempfile.mkdtemp()
        orig_artifacts = settings.ML_ARTIFACTS_DIR
        try:
            settings.ML_ARTIFACTS_DIR = temp_dir
            get_bundle.cache_clear()
            with self.assertRaises(FileNotFoundError) as ctx:
                get_bundle()
            self.assertIn("Missing required ML artifact", str(ctx.exception))
        finally:
            settings.ML_ARTIFACTS_DIR = orig_artifacts
            get_bundle.cache_clear()
            shutil.rmtree(temp_dir, ignore_errors=True)

    def test_invalid_threshold_json_raises_clear_value_error(self):
        temp_dir = tempfile.mkdtemp()
        orig_artifacts = settings.ML_ARTIFACTS_DIR
        try:
            # Copy real joblib files into temp_dir but write invalid threshold.json
            real_artifacts = Path(orig_artifacts)
            shutil.copy(real_artifacts / "isolation_forest.joblib", Path(temp_dir) / "isolation_forest.joblib")
            shutil.copy(real_artifacts / "xgb_with_iso.joblib", Path(temp_dir) / "xgb_with_iso.joblib")
            (Path(temp_dir) / "threshold.json").write_text("{invalid json", encoding="utf-8")

            settings.ML_ARTIFACTS_DIR = temp_dir
            get_bundle.cache_clear()
            with self.assertRaises(ValueError) as ctx:
                get_bundle()
            self.assertIn("Invalid threshold artifact", str(ctx.exception))
        finally:
            settings.ML_ARTIFACTS_DIR = orig_artifacts
            get_bundle.cache_clear()
            shutil.rmtree(temp_dir, ignore_errors=True)

    # Numeric validation: NaN and Infinity in query params
    def test_query_param_float_rejects_nan_and_infinity(self):
        # min_score = NaN
        resp_nan = self.client.get(reverse("alert-list") + "?min_score=NaN")
        self.assertEqual(resp_nan.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("finite number", resp_nan.json()["detail"])

        # min_score = Infinity
        resp_inf = self.client.get(reverse("alert-list") + "?min_score=Infinity")
        self.assertEqual(resp_inf.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("finite number", resp_inf.json()["detail"])

        # min_amount = -Infinity
        resp_ninf = self.client.get(reverse("transaction-list") + "?min_amount=-Infinity")
        self.assertEqual(resp_ninf.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("finite number", resp_ninf.json()["detail"])

    # Duplicate transaction reference returns 400 Bad Request
    def test_duplicate_transaction_reference_returns_bad_request(self):
        Transaction.objects.create(
            card=self.card,
            trans_ref="DUP-REF-TEST-001",
            occurred_at=timezone.now(),
            merchant="Original Merchant",
            category=Transaction.Category.FOOD_DINING,
            amount=Decimal("15.00"),
        )

        response = self.client.post(
            reverse("transaction-list"),
            {
                "card": self.card.id,
                "occurred_at": timezone.now().isoformat(),
                "merchant": "Duplicate Merchant",
                "category": "food_dining",
                "amount": "20.00",
                "trans_ref": "DUP-REF-TEST-001",
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("trans_ref", response.data)

    def test_concurrent_duplicate_reference_integrity_error_returns_bad_request(self):
        # Transaction exists in DB so a real duplicate UNIQUE constraint violation occurs at DB level
        Transaction.objects.create(
            card=self.card,
            trans_ref="CONCURRENT-DUP-001",
            occurred_at=timezone.now(),
            merchant="First Inserted",
            category=Transaction.Category.FOOD_DINING,
            amount=Decimal("25.00"),
        )
        # Simulate race condition: serializer validation passed, allowing the request to hit the real DB
        with patch("transactions.serializers.TransactionCreateSerializer.validate_trans_ref", side_effect=lambda x: x):
            response = self.client.post(
                reverse("transaction-list"),
                {
                    "card": self.card.id,
                    "occurred_at": timezone.now().isoformat(),
                    "merchant": "Raced Duplicate",
                    "category": "food_dining",
                    "amount": "30.00",
                    "trans_ref": "CONCURRENT-DUP-001",
                },
                format="json",
            )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("trans_ref", response.data)
        self.assertIn("already exists", str(response.data["trans_ref"]))

    def test_unrelated_integrity_error_with_supplied_ref_is_re_raised(self):
        # Supplied reference does NOT exist in DB; an unrelated DB IntegrityError must be re-raised
        with patch("transactions.views.ingest_transaction", side_effect=IntegrityError("FOREIGN KEY constraint failed")):
            with self.assertRaises(IntegrityError):
                self.client.post(
                    reverse("transaction-list"),
                    {
                        "card": self.card.id,
                        "occurred_at": timezone.now().isoformat(),
                        "merchant": "Test Merchant",
                        "category": "food_dining",
                        "amount": "30.00",
                        "trans_ref": "UNRELATED-FAIL-REF",
                    },
                    format="json",
                )

    def test_unrelated_integrity_error_with_blank_ref_is_re_raised(self):
        # Auto-generated/blank reference; an unrelated IntegrityError must be re-raised
        with patch("transactions.views.ingest_transaction", side_effect=IntegrityError("NOT NULL constraint failed")):
            with self.assertRaises(IntegrityError):
                self.client.post(
                    reverse("transaction-list"),
                    {
                        "card": self.card.id,
                        "occurred_at": timezone.now().isoformat(),
                        "merchant": "Test Merchant",
                        "category": "food_dining",
                        "amount": "30.00",
                    },
                    format="json",
                )