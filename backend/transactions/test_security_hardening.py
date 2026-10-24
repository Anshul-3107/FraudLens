"""Comprehensive security hardening test suite for FraudLens DRF backend.

Tests verify:
1. Unauthenticated access enforcement across all protected endpoints.
2. User isolation and authorization boundaries (IDOR prevention).
3. Staff access boundaries and privilege separation.
4. Registration and authentication input validation (password strength, username uniqueness, staff flag injection prevention).
5. Token revocation and logout semantics.
6. Input bounds and data integrity (amounts, coordinates, date ranges, search lengths, duplicate references).
7. Production error sanitization (traceback/path suppression).
8. Rate throttling behavior on authentication endpoints.
9. Settings fail-closed validation for production secrets and ALLOWED_HOSTS.
"""
from decimal import Decimal
import json
from unittest.mock import MagicMock, patch

from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.exceptions import ImproperlyConfigured
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.test import APIClient

from transactions.exceptions import custom_exception_handler
from transactions.models import Alert, Card, Investigation, Transaction

User = get_user_model()


class SecurityHardeningBaseTestCase(TestCase):
    @classmethod
    def setUpTestData(cls):
        # User A (regular user)
        cls.user_a = User.objects.create_user(
            username="user_alice",
            password="StrongPassword123!",
            email="alice@example.com",
        )
        cls.token_a, _ = Token.objects.get_or_create(user=cls.user_a)

        # User B (regular user)
        cls.user_b = User.objects.create_user(
            username="user_bob",
            password="StrongPassword123!",
            email="bob@example.com",
        )
        cls.token_b, _ = Token.objects.get_or_create(user=cls.user_b)

        # Staff user
        cls.user_staff = User.objects.create_user(
            username="analyst_staff",
            password="StrongStaffPassword123!",
            email="staff@example.com",
            is_staff=True,
        )
        cls.token_staff, _ = Token.objects.get_or_create(user=cls.user_staff)

        # Card A for User A
        cls.card_a = Card.objects.create(
            owner=cls.user_a,
            card_ref="CARD-ALICE-1111",
            label="Alice Card",
        )

        # Card B for User B
        cls.card_b = Card.objects.create(
            owner=cls.user_b,
            card_ref="CARD-BOB-2222",
            label="Bob Card",
        )

        # Transactions for Card A
        cls.txn_a = Transaction.objects.create(
            card=cls.card_a,
            occurred_at=timezone.now(),
            merchant="Coffee Shop",
            category="food_dining",
            amount=Decimal("15.50"),
            trans_ref="TXN-ALICE-001",
        )

        # Alert on Txn A
        cls.alert_a = Alert.objects.create(
            transaction=cls.txn_a,
            score=0.92,
            threshold=0.85,
            status=Alert.Status.OPEN,
            reasons=["High anomalous spend"],
        )

        # Investigation on Alert A
        cls.investigation_a = Investigation.objects.create(
            alert=cls.alert_a,
            analyst=cls.user_a,
            verdict=Investigation.Verdict.CONFIRMED_FRAUD,
            notes="Confirmed fraud attempt on Alice card",
        )

        # Transactions for Card B
        cls.txn_b = Transaction.objects.create(
            card=cls.card_b,
            occurred_at=timezone.now(),
            merchant="Electronics Superstore",
            category="shopping_net",
            amount=Decimal("899.99"),
            trans_ref="TXN-BOB-001",
        )

        # Alert on Txn B
        cls.alert_b = Alert.objects.create(
            transaction=cls.txn_b,
            score=0.88,
            threshold=0.85,
            status=Alert.Status.OPEN,
            reasons=["High value transaction"],
        )


