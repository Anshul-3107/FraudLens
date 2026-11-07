from datetime import datetime, timezone
from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient

from .ingest import ingest_transaction
from .models import Card, Transaction, UserBehaviorProfile
from .personal_ml_service import (
    determine_graduation_phase,
    train_personal_model_for_card,
    update_behavior_profile_online,
)

User = get_user_model()


class PersonalMlTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="personal_tester", password="password123")
        self.card = Card.objects.create(
            owner=self.user,
            card_ref="bank_test_1234",
            label="HDFC Bank A/c •• 1234",
            home_lat=19.0760,
            home_long=72.8777,
        )

    def test_determine_graduation_phase(self):
        # Phase 1: < 16 txns
        phase, w_global, w_pers = determine_graduation_phase(5, has_trained_model=False)
        self.assertEqual(phase, 1)
        self.assertEqual(w_global, 1.0)
        self.assertEqual(w_pers, 0.0)

        # Phase 2: 16 to 50 txns
        phase, w_global, w_pers = determine_graduation_phase(25, has_trained_model=False)
        self.assertEqual(phase, 2)
        self.assertEqual(w_global, 0.85)
        self.assertEqual(w_pers, 0.15)

        # Phase 3: 51 to 100 txns with trained model
        phase, w_global, w_pers = determine_graduation_phase(60, has_trained_model=True)
        self.assertEqual(phase, 3)
        self.assertEqual(w_global, 0.50)
        self.assertEqual(w_pers, 0.50)

        # Phase 4: > 100 txns with trained model
        phase, w_global, w_pers = determine_graduation_phase(120, has_trained_model=True)
        self.assertEqual(phase, 4)
        self.assertEqual(w_global, 0.30)
        self.assertEqual(w_pers, 0.70)

    def test_online_behavior_profile_update(self):
        t1 = datetime(2026, 1, 10, 14, 0, 0, tzinfo=timezone.utc)
        update_behavior_profile_online(self.card, 150.0, t1, "Starbucks", "food_dining")

        profile = UserBehaviorProfile.objects.get(card=self.card)
        self.assertEqual(profile.total_txns, 1)
        self.assertEqual(profile.avg_amount, 150.0)
        self.assertIn(14, profile.active_hours)
        self.assertIn("Starbucks", profile.frequent_merchants)

        # Add second transaction
        t2 = datetime(2026, 1, 10, 16, 0, 0, tzinfo=timezone.utc)
        update_behavior_profile_online(self.card, 250.0, t2, "Amazon", "shopping_net")
        profile.refresh_from_db()
        self.assertEqual(profile.total_txns, 2)
        self.assertEqual(profile.avg_amount, 200.0)
        self.assertIn(16, profile.active_hours)

    def test_ingest_transaction_populates_scoring_personal_metadata(self):
        t = datetime(2026, 1, 10, 12, 0, 0, tzinfo=timezone.utc)
        txn, alert, result = ingest_transaction(
            card=self.card,
            occurred_at=t,
            merchant="Local Grocery",
            category="grocery_pos",
            amount=50.0,
        )
        self.assertIsNotNone(txn)
        self.assertIn("graduation_phase", result)
        self.assertIn("weights", result)
        self.assertEqual(result["graduation_phase"], 1)

        # Profile updated automatically
        profile = UserBehaviorProfile.objects.get(card=self.card)
        self.assertEqual(profile.total_txns, 1)

    def test_train_personal_model_requires_minimum_transactions(self):
        res = train_personal_model_for_card(self.card.id)
        self.assertFalse(res["success"])
        self.assertIn("At least 20 are required", res["error"])
