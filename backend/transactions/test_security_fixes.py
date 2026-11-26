from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from .models import Card

User = get_user_model()


class SecurityFixesRegressionTests(TestCase):
    def setUp(self):
        self.user_a = User.objects.create_user(
            username="sec_user_a", password="Strong-Password-123!"
        )
        self.user_b = User.objects.create_user(
            username="sec_user_b", password="Strong-Password-123!"
        )
        self.client_a = APIClient()
        self.client_a.force_authenticate(user=self.user_a)
        self.client_b = APIClient()
        self.client_b.force_authenticate(user=self.user_b)

    def test_avatar_upload_rejects_svg_html_or_non_image_files(self):
        fake_svg = SimpleUploadedFile(
            "evil.svg",
            b'<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>',
            content_type="image/svg+xml",
        )
        res = self.client_a.post(
            "/api/auth/avatar/", {"avatar": fake_svg}, format="multipart"
        )
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

        fake_gif = SimpleUploadedFile(
            "avatar.gif",
            b"<html><script>alert(1)</script></html>",
            content_type="image/gif",
        )
        res2 = self.client_a.post(
            "/api/auth/avatar/", {"avatar": fake_gif}, format="multipart"
        )
        self.assertEqual(res2.status_code, status.HTTP_400_BAD_REQUEST)

    def test_avatar_requires_authentication_and_no_public_media_route(self):
        small_gif = (
            b"\x47\x49\x46\x38\x39\x61\x01\x00\x01\x00\x00\x00\x00\x21\xf9\x04"
            b"\x01\x00\x00\x00\x00\x2c\x00\x00\x00\x00\x01\x00\x01\x00\x00\x02"
            b"\x02\x44\x01\x00\x3b"
        )
        avatar = SimpleUploadedFile("avatar.gif", small_gif, content_type="image/gif")
        res = self.client_a.post(
            "/api/auth/avatar/", {"avatar": avatar}, format="multipart"
        )
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIn("/api/auth/avatar/", res.data["avatar_url"])

        # Unauthenticated fetch must fail 401
        anon_client = APIClient()
        self.assertEqual(
            anon_client.get("/api/auth/avatar/").status_code,
            status.HTTP_401_UNAUTHORIZED,
        )

        # User B does not see User A's avatar at /api/auth/avatar/
        self.assertEqual(
            self.client_b.get("/api/auth/avatar/").status_code,
            status.HTTP_404_NOT_FOUND,
        )

        # User A fetches their own avatar with nosniff header
        own_res = self.client_a.get("/api/auth/avatar/")
        self.assertEqual(own_res.status_code, status.HTTP_200_OK)
        self.assertEqual(own_res["X-Content-Type-Options"], "nosniff")
        b"".join(own_res.streaming_content)

        # Public /media/ route is disabled
        stored_name = self.user_a.profile.avatar.name
        self.assertEqual(
            anon_client.get(f"/media/{stored_name}").status_code,
            status.HTTP_404_NOT_FOUND,
        )

        # Clean up stored file after test
        self.client_a.delete("/api/auth/avatar/")

    def test_link_bank_and_process_notification_reject_invalid_coordinates(self):
        bad_bank = self.client_a.post(
            "/api/accounts/link-bank/",
            {
                "bank_name": "HDFC Bank",
                "account_number": "12345678",
                "home_lat": 999.0,
                "home_long": 72.8,
            },
            format="json",
        )
        self.assertEqual(bad_bank.status_code, status.HTTP_400_BAD_REQUEST)

        bad_notif = self.client_a.post(
            "/api/transactions/process_notification/",
            {
                "amount": 100.0,
                "merchant": "Coffee",
                "merch_lat": "NaN",
            },
            format="json",
        )
        self.assertEqual(bad_notif.status_code, status.HTTP_400_BAD_REQUEST)

    def test_richie_chat_works_with_linked_card_and_uses_header_api_key(self):
        Card.objects.create(
            owner=self.user_a,
            card_ref="bank_a_9719_abc",
            label="HDFC Bank A/c •• 9719",
        )
        captured = {}

        class FakeResp:
            status_code = 200

            def json(self):
                return {
                    "candidates": [
                        {"content": {"parts": [{"text": "Your account looks safe."}]}}
                    ]
                }

        def fake_post(url, headers=None, json=None, timeout=12):
            captured["url"] = url
            captured["headers"] = headers or {}
            captured["json"] = json
            return FakeResp()

        with patch.dict("os.environ", {"GEMINI_API_KEY": "test-secret-key"}):
            with patch("transactions.chat_service.requests.post", side_effect=fake_post):
                res = self.client_a.post(
                    "/api/chat/richie/",
                    {"message": "Check my cards"},
                    format="json",
                )

        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data["reply"], "Your account looks safe.")
        self.assertNotIn("test-secret-key", captured["url"])
        self.assertEqual(captured["headers"].get("x-goog-api-key"), "test-secret-key")