class UnauthenticatedAccessSecurityTests(SecurityHardeningBaseTestCase):
    def setUp(self):
        self.anon_client = APIClient()

    def test_protected_endpoints_reject_unauthenticated_requests(self):
        protected_endpoints = [
            ("get", "/api/cards/"),
            ("get", f"/api/cards/{self.card_a.id}/"),
            ("get", "/api/transactions/"),
            ("get", f"/api/transactions/{self.txn_a.id}/"),
            ("post", "/api/transactions/"),
            ("get", "/api/alerts/"),
            ("get", f"/api/alerts/{self.alert_a.id}/"),
            ("post", f"/api/alerts/{self.alert_a.id}/investigate/"),
            ("get", "/api/investigations/"),
            ("get", f"/api/investigations/{self.investigation_a.id}/"),
            ("get", "/api/summary/"),
            ("get", "/api/auth/me/"),
            ("post", "/api/auth/logout/"),
        ]

        for method, url in protected_endpoints:
            with self.subTest(method=method, url=url):
                func = getattr(self.anon_client, method)
                response = func(url)
                self.assertEqual(
                    response.status_code,
                    status.HTTP_401_UNAUTHORIZED,
                    f"Expected 401 for unauthenticated {method.upper()} {url}, got {response.status_code}",
                )

    def test_public_endpoints_allow_unauthenticated_access(self):
        # Health check
        res_health = self.anon_client.get("/api/health/")
        self.assertEqual(res_health.status_code, status.HTTP_200_OK)
        self.assertEqual(res_health.json(), {"status": "ok", "service": "fraudlens-backend"})

        # Registration (validates input without auth)
        res_reg = self.anon_client.post("/api/auth/register/", {})
        self.assertEqual(res_reg.status_code, status.HTTP_400_BAD_REQUEST)

        # Login (validates input without auth)
        res_login = self.anon_client.post("/api/auth/login/", {})
        self.assertEqual(res_login.status_code, status.HTTP_400_BAD_REQUEST)


