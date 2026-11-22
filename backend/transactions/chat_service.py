import json
import logging
import os
import requests
from django.conf import settings
from .models import Alert, Card, Transaction

logger = logging.getLogger("fraudlens.chat")

# Primary and fallback Gemini models
GEMINI_MODELS = [
    "gemini-3.1-flash-lite",
    "gemini-3.8-flash",
    "gemini-flash-latest",
]


def _build_richie_context(user) -> str:
    """Build a compact, factual summary of the user's account state."""
    cards = Card.objects.filter(owner=user)
    card_count = cards.count()
    masked_cards = [f"•••• {c.card_number[-4:]}" for c in cards[:4]]
    cards_str = ", ".join(masked_cards) if masked_cards else "No registered cards yet"

    user_cards = Card.objects.filter(owner=user)
    open_alerts = Alert.objects.filter(transaction__card__in=user_cards, status=Alert.Status.OPEN)
    open_alert_count = open_alerts.count()

    recent_txns = (
        Transaction.objects.filter(card__in=user_cards)
        .select_related("alert")
        .order_by("-occurred_at")[:5]
    )
    txn_lines = []
    for t in recent_txns:
        has_alert = hasattr(t, "alert") and t.alert is not None
        status = f"FLAGGED SUSPICIOUS (Score: {t.alert.score:.2f})" if has_alert else "Normal"
        txn_lines.append(
            f"- Txn #{t.id}: ₹{t.amount:.2f} ({t.currency}) at {t.merchant} (Category: {t.category}) | Status: {status}"
        )
    recent_txns_str = "\n".join(txn_lines) if txn_lines else "No recent transactions found."

    context = f"""
USER CONTEXT (CONFIDENTIAL TO THIS USER):
- Name: {user.username} (First name: {user.first_name or user.username})
- Registered Cards Count: {card_count} ({cards_str})
- Open Unresolved Alerts: {open_alert_count}
- Recent Transactions:
{recent_txns_str}
"""
    return context.strip()


def ask_richie(user, user_message: str, chat_history: list = None) -> str:
    """Send conversation to Google Gemini and return Richie's assistant response."""
    api_key = os.environ.get("GEMINI_API_KEY", "").strip()
    if not api_key:
        return (
            "Hi there! I am Richie, your FraudLens assistant. "
            "My AI engine is currently not configured with an API key. "
            "Please configure GEMINI_API_KEY in the backend settings."
        )

    user_context = _build_richie_context(user)

    system_instruction = f"""
You are Richie, the personal AI fraud prevention & financial security assistant for FraudLens.
You are warm, reassuring, concise, security-conscious, and expert in banking fraud prevention.
You speak clearly without heavy jargon. When explaining fraud scores or risk factors to the user,
make them feel empowered and safe.

{user_context}

RULES:
1. Greet the user naturally when appropriate (User's name is {user.first_name or user.username}).
2. Use the user's live context to answer questions about their account, alerts, or transactions accurately.
3. If they ask about a suspicious transaction or how to report fraud, give immediate, clear steps:
   - Advise them to use the 'Report Fraud' or 'Dispute' button on the alert or transaction screen.
   - Recommend freezing/locking their card if they suspect unauthorized activity.
   - Remind them never to share OTPs or PINs with anyone.
4. If they ask how to use FraudLens features (e.g. adding cards, recording transactions, switching currency), guide them through the app.
5. Keep responses concise, friendly, and formatted in clean markdown (bullet points or short paragraphs).
6. Politely refuse queries that are completely unrelated to finance, fraud prevention, security, or the FraudLens app.
"""

    # Format contents for Gemini generateContent API
    contents = []

    # Inject system instruction as first user/model grounding turn
    contents.append({
        "role": "user",
        "parts": [{"text": f"SYSTEM INSTRUCTION & CONTEXT:\n{system_instruction}"}],
    })
    contents.append({
        "role": "model",
        "parts": [{"text": f"Understood! I am Richie, your FraudLens security assistant. Hello {user.first_name or user.username}! How can I help you today?"}],
    })

    # Append recent chat history if provided
    if chat_history and isinstance(chat_history, list):
        for turn in chat_history[-6:]:
            role = "user" if turn.get("sender") == "user" else "model"
            text = (turn.get("text") or "").strip()
            if text:
                contents.append({"role": role, "parts": [{"text": text}]})

    # Append the latest user query
    contents.append({"role": "user", "parts": [{"text": user_message.strip()}]})

    # Attempt calling Gemini models with fallback
    last_error = None
    for model in GEMINI_MODELS:
        endpoint = f"https://generativelanguage.googleapis.com/v1/models/{model}:generateContent?key={api_key}"
        try:
            resp = requests.post(
                endpoint,
                headers={"Content-Type": "application/json"},
                json={
                    "contents": contents,
                    "generationConfig": {
                        "temperature": 0.7,
                        "maxOutputTokens": 600,
                    },
                },
                timeout=12,
            )
            if resp.status_code == 200:
                data = resp.json()
                candidates = data.get("candidates", [])
                if candidates and "content" in candidates[0]:
                    parts = candidates[0]["content"].get("parts", [])
                    if parts and "text" in parts[0]:
                        return parts[0]["text"].strip()
            else:
                err_msg = resp.text[:200]
                logger.warning("Gemini model %s returned status %d: %s", model, resp.status_code, err_msg)
                last_error = f"Model {model} returned {resp.status_code}"
        except Exception as exc:
            logger.warning("Gemini model %s request exception: %s", model, exc)
            last_error = str(exc)

    logger.error("All Gemini models failed. Last error: %s", last_error)
    return (
        "I'm having a little trouble connecting to my knowledge base right now. "
        "Please check your internet connection or try again in a moment!"
    )
