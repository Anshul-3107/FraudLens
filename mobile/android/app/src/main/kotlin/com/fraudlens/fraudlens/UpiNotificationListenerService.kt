package com.fraudlens.fraudlens

import android.content.Intent
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class UpiNotificationListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "FraudLensNotification"
        const val ACTION_UPI_NOTIFICATION = "com.fraudlens.fraudlens.UPI_NOTIFICATION"
        const val EXTRA_PACKAGE = "package_name"
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
        const val EXTRA_TIMESTAMP = "timestamp"

        val SUPPORTED_PACKAGES = setOf(
            "com.google.android.apps.nbu.paisa.user", // Google Pay
            "com.phonepe.app",                       // PhonePe
            "net.one97.paytm",                        // Paytm UPI
        )
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val pkg = sbn.packageName ?: return
        if (!SUPPORTED_PACKAGES.contains(pkg)) return

        val extras = sbn.notification.extras ?: return
        val title = extras.getCharSequence("android.title")?.toString() ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        val bigText = extras.getCharSequence("android.bigText")?.toString() ?: ""
        val combinedText = if (bigText.isNotEmpty()) "$text $bigText" else text

        Log.d(TAG, "Captured UPI notification from $pkg: Title='$title' | Text='$combinedText'")

        // Broadcast to MainActivity via local intent
        val intent = Intent(ACTION_UPI_NOTIFICATION).apply {
            putExtra(EXTRA_PACKAGE, pkg)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_TEXT, combinedText)
            putExtra(EXTRA_TIMESTAMP, sbn.postTime)
            setPackage(packageName)
        }
        sendBroadcast(intent)
    }
}
