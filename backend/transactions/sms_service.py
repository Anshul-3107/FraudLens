import hashlib
import json
import logging
import os
import secrets
import urllib.parse
import urllib.request

logger = logging.getLogger("fraudlens.security")


def generate_otp_code(length: int = 6) -> str:
    """Generate a cryptographically secure numeric OTP."""
    digits = [str(secrets.randbelow(10)) for _ in range(length)]
    return "".join(digits)


def hash_otp(phone: str, otp: str, salt: str = "fraudlens_salt") -> str:
    """Hash OTP using SHA-256 with phone number salt to avoid storing plaintext in database."""
    content = f"{phone}:{otp}:{salt}".encode("utf-8")
    return hashlib.sha256(content).hexdigest()


def send_live_sms(phone: str, otp: str) -> dict:
    """Dispatches a real live SMS using configured gateway (Fast2SMS / Twilio).

    Supported Environment Variables:
    - FAST2SMS_API_KEY: Fast2SMS authorization key for direct Indian (+91) OTP / Quick SMS.
    - TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER: Twilio credentials.

    Returns:
        dict: {"success": bool, "channel": str, "gateway": str, "message": str}
    """
    message_text = f"Your FraudLens secure verification code is: {otp}. Valid for 5 minutes. Do not share this code."

    fast2sms_error_reason = ""
    # 1. Check Fast2SMS (Indian SMS Gateway - primary for Indian +91 numbers)
    fast2sms_key = os.environ.get("FAST2SMS_API_KEY", "").strip()
    if fast2sms_key:
        cleaned_phone = phone.replace("+91", "").replace(" ", "").replace("-", "")
        # Dedicated Fast2SMS 'otp' route (requires authorization header)
        try:
            url = "https://www.fast2sms.com/dev/bulkV2"
            payload = json.dumps({
                "route": "otp",
                "variables_values": otp,
                "numbers": cleaned_phone,
            }).encode("utf-8")

            req = urllib.request.Request(url, data=payload, method="POST")
            req.add_header("authorization", fast2sms_key)
            req.add_header("Content-Type", "application/json")
            with urllib.request.urlopen(req, timeout=10) as response:
                body = json.loads(response.read().decode("utf-8"))
                if body.get("return") is True:
                    logger.info("Fast2SMS live OTP delivered successfully to %s", phone[:6] + "XXXX")
                    return {
                        "success": True,
                        "channel": "live_sms",
                        "gateway": "fast2sms",
                        "message": "Live SMS dispatched via Fast2SMS",
                    }
                else:
                    logger.warning("Fast2SMS OTP route returned false: %s", body)
        except urllib.error.HTTPError as e:
            err_body = e.read().decode("utf-8", errors="ignore")
            logger.warning("Fast2SMS OTP route HTTP %s: %s", e.code, err_body)
            # Check if TRAI / Fast2SMS requires 1-time verification or recharge
            try:
                err_json = json.loads(err_body)
                err_msg = err_json.get("message", "")
            except Exception:
                err_msg = err_body
            fast2sms_error_reason = err_msg
        except Exception as e:
            logger.warning("Fast2SMS OTP route attempt failed: %s", e)
            fast2sms_error_reason = str(e)

        # Fallback to Fast2SMS Quick SMS ('q') route with JSON and authorization header
        try:
            url = "https://www.fast2sms.com/dev/bulkV2"
            payload = json.dumps({
                "route": "q",
                "message": message_text,
                "language": "english",
                "flash": 0,
                "numbers": cleaned_phone,
            }).encode("utf-8")

            req = urllib.request.Request(url, data=payload, method="POST")
            req.add_header("authorization", fast2sms_key)
            req.add_header("Content-Type", "application/json")
            with urllib.request.urlopen(req, timeout=10) as response:
                body = json.loads(response.read().decode("utf-8"))
                if body.get("return") is True:
                    logger.info("Fast2SMS Quick SMS delivered successfully to %s", phone[:6] + "XXXX")
                    return {
                        "success": True,
                        "channel": "live_sms",
                        "gateway": "fast2sms",
                        "message": "Live SMS dispatched via Fast2SMS Quick Route",
                    }
                else:
                    logger.error("Fast2SMS dispatch failed: %s", body.get("message"))
        except Exception as e:
            logger.error("Fast2SMS request failed for %s: %s", phone[:6] + "XXXX", e)

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

            with urllib.request.urlopen(req, timeout=8) as response:
                if response.status in (200, 201):
                    logger.info("Twilio live message delivered successfully to %s", phone[:6] + "XXXX")
                    return {
                        "success": True,
                        "channel": "live_sms",
                        "gateway": "twilio",
                        "message": "Live SMS dispatched via Twilio",
                    }
        except Exception as e:
            logger.error("Twilio dispatch failed for %s: %s", phone[:6] + "XXXX", e)

    # 3. Fallback / Local Development Simulation: Log prominently to server console
    print("\n" + "=" * 62)
    print(" [FRAUDLENS LIVE OTP SERVICE - TEST CONSOLE]")
    print(f" Recipient : {phone}")
    print(f" OTP Code  : {otp}")
    if fast2sms_key:
        print(f" Gateway   : Fast2SMS (API Key present, but gateway reported: {fast2sms_error_reason})")
    else:
        print(" Gateway   : Local Simulation (No FAST2SMS_API_KEY in .env)")
    print("=" * 62 + "\n")
    logger.info("[SMS-DEV-DISPATCH] Phone: %s | OTP: %s", phone, otp)

    return {
        "success": True,
        "channel": "console_simulation",
        "gateway": "fast2sms_pending_activation" if fast2sms_key else "none",
        "message": fast2sms_error_reason if fast2sms_key else "Logged to console simulation.",
    }
