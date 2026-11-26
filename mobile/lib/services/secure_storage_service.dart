import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Encrypted key-value storage using Android Keystore AES/GCM via MethodChannel.
/// Falls back to volatile in-memory storage when running in unit tests or on
/// platforms without a native secure keystore bridge.
class SecureStorageService {
  SecureStorageService._();

  static final SecureStorageService instance = SecureStorageService._();
  static const MethodChannel _channel = MethodChannel(
    'com.fraudlens.fraudlens/secure_storage',
  );

  final Map<String, String> _memoryFallback = <String, String>{};

  bool get _supportsNativeKeystore =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> write(String key, String value) async {
    _memoryFallback[key] = value;
    if (!_supportsNativeKeystore) return;
    try {
      await _channel.invokeMethod<bool>('write', {'key': key, 'value': value});
    } on MissingPluginException {
      // Expected inside Flutter unit tests without a running Android host.
    }
  }

  Future<String?> read(String key) async {
    if (_supportsNativeKeystore) {
      try {
        final nativeValue = await _channel.invokeMethod<String>('read', {
          'key': key,
        });
        if (nativeValue != null) {
          _memoryFallback[key] = nativeValue;
          return nativeValue;
        }
      } on MissingPluginException {
        return _memoryFallback[key];
      }
      return null;
    }
    return _memoryFallback[key];
  }

  Future<void> delete(String key) async {
    _memoryFallback.remove(key);
    if (!_supportsNativeKeystore) return;
    try {
      await _channel.invokeMethod<bool>('delete', {'key': key});
    } on MissingPluginException {
      // Expected inside Flutter unit tests without a running Android host.
    }
  }
}
