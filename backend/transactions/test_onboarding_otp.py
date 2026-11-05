from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from .models import Card, PhoneVerification
from .sms_service import hash_otp

User = get_user_model()


class OnboardingOtpTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.test_phone = "+919876543210"

    def test_send_otp_success(self):
        resp = self.client.post("/api/auth/phone/send-otp/", {"phone": self.test_phone})
        self.assertEqual(resp.status_code, 200)
        self.assertIn("Verification code sent", resp.data["detail"])

        # Verify db record was created
        record = PhoneVerification.objects.filter(phone_number=self.test_phone).first()
        self.assertIsNotNone(record)
        self.assertFalse(record.is_verified)
        self.assertGreater(record.expires_at, timezone.now())

    def test_send_otp_invalid_phone(self):
        resp = self.client.post("/api/auth/phone/send-otp/", {"phone": "123"})
        self.assertEqual(resp.status_code, 400)

    def test_verify_otp_success_creates_user_and_token(self):
        # Create record with known OTP
        code = "123456"
        otp_hash = hash_otp(self.test_phone, code)
        PhoneVerification.objects.create(
            phone_number=self.test_phone,
            otp_hash=otp_hash,
            expires_at=timezone.now() + timezone.timedelta(minutes=5),
        )

        resp = self.client.post("/api/auth/phone/verify-otp/", {
            "phone": self.test_phone,
            "code": code,
        })
        self.assertEqual(resp.status_code, 200)
        self.assertIn("token", resp.data)
        self.assertIn("username", resp.data)

        # Record should be verified
        record = PhoneVerification.objects.get(phone_number=self.test_phone)
        self.assertTrue(record.is_verified)

    def test_verify_otp_wrong_code_increments_attempts(self):
        code = "123456"
        otp_hash = hash_otp(self.test_phone, code)
        PhoneVerification.objects.create(
            phone_number=self.test_phone,
            otp_hash=otp_hash,
            expires_at=timezone.now() + timezone.timedelta(minutes=5),
        )

        resp = self.client.post("/api/auth/phone/verify-otp/", {
            "phone": self.test_phone,
            "code": "999999",
        })
        self.assertEqual(resp.status_code, 400)
        self.assertIn("Incorrect verification code", resp.data["error"])

        record = PhoneVerification.objects.get(phone_number=self.test_phone)
        self.assertEqual(record.attempts, 1)

    def test_link_bank_account_authenticated(self):
        user = User.objects.create_user(username="test_bank_user", password="password123")
        self.client.force_authenticate(user=user)

        resp = self.client.post("/api/accounts/link-bank/", {
            "bank_name": "HDFC Bank",
            "account_number": "50100492819719",
            "home_lat": 19.0760,
            "home_long": 72.8777,
        })
        self.assertEqual(resp.status_code, 201)
        self.assertEqual(resp.data["label"], "HDFC Bank A/c •• 9719")

        card = Card.objects.filter(owner=user).first()
        self.assertIsNotNone(card)
        self.assertEqual(card.label, "HDFC Bank A/c •• 9719")
