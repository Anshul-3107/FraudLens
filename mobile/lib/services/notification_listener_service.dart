import 'dart:async';
import 'package:flutter/services.dart';
import 'upi_parser.dart';

class NotificationListenerService {
  static const MethodChannel _channel = MethodChannel(
    'com.fraudlens.fraudlens/notification_listener',
  );

  final StreamController<ParsedUpiNotification> _notificationController =
      StreamController<ParsedUpiNotification>.broadcast();

  Stream<ParsedUpiNotification> get onUpiPaymentCaptured =>
      _notificationController.stream;

  static final NotificationListenerService instance =
      NotificationListenerService._internal();

  NotificationListenerService._internal() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onNotificationReceived') {
      final data = Map<String, dynamic>.from(call.arguments as Map);
      final pkg = data['package_name'] as String? ?? '';
      final title = data['title'] as String? ?? '';
      final text = data['text'] as String? ?? '';
      final source = data['source'] as String? ?? 'notification';

      final parsed = UpiParser.parse(
        packageName: pkg,
        title: title,
        text: text,
        source: source,
      );

      if (parsed != null) {
        _notificationController.add(parsed);
      }
    }
  }

  /// Check if the user has enabled Notification Access in Android Settings
  Future<bool> isPermissionGranted() async {
    try {
      final granted =
          await _channel.invokeMethod<bool>('isNotificationListenerEnabled');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Open Android Notification Access settings screen for the user
  Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } catch (_) {}
  }

  /// Check if SMS Receive permission is granted
  Future<bool> isSmsPermissionGranted() async {
    try {
      final granted =
          await _channel.invokeMethod<bool>('isSmsPermissionGranted');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Request SMS permission dialog
  Future<void> requestSmsPermission() async {
    try {
      await _channel.invokeMethod('requestSmsPermission');
    } catch (_) {}
  }

  void dispose() {
    _notificationController.close();
  }
}
