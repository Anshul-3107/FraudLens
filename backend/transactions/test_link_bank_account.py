from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient

from .models import Card

User = get_user_model()


class LinkBankAccountTests(TestCase):
    def setUp(self):
        self.client = APIClient()

    def test_link_bank_account_authenticated(self):
        user = User.objects.create_user(
            username="test_bank_user", password="password123"
        )
        self.client.force_authenticate(user=user)

        resp = self.client.post(
            "/api/accounts/link-bank/",
            {
                "bank_name": "HDFC Bank",
                "account_number": "50100492819719",
                "home_lat": 19.0760,
                "home_long": 72.8777,
            },
        )
        self.assertEqual(resp.status_code, 201)
        self.assertEqual(resp.data["label"], "HDFC Bank A/c •• 9719")

        card = Card.objects.filter(owner=user).first()
        self.assertIsNotNone(card)
        self.assertEqual(card.label, "HDFC Bank A/c •• 9719")
