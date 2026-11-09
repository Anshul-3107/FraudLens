package com.fraudlens.fraudlens

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.telephony.SmsMessage
import android.util.Log

class BankSmsReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "FraudLensBankSms"
        const val ACTION_BANK_SMS = "com.fraudlens.fraudlens.BANK_SMS_RECEIVED"
        const val EXTRA_SENDER = "sender"
        const val EXTRA_BODY = "body"
        const val EXTRA_TIMESTAMP = "timestamp"

        // Common Indian Bank DLT SMS Header patterns
        // e.g. VK-HDFCBK, AD-SBIINB, AX-ICICIB, BZ-KOTAKB, VM-AXISBK, etc.
        val BANK_SENDER_PATTERNS = listOf(
            "HDFC", "SBI", "ICICI", "AXIS", "KOTAK", "PNB", "BOB", "CANARA",
            "UNION", "INDUS", "YES", "PAYTM", "CITI", "SCB", "HSBC", "BANK"
        )
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages: Array<SmsMessage> = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        if (messages.isEmpty()) return

        val sender = messages[0].displayOriginatingAddress ?: ""
        val body = messages.joinToString("") { it.displayMessageBody ?: "" }
        val timestamp = messages[0].timestampMillis

        Log.d(TAG, "SMS received from '$sender': $body")

        val upperSender = sender.uppercase()
        val isBankSender = BANK_SENDER_PATTERNS.any { upperSender.contains(it) }

        // Also check if body contains standard Indian banking debit keywords
        val upperBody = body.uppercase()
        val hasDebitKeywords = (upperBody.contains("DEBITED") ||
                upperBody.contains("SENT") ||
                upperBody.contains("PAID") ||
                upperBody.contains("SPENT")) &&
                (upperBody.contains("RS") || upperBody.contains("INR") || upperBody.contains("₹"))

        if (isBankSender || hasDebitKeywords) {
            Log.d(TAG, "Identified Bank Debit SMS from $sender. Broadcasting to Flutter engine...")
            val broadcastIntent = Intent(ACTION_BANK_SMS).apply {
                putExtra(EXTRA_SENDER, sender)
                putExtra(EXTRA_BODY, body)
                putExtra(EXTRA_TIMESTAMP, timestamp)
                setPackage(context?.packageName)
            }
            context?.sendBroadcast(broadcastIntent)
        }
    }
}
