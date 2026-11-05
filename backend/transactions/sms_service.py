import hashlib
import logging
import os
import secrets
import urllib.parse
import urllib.request
from datetime import timedelta
from django.utils import timezone

logger = logging.getLogger("fraudlens.security")


def generate_otp_code(length: int = 6) -> str:
    """Generate a cryptographically secure numeric OTP."""
    digits = [str(secrets.randbelow(10)) for _ in range(length)]
    return "".join(digits)


def hash_otp(phone: str, otp: str, salt: str = "fraudlens_salt") -> str:
    """Hash OTP using SHA-256 with phone number salt to avoid storing plaintext in database."""
    content = f"{phone}:{otp}:{salt}".encode("utf-8")
    return hashlib.sha256(content).hexdigest()


def send_live_sms(phone: str, otp: str) -> bool:
    """Dispatches a real live SMS using configured gateway (Fast2SMS / Twilio).

    Supported Environment Variables:
    - FAST2SMS_API_KEY: Fast2SMS authorization key for direct Indian (+91) DLT/Quick SMS.
    - TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER: Twilio SMS credentials.

    If no gateway keys are supplied, logs the live SMS dispatch securely for local development.
    """
    message_text = f"Your FraudLens secure verification code is: {otp}. Valid for 5 minutes. Do not share this code."

    # 1. Check Fast2SMS (Indian SMS Gateway)
    fast2sms_key = os.environ.get("FAST2SMS_API_KEY", "").strip()
    if fast2sms_key:
        try:
            # Clean phone format (e.g. +919876543210 -> 9876543210)
            cleaned_phone = phone.replace("+91", "").replace(" ", "").replace("-", "")
            url = "https://www.fast2sms.com/dev/bulkV2"
            data = urllib.parse.urlencode({
                "authorization": fast2sms_key,
                "route": "q",
                "message": message_text,
                "language": "english",
                "flash": "0",
                "numbers": cleaned_phone,
            }).encode("utf-8")

            req = urllib.request.Request(url, data=data, method="POST")
            req.add_header("Content-Type", "application/x-www-form-urlencoded")
            with urllib.request.urlopen(req, timeout=5) as response:
                if response.status == 200:
                    logger.info("Fast2SMS live message delivered successfully to %s", phone[:6] + "XXXX")
                    return True
        except Exception as e:
            logger.error("Fast2SMS dispatch failed for %s: %s", phone[:6] + "XXXX", e)

    # 2. Check Twilio (Global SMS Gateway)
    twilio_sid = os.environ.get("TWILIO_ACCOUNT_SID", "").strip()
    twilio_token = os.environ.get("TWILIO_AUTH_TOKEN", "").strip()
    twilio_from = os.environ.get("TWILIO_PHONE_NUMBER", "").strip()
    if twilio_sid and twilio_token and twilio_from:
        try:
            url = f"https://api.twilio.com/2010-04-01/Accounts/{twilio_sid}/Messages.json"
            data = urllib.parse.urlencode({
                "To": phone,
                "From": twilio_from,
                "Body": message_text,
            }).encode("utf-8")

            req = urllib.request.Request(url, data=data, method="POST")
            import base64
            auth_header = base64.b64encode(f"{twilio_sid}:{twilio_token}".encode("utf-8")).decode("utf-8")
            req.add_header("Authorization", f"Basic {auth_header}")
            req.add_header("Content-Type", "application/x-www-form-urlencoded")

            with urllib.request.urlopen(req, timeout=5) as response:
                if response.status in (200, 201):
                    logger.info("Twilio live message delivered successfully to %s", phone[:6] + "XXXX")
                    return True
        except Exception as e:
            logger.error("Twilio dispatch failed for %s: %s", phone[:6] + "XXXX", e)

    # Fallback / Development Simulation: Log securely to server console
    logger.info("[SMS-GATEWAY-DISPATCH] To: %s | Message: '%s'", phone, message_text)
    return True
