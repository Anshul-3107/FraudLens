import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String _kPrefBaseUrlKey = 'fraudlens_api_base_url';

  // Build-time override via --dart-define=API_BASE_URL=https://...
  static const String _dartDefineBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  static String get defaultBaseUrl {
    if (_dartDefineBaseUrl.isNotEmpty) {
      return _dartDefineBaseUrl;
    }
    // Android emulator loopback vs standard host localhost
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  static String _activeBaseUrl = '';

  static String get baseUrl {
    if (_activeBaseUrl.isNotEmpty) {
      return _activeBaseUrl;
    }
    return defaultBaseUrl;
  }

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kPrefBaseUrlKey);
    if (saved != null && saved.trim().isNotEmpty) {
      _activeBaseUrl = saved.trim();
    } else {
      _activeBaseUrl = defaultBaseUrl;
    }
  }

  static Future<void> setBaseUrl(String newUrl) async {
    var sanitized = newUrl.trim();
    while (sanitized.endsWith('/')) {
      sanitized = sanitized.substring(0, sanitized.length - 1);
    }
    _activeBaseUrl = sanitized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefBaseUrlKey, sanitized);
  }

  static Future<void> resetToDefault() async {
    _activeBaseUrl = defaultBaseUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefBaseUrlKey);
  }

  // Endpoints
  static String get healthUrl => '$baseUrl/api/health/';
  static String get registerUrl => '$baseUrl/api/auth/register/';
  static String get loginUrl => '$baseUrl/api/auth/login/';
  static String get logoutUrl => '$baseUrl/api/auth/logout/';
  static String get meUrl => '$baseUrl/api/auth/me/';
  static String get summaryUrl => '$baseUrl/api/summary/';
  static String get cardsUrl => '$baseUrl/api/cards/';
  static String get transactionsUrl => '$baseUrl/api/transactions/';
  static String get alertsUrl => '$baseUrl/api/alerts/';
  static String get investigationsUrl => '$baseUrl/api/investigations/';

  static String alertInvestigateUrl(int alertId) =>
      '$baseUrl/api/alerts/$alertId/investigate/';
  static String transactionDetailUrl(int transactionId) =>
      '$baseUrl/api/transactions/$transactionId/';
  static String alertDetailUrl(int alertId) => '$baseUrl/api/alerts/$alertId/';
}
