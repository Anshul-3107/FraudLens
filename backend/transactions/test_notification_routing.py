from datetime import datetime, timezone
from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient

from .models import Card, Transaction, UserBehaviorProfile

User = get_user_model()


class NotificationRoutingTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(username="upi_tester", password="password123")
        self.client.force_authenticate(user=self.user)

        # Primary registered bank card
        self.card = Card.objects.create(
            owner=self.user,
            card_ref="bank_upi_9719",
            label="HDFC Bank A/c •• 9719",
            home_lat=19.0760,
            home_long=72.8777,
        )

    def test_registered_account_notification_routes_to_user_card(self):
        payload = {
            "amount": 250.0,
            "merchant": "Starbucks Coffee",
            "category": "food_dining",
            "last4": "9719",
            "bank_name": "HDFC Bank",
            "package_name": "com.google.android.apps.nbu.paisa.user",
        }
        resp = self.client.post("/api/transactions/process_notification/", payload)
        self.assertEqual(resp.status_code, 201)
        data = resp.data

        self.assertTrue(data["scoring"]["is_registered_account"])
        self.assertEqual(data["transaction"]["card"], self.card.id)
        self.assertIn("routing_destination", data["scoring"])
        self.assertIn("card_color", data["scoring"])

        # Check behavior profile updated for registered card
        profile = UserBehaviorProfile.objects.filter(card=self.card).first()
        self.assertIsNotNone(profile)
        self.assertEqual(profile.total_txns, 1)

    def test_unregistered_secondary_account_notification(self):
        # Transaction with unknown account last 4 digits
        payload = {
            "amount": 120.0,
            "merchant": "Local Bakery",
            "category": "food_dining",
            "last4": "4321",
            "bank_name": "SBI Bank",
            "package_name": "com.phonepe.app",
        }
        resp = self.client.post("/api/transactions/process_notification/", payload)
        self.assertEqual(resp.status_code, 201)
        data = resp.data

        self.assertFalse(data["scoring"]["is_registered_account"])
        self.assertNotEqual(data["transaction"]["card"], self.card.id)
        self.assertIn("Unregistered", data["transaction"]["card_label"])

        # Primary registered card behavior profile should NOT be affected
        profile = UserBehaviorProfile.objects.filter(card=self.card).first()
        self.assertIsNone(profile)  # Primary card untouched

    def test_deduplication_between_notification_and_bank_sms(self):
        # 1. First event: Google Pay Notification arrives
        payload1 = {
            "amount": 500.0,
            "merchant": "Starbucks Coffee",
            "category": "food_dining",
            "last4": "9719",
            "bank_name": "HDFC Bank",
            "package_name": "com.google.android.apps.nbu.paisa.user",
            "source": "notification",
        }
        resp1 = self.client.post("/api/transactions/process_notification/", payload1)
        self.assertEqual(resp1.status_code, 201)
        self.assertFalse(resp1.data["scoring"]["is_duplicate_enriched"])
        txn_id = resp1.data["transaction"]["id"]

        # 2. Second event: Bank SMS arrives 15 seconds later for the same charge
        payload2 = {
            "amount": 500.0,
            "merchant": "STARBUCKS MUMBAI",
            "category": "food_dining",
            "last4": "9719",
            "bank_name": "HDFC Bank",
            "package_name": "android.telephony.sms",
            "source": "sms",
        }
        resp2 = self.client.post("/api/transactions/process_notification/", payload2)
        # Should return 200 OK (deduplicated) rather than creating a new transaction
        self.assertEqual(resp2.status_code, 200)
        self.assertTrue(resp2.data["scoring"]["is_duplicate_enriched"])
        self.assertEqual(resp2.data["transaction"]["id"], txn_id)

        # Assert only ONE transaction exists in database
        self.assertEqual(Transaction.objects.filter(amount=500.0).count(), 1)
