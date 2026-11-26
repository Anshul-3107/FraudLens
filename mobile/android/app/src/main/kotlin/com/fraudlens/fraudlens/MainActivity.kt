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

import android.location.Geocoder
import android.location.Location
import android.location.LocationManager
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import java.util.Locale
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.fraudlens.fraudlens/notification_listener"
    private val SECURE_STORAGE_CHANNEL = "com.fraudlens.fraudlens/secure_storage"
    private val SECURE_PREFS_NAME = "fraudlens_secure_prefs"
    private val KEYSTORE_ALIAS = "fraudlens_token_key_v1"
    private val SMS_PERMISSION_REQUEST_CODE = 101
    private val LOCATION_PERMISSION_REQUEST_CODE = 102
    private var notificationReceiver: BroadcastReceiver? = null
    private var smsBroadcastReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val secureChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURE_STORAGE_CHANNEL)
        secureChannel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "write" -> {
                        val key = call.argument<String>("key")
                        val value = call.argument<String>("value")
                        if (key.isNullOrEmpty() || value == null) {
                            result.error("INVALID_ARGS", "Key and value are required", null)
                        } else {
                            writeSecureValue(key, value)
                            result.success(true)
                        }
                    }
                    "read" -> {
                        val key = call.argument<String>("key")
                        if (key.isNullOrEmpty()) {
                            result.error("INVALID_ARGS", "Key is required", null)
                        } else {
                            result.success(readSecureValue(key))
                        }
                    }
                    "delete" -> {
                        val key = call.argument<String>("key")
                        if (key.isNullOrEmpty()) {
                            result.error("INVALID_ARGS", "Key is required", null)
                        } else {
                            getSharedPreferences(SECURE_PREFS_NAME, Context.MODE_PRIVATE)
                                .edit().remove(key).apply()
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("SECURE_STORAGE_ERROR", e.message ?: "Encryption failure", null)
            }
        }

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
                "isLocationPermissionGranted" -> {
                    val hasFine = ContextCompat.checkSelfPermission(
                        this, Manifest.permission.ACCESS_FINE_LOCATION
                    ) == PackageManager.PERMISSION_GRANTED
                    val hasCoarse = ContextCompat.checkSelfPermission(
                        this, Manifest.permission.ACCESS_COARSE_LOCATION
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(hasFine || hasCoarse)
                }
                "requestLocationPermission" -> {
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(
                            Manifest.permission.ACCESS_FINE_LOCATION,
                            Manifest.permission.ACCESS_COARSE_LOCATION
                        ),
                        LOCATION_PERMISSION_REQUEST_CODE
                    )
                    result.success(true)
                }
                "getCurrentLocation" -> {
                    result.success(getLocationDetails())
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

    private fun getBestLocation(): Location? {
        val locationManager = getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return null
        val hasFine = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val hasCoarse = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (!hasFine && !hasCoarse) return null

        var bestLocation: Location? = null
        val providers = locationManager.getProviders(true)
        for (provider in providers) {
            val l = try {
                locationManager.getLastKnownLocation(provider)
            } catch (e: SecurityException) {
                null
            }
            if (l != null) {
                if (bestLocation == null || l.accuracy < bestLocation.accuracy) {
                    bestLocation = l
                }
            }
        }
        return bestLocation
    }

    private fun getLocationDetails(): Map<String, Any?> {
        val loc = getBestLocation() ?: return emptyMap()
        var city = ""
        var addressLine = ""
        try {
            val geocoder = Geocoder(this, Locale.getDefault())
            @Suppress("DEPRECATION")
            val addresses = geocoder.getFromLocation(loc.latitude, loc.longitude, 1)
            if (!addresses.isNullOrEmpty()) {
                val addr = addresses[0]
                city = addr.locality ?: addr.subAdminArea ?: addr.adminArea ?: ""
                addressLine = addr.getAddressLine(0) ?: ""
            }
        } catch (e: Exception) {
            // Geocoder service may be offline or unavailable
        }
        return mapOf(
            "latitude" to loc.latitude,
            "longitude" to loc.longitude,
            "city" to city,
            "address" to addressLine
        )
    }

    @Synchronized
    private fun getOrCreateAesKey(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val existing = keyStore.getEntry(KEYSTORE_ALIAS, null) as? KeyStore.SecretKeyEntry
        if (existing != null) {
            return existing.secretKey
        }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        val spec = KeyGenParameterSpec.Builder(
            KEYSTORE_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .build()
        generator.init(spec)
        return generator.generateKey()
    }

    private fun writeSecureValue(key: String, plainText: String) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateAesKey())
        val iv = cipher.iv
        val cipherBytes = cipher.doFinal(plainText.toByteArray(Charsets.UTF_8))
        val combined = ByteArray(iv.size + cipherBytes.size)
        System.arraycopy(iv, 0, combined, 0, iv.size)
        System.arraycopy(cipherBytes, 0, combined, iv.size, cipherBytes.size)
        val encoded = Base64.encodeToString(combined, Base64.NO_WRAP)
        getSharedPreferences(SECURE_PREFS_NAME, Context.MODE_PRIVATE)
            .edit().putString(key, encoded).apply()
    }

    private fun readSecureValue(key: String): String? {
        val prefs = getSharedPreferences(SECURE_PREFS_NAME, Context.MODE_PRIVATE)
        val encoded = prefs.getString(key, null) ?: return null
        return try {
            val combined = Base64.decode(encoded, Base64.NO_WRAP)
            if (combined.size <= 12) return null
            val iv = combined.copyOfRange(0, 12)
            val cipherBytes = combined.copyOfRange(12, combined.size)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, getOrCreateAesKey(), GCMParameterSpec(128, iv))
            String(cipher.doFinal(cipherBytes), Charsets.UTF_8)
        } catch (_: Exception) {
            prefs.edit().remove(key).apply()
            null
        }
    }
}