class UserIsolationAndAuthorizationTests(SecurityHardeningBaseTestCase):
    def setUp(self):
        self.client_a = APIClient()
        self.client_a.credentials(HTTP_AUTHORIZATION=f"Token {self.token_a.key}")

        self.client_b = APIClient()
        self.client_b.credentials(HTTP_AUTHORIZATION=f"Token {self.token_b.key}")

    def test_user_a_cannot_see_user_b_cards(self):
        res = self.client_a.get("/api/cards/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        ids = [item["id"] for item in res.json().get("results", res.json())]
        self.assertIn(self.card_a.id, ids)
        self.assertNotIn(self.card_b.id, ids)

        # Direct ID access
        res_direct = self.client_a.get(f"/api/cards/{self.card_b.id}/")
        self.assertEqual(res_direct.status_code, status.HTTP_404_NOT_FOUND)

    def test_user_a_cannot_see_user_b_transactions(self):
        res = self.client_a.get("/api/transactions/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        ids = [item["id"] for item in res.json().get("results", res.json())]
        self.assertIn(self.txn_a.id, ids)
        self.assertNotIn(self.txn_b.id, ids)

        # Direct ID access
        res_direct = self.client_a.get(f"/api/transactions/{self.txn_b.id}/")
        self.assertEqual(res_direct.status_code, status.HTTP_404_NOT_FOUND)

    def test_user_a_cannot_post_transaction_to_user_b_card(self):
        payload = {
            "card": self.card_b.id,
            "occurred_at": timezone.now().isoformat(),
            "merchant": "Unauthorized Merchant",
            "category": "shopping_net",
            "amount": "50.00",
        }
        res = self.client_a.post("/api/transactions/", payload, format="json")
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("card", res.data)
        self.assertIn("No card with that id on your account", str(res.data["card"]))

    def test_user_a_cannot_see_or_investigate_user_b_alerts(self):
        # List alerts
        res = self.client_a.get("/api/alerts/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        ids = [item["id"] for item in res.json().get("results", res.json())]
        self.assertIn(self.alert_a.id, ids)
        self.assertNotIn(self.alert_b.id, ids)

        # Direct access
        res_direct = self.client_a.get(f"/api/alerts/{self.alert_b.id}/")
        self.assertEqual(res_direct.status_code, status.HTTP_404_NOT_FOUND)

        # Attempt investigate
        res_investigate = self.client_a.post(
            f"/api/alerts/{self.alert_b.id}/investigate/",
            {"verdict": "false_positive", "notes": "Attacker note"},
            format="json",
        )
        self.assertEqual(res_investigate.status_code, status.HTTP_404_NOT_FOUND)
        self.alert_b.refresh_from_db()
        self.assertEqual(self.alert_b.status, Alert.Status.OPEN)

    def test_user_a_cannot_see_user_b_investigations(self):
        # Create investigation on Alert B by User B
        inv_b = Investigation.objects.create(
            alert=self.alert_b,
            analyst=self.user_b,
            verdict=Investigation.Verdict.FALSE_POSITIVE,
            notes="Bob notes",
        )

        res = self.client_a.get("/api/investigations/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        ids = [item["id"] for item in res.json().get("results", res.json())]
        self.assertIn(self.investigation_a.id, ids)
        self.assertNotIn(inv_b.id, ids)

        # Direct access
        res_direct = self.client_a.get(f"/api/investigations/{inv_b.id}/")
        self.assertEqual(res_direct.status_code, status.HTTP_404_NOT_FOUND)

    def test_summary_scoped_strictly_to_authenticated_user(self):
        res = self.client_a.get("/api/summary/")
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        data = res.json()
        self.assertEqual(data["transaction_count"], 1)
        self.assertEqual(data["total_spend"], float(self.txn_a.amount))


class StaffAccessBoundariesTests(SecurityHardeningBaseTestCase):
    def setUp(self):
        self.client_staff = APIClient()
        self.client_staff.credentials(HTTP_AUTHORIZATION=f"Token {self.token_staff.key}")

        self.client_user = APIClient()
        self.client_user.credentials(HTTP_AUTHORIZATION=f"Token {self.token_a.key}")

    def test_staff_can_view_all_cards_transactions_alerts(self):
        res_cards = self.client_staff.get("/api/cards/")
        card_ids = [c["id"] for c in res_cards.json().get("results", res_cards.json())]
        self.assertIn(self.card_a.id, card_ids)
        self.assertIn(self.card_b.id, card_ids)

        res_txns = self.client_staff.get("/api/transactions/")
        txn_ids = [t["id"] for t in res_txns.json().get("results", res_txns.json())]
        self.assertIn(self.txn_a.id, txn_ids)
        self.assertIn(self.txn_b.id, txn_ids)

        res_alerts = self.client_staff.get("/api/alerts/")
        alert_ids = [a["id"] for a in res_alerts.json().get("results", res_alerts.json())]
        self.assertIn(self.alert_a.id, alert_ids)
        self.assertIn(self.alert_b.id, alert_ids)

    def test_me_endpoint_correctly_reports_staff_flag(self):
        res_staff = self.client_staff.get("/api/auth/me/")
        self.assertTrue(res_staff.json()["is_staff"])

        res_regular = self.client_user.get("/api/auth/me/")
        self.assertFalse(res_regular.json()["is_staff"])


class AuthenticationAndTokenSecurityTests(TestCase):
    def setUp(self):
        self.client = APIClient()

    def test_register_validation_and_staff_injection_prevention(self):
        # Attempt to register with is_staff=True and is_superuser=True
        payload = {
            "username": "attacker",
            "password": "StrongPassword123!",
            "email": "attacker@example.com",
            "is_staff": True,
            "is_superuser": True,
        }
        res = self.client.post("/api/auth/register/", payload, format="json")
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertIn("token", res.data)

        user = User.objects.get(username="attacker")
        self.assertFalse(user.is_staff)
        self.assertFalse(user.is_superuser)

    def test_register_rejects_weak_password(self):
        payload = {
            "username": "weakuser",
            "password": "123",
            "email": "weak@example.com",
        }
        res = self.client.post("/api/auth/register/", payload, format="json")
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("password", res.data)

    def test_register_rejects_short_or_blank_username(self):
        for bad_username in ["", "  ", "ab"]:
            with self.subTest(username=bad_username):
                payload = {
                    "username": bad_username,
                    "password": "StrongPassword123!",
                }
                res = self.client.post("/api/auth/register/", payload, format="json")
                self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    def test_register_rejects_case_insensitive_duplicate_username(self):
        User.objects.create_user(username="OriginalUser", password="StrongPassword123!")
        payload = {
            "username": "originaluser",
            "password": "AnotherStrongPassword123!",
        }
        res = self.client.post("/api/auth/register/", payload, format="json")
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("username", res.data)

    def test_token_revocation_on_logout(self):
        # Create user and obtain token
        user = User.objects.create_user(username="logout_user", password="StrongPassword123!")
        res_login = self.client.post(
            "/api/auth/login/",
            {"username": "logout_user", "password": "StrongPassword123!"},
            format="json",
        )
        self.assertEqual(res_login.status_code, status.HTTP_200_OK)
        token_key = res_login.data["token"]

        # Call authenticated endpoint with token
        auth_client = APIClient()
        auth_client.credentials(HTTP_AUTHORIZATION=f"Token {token_key}")
        res_me = auth_client.get("/api/auth/me/")
        self.assertEqual(res_me.status_code, status.HTTP_200_OK)

        # Call logout endpoint
        res_logout = auth_client.post("/api/auth/logout/")
        self.assertEqual(res_logout.status_code, status.HTTP_200_OK)
        self.assertIn("detail", res_logout.data)

        # Verify token was removed from database
        self.assertFalse(Token.objects.filter(key=token_key).exists())

        # Calling authenticated endpoint with old token now returns 401
        res_me_after = auth_client.get("/api/auth/me/")
        self.assertEqual(res_me_after.status_code, status.HTTP_401_UNAUTHORIZED)


class InputValidationAndIntegrityTests(SecurityHardeningBaseTestCase):
    def setUp(self):
        self.client_a = APIClient()
        self.client_a.credentials(HTTP_AUTHORIZATION=f"Token {self.token_a.key}")

    def test_transaction_create_rejects_negative_or_zero_amount(self):
        for bad_amount in ["0.00", "-15.00", "0"]:
            with self.subTest(amount=bad_amount):
                payload = {
                    "card": self.card_a.id,
                    "occurred_at": timezone.now().isoformat(),
                    "merchant": "Test Store",
                    "category": "shopping_net",
                    "amount": bad_amount,
                }
                res = self.client_a.post("/api/transactions/", payload, format="json")
                self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    def test_transaction_create_rejects_exorbitant_amount(self):
        payload = {
            "card": self.card_a.id,
            "occurred_at": timezone.now().isoformat(),
            "merchant": "Test Store",
            "category": "shopping_net",
            "amount": "10000001.00",  # exceeds $10M ceiling
        }
        res = self.client_a.post("/api/transactions/", payload, format="json")
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("amount", res.data)

    def test_transaction_create_rejects_non_finite_coordinates(self):
        for non_finite in ["nan", "inf", "-inf"]:
            with self.subTest(val=non_finite):
                payload = {
                    "card": self.card_a.id,
                    "occurred_at": timezone.now().isoformat(),
                    "merchant": "Test Store",
                    "category": "shopping_net",
                    "amount": "25.00",
                    "merch_lat": non_finite,
                    "merch_long": -73.98,
                }
                res = self.client_a.post("/api/transactions/", payload, format="json")
                self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    def test_transaction_create_rejects_blank_merchant(self):
        for bad_merchant in ["", "   "]:
            with self.subTest(merchant=bad_merchant):
                payload = {
                    "card": self.card_a.id,
                    "occurred_at": timezone.now().isoformat(),
                    "merchant": bad_merchant,
                    "category": "shopping_net",
                    "amount": "25.00",
                }
                res = self.client_a.post("/api/transactions/", payload, format="json")
                self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    def test_inverted_date_range_rejected_on_transactions_and_summary(self):
        # date_from > date_to
        params = {"date_from": "2026-10-25", "date_to": "2026-10-20"}
        res_txns = self.client_a.get("/api/transactions/", params)
        self.assertEqual(res_txns.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("date_from", res_txns.json().get("detail", ""))

        res_sum = self.client_a.get("/api/summary/", params)
        self.assertEqual(res_sum.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("date_from", res_sum.json().get("detail", ""))

    def test_excessive_search_query_parameter_length_rejected(self):
        huge_search = "A" * 150
        res = self.client_a.get("/api/transactions/", {"search": huge_search})
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("search", res.json().get("detail", ""))


class ProductionSettingsAndErrorSanitizationTests(TestCase):
    def test_production_error_handler_sanitizes_500_responses(self):
        # Simulates an unhandled internal exception with IS_PRODUCTION=True, DEBUG=False
        fake_exc = RuntimeError("Secret DB password or path: /var/secrets/key.pem")
        mock_view = MagicMock()
        mock_request = MagicMock()
        mock_request.user.username = "test_user"
        context = {"view": mock_view, "request": mock_request}

        with override_settings(IS_PRODUCTION=True, DEBUG=False):
            res = custom_exception_handler(fake_exc, context)
            self.assertIsNotNone(res)
            self.assertEqual(res.status_code, status.HTTP_500_INTERNAL_SERVER_ERROR)
            self.assertEqual(res.data.get("error_code"), "INTERNAL_SERVER_ERROR")
            # Verify no secret text or path was leaked in response
            self.assertNotIn("Secret DB password", str(res.data))
            self.assertNotIn("/var/secrets", str(res.data))

    def test_production_settings_validation_rejects_insecure_secrets(self):
        # When IS_PRODUCTION=True, a missing or default SECRET_KEY must fail
        from config.settings import DEFAULT_INSECURE_SECRET, validate_security_settings

        # Insecure default key in production
        with self.assertRaises(ImproperlyConfigured) as ctx:
            validate_security_settings(
                secret_key=DEFAULT_INSECURE_SECRET,
                debug=False,
                allowed_hosts=["fraudlens.example.com"],
                is_production=True,
            )
        self.assertIn("Cannot use insecure default SECRET_KEY", str(ctx.exception))

        # Wildcard host in production
        with self.assertRaises(ImproperlyConfigured) as ctx:
            validate_security_settings(
                secret_key="a" * 50,
                debug=False,
                allowed_hosts=["*"],
                is_production=True,
            )
        self.assertIn("Wildcard '*' in ALLOWED_HOSTS", str(ctx.exception))

        # DEBUG=True in production
        with self.assertRaises(ImproperlyConfigured) as ctx:
            validate_security_settings(
                secret_key="a" * 50,
                debug=True,
                allowed_hosts=["fraudlens.example.com"],
                is_production=True,
            )
        self.assertIn("DEBUG cannot be True in production", str(ctx.exception))


class DuplicateTransactionReferenceTests(SecurityHardeningBaseTestCase):
    def setUp(self):
        self.client_a = APIClient()
        self.client_a.credentials(HTTP_AUTHORIZATION=f"Token {self.token_a.key}")

    def test_duplicate_trans_ref_rejected(self):
        payload = {
            "card": self.card_a.id,
            "occurred_at": timezone.now().isoformat(),
            "merchant": "Unique Coffee Shop",
            "category": "food_dining",
            "amount": "12.00",
            "trans_ref": "TXN-IDEMPOTENT-001",
        }
        res1 = self.client_a.post("/api/transactions/", payload, format="json")
        self.assertEqual(res1.status_code, status.HTTP_201_CREATED)

        # Attempt to insert same trans_ref again
        res2 = self.client_a.post("/api/transactions/", payload, format="json")
        self.assertEqual(res2.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("trans_ref", res2.data)
        self.assertIn("already exists", str(res2.data["trans_ref"]))


class RateThrottlingSecurityTests(TestCase):
    def test_login_rate_limiting_enforcement(self):
        client = APIClient()
        from rest_framework.throttling import ScopedRateThrottle

        with patch.dict(ScopedRateThrottle.THROTTLE_RATES, {"auth_login": "3/minute"}):
            responses = []
            for _ in range(5):
                res = client.post(
                    "/api/auth/login/",
                    {"username": "testuser", "password": "wrongpassword"},
                    format="json",
                )
                responses.append(res.status_code)

            # At least one request beyond the limit must receive 429 Too Many Requests
            self.assertIn(
                status.HTTP_429_TOO_MANY_REQUESTS,
                responses,
                f"Expected rate limit 429 response in {responses}",
            )


class ScoringAndAlertCompatibilityTests(SecurityHardeningBaseTestCase):
    def setUp(self):
        self.client_a = APIClient()
        self.client_a.credentials(HTTP_AUTHORIZATION=f"Token {self.token_a.key}")

    def test_transaction_scoring_contract_compatibility(self):
        payload = {
            "card": self.card_a.id,
            "occurred_at": timezone.now().isoformat(),
            "merchant": "Contract Verification Merchant",
            "category": "shopping_net",
            "amount": "45.00",
            "merch_lat": 40.7128,
            "merch_long": -74.0060,
            "trans_ref": "TXN-CONTRACT-VERIFY",
        }
        res = self.client_a.post("/api/transactions/", payload, format="json")
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        data = res.json()

        # Validate response schema contract
        self.assertIn("transaction", data)
        self.assertIn("scoring", data)
        self.assertIn("score", data["scoring"])
        self.assertIn("flagged", data["scoring"])
        self.assertIn("threshold", data["scoring"])
        self.assertIn("reasons", data["scoring"])
        self.assertIsInstance(data["scoring"]["score"], float)
        self.assertIsInstance(data["scoring"]["flagged"], bool)
        self.assertIsInstance(data["scoring"]["reasons"], list)

