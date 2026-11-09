package com.fraudlens.fraudlens

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.fraudlens.fraudlens/notification_listener"
    private val SMS_PERMISSION_REQUEST_CODE = 101
    private var notificationReceiver: BroadcastReceiver? = null
    private var smsBroadcastReceiver: BroadcastReceiver? = null

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
                "isSmsPermissionGranted" -> {
                    val hasReceive = ContextCompat.checkSelfPermission(
                        this, Manifest.permission.RECEIVE_SMS
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(hasReceive)
                }
                "requestSmsPermission" -> {
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(Manifest.permission.RECEIVE_SMS, Manifest.permission.READ_SMS),
                        SMS_PERMISSION_REQUEST_CODE
                    )
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // 1. Relay app notifications (GPay / PhonePe) to Flutter
        notificationReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == UpiNotificationListenerService.ACTION_UPI_NOTIFICATION) {
                    val payload = mapOf(
                        "package_name" to (intent.getStringExtra(UpiNotificationListenerService.EXTRA_PACKAGE) ?: ""),
                        "title" to (intent.getStringExtra(UpiNotificationListenerService.EXTRA_TITLE) ?: ""),
                        "text" to (intent.getStringExtra(UpiNotificationListenerService.EXTRA_TEXT) ?: ""),
                        "timestamp" to intent.getLongExtra(UpiNotificationListenerService.EXTRA_TIMESTAMP, System.currentTimeMillis()),
                        "source" to "notification"
                    )
                    channel.invokeMethod("onNotificationReceived", payload)
                }
            }
        }
        val notifFilter = IntentFilter(UpiNotificationListenerService.ACTION_UPI_NOTIFICATION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(notificationReceiver, notifFilter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(notificationReceiver, notifFilter)
        }

        // 2. Relay Bank SMS to Flutter
        smsBroadcastReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == BankSmsReceiver.ACTION_BANK_SMS) {
                    val payload = mapOf(
                        "package_name" to "android.telephony.sms",
                        "title" to (intent.getStringExtra(BankSmsReceiver.EXTRA_SENDER) ?: "Bank SMS"),
                        "text" to (intent.getStringExtra(BankSmsReceiver.EXTRA_BODY) ?: ""),
                        "timestamp" to intent.getLongExtra(BankSmsReceiver.EXTRA_TIMESTAMP, System.currentTimeMillis()),
                        "source" to "sms"
                    )
                    channel.invokeMethod("onNotificationReceived", payload)
                }
            }
        }
        val smsFilter = IntentFilter(BankSmsReceiver.ACTION_BANK_SMS)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(smsBroadcastReceiver, smsFilter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(smsBroadcastReceiver, smsFilter)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        notificationReceiver?.let {
            unregisterReceiver(it)
            notificationReceiver = null
        }
        smsBroadcastReceiver?.let {
            unregisterReceiver(it)
            smsBroadcastReceiver = null
        }
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        return flat != null && flat.contains(packageName)
    }
}
