package com.fraudlens.fraudlens

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.fraudlens.fraudlens/notification_listener"
    private var notificationReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isNotificationListenerEnabled" -> {
                    result.success(isNotificationServiceEnabled())
                }
                "openNotificationSettings" -> {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Register broadcast receiver to relay captured notifications to Flutter
        notificationReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == UpiNotificationListenerService.ACTION_UPI_NOTIFICATION) {
                    val payload = mapOf(
                        "package_name" to (intent.getStringExtra(UpiNotificationListenerService.EXTRA_PACKAGE) ?: ""),
                        "title" to (intent.getStringExtra(UpiNotificationListenerService.EXTRA_TITLE) ?: ""),
                        "text" to (intent.getStringExtra(UpiNotificationListenerService.EXTRA_TEXT) ?: ""),
                        "timestamp" to intent.getLongExtra(UpiNotificationListenerService.EXTRA_TIMESTAMP, System.currentTimeMillis())
                    )
                    channel.invokeMethod("onNotificationReceived", payload)
                }
            }
        }

        val filter = IntentFilter(UpiNotificationListenerService.ACTION_UPI_NOTIFICATION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(notificationReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(notificationReceiver, filter)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        notificationReceiver?.let {
            unregisterReceiver(it)
            notificationReceiver = null
        }
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        return flat != null && flat.contains(packageName)
    }
}
