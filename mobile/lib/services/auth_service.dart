import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/user.dart';
import 'api_client.dart';
import 'secure_storage_service.dart';

class AuthService {
  static const String _kPrefAuthToken = 'fraudlens_auth_token';
  static const String _kPrefUserCache = 'fraudlens_user_cache';

  final ApiClient _client = ApiClient.instance;
  final SecureStorageService _secureStorage = SecureStorageService.instance;

  Future<String?> getStoredToken() async {
    final secureToken = await _secureStorage.read(_kPrefAuthToken);
    if (secureToken != null && secureToken.isNotEmpty) {
      return secureToken;
    }

    // One-time migration from legacy plaintext SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(_kPrefAuthToken);
    if (legacyToken != null && legacyToken.isNotEmpty) {
      await _secureStorage.write(_kPrefAuthToken, legacyToken);
      await prefs.remove(_kPrefAuthToken);
      return legacyToken;
    }
    return null;
  }

  Future<UserMe?> getStoredUser() async {
    var jsonStr = await _secureStorage.read(_kPrefUserCache);
    if (jsonStr == null || jsonStr.isEmpty) {
      // One-time migration from legacy plaintext SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final legacyUser = prefs.getString(_kPrefUserCache);
      if (legacyUser != null && legacyUser.isNotEmpty) {
        await _secureStorage.write(_kPrefUserCache, legacyUser);
        await prefs.remove(_kPrefUserCache);
        jsonStr = legacyUser;
      }
    }

    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return UserMe.fromJson(map);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> saveToken(String token) async {
    await _secureStorage.write(_kPrefAuthToken, token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefAuthToken);
    _client.setToken(token);
  }

  Future<void> saveUser(UserMe user) async {
    await _secureStorage.write(_kPrefUserCache, jsonEncode(user.toJson()));
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefUserCache);
  }

  Future<void> clearSession() async {
    await _secureStorage.delete(_kPrefAuthToken);
    await _secureStorage.delete(_kPrefUserCache);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefAuthToken);
    await prefs.remove(_kPrefUserCache);
    _client.setToken(null);
  }

  Future<Map<String, dynamic>> checkHealth() async {
    final result = await _client.get(ApiConfig.healthUrl);
    return result as Map<String, dynamic>;
  }

  Future<AuthResponse> login({
    required String username,
    required String password,
  }) async {
    final body = {'username': username.trim(), 'password': password};
    final response = await _client.post(ApiConfig.loginUrl, body: body);
    final authResp = AuthResponse.fromJson(response as Map<String, dynamic>);
    await saveToken(authResp.token);
    return authResp;
  }

  Future<AuthResponse> register({
    required String username,
    required String password,
    String? email,
  }) async {
    final body = <String, dynamic>{
      'username': username.trim(),
      'password': password,
    };
    if (email != null && email.trim().isNotEmpty) {
      body['email'] = email.trim();
    }
    final response = await _client.post(ApiConfig.registerUrl, body: body);
    final authResp = AuthResponse.fromJson(response as Map<String, dynamic>);
    await saveToken(authResp.token);
    return authResp;
  }

  Future<Map<String, dynamic>> linkBankAccount({
    required String bankName,
    required String accountNumber,
    double? homeLat,
    double? homeLong,
  }) async {
    final body = <String, dynamic>{
      'bank_name': bankName.trim(),
      'account_number': accountNumber.trim(),
    };
    if (homeLat != null) body['home_lat'] = homeLat;
    if (homeLong != null) body['home_long'] = homeLong;

    final response = await _client.post(ApiConfig.linkBankUrl, body: body);
    return response as Map<String, dynamic>;
  }

  Future<UserMe> getMe() async {
    final response = await _client.get(ApiConfig.meUrl);
    final user = UserMe.fromJson(response as Map<String, dynamic>);
    await saveUser(user);
    return user;
  }

  Future<String?> uploadAvatar(String filePath) async {
    final response = await _client.postMultipart(
      ApiConfig.avatarUrl,
      fileField: 'avatar',
      filePath: filePath,
    );
    final map = response as Map<String, dynamic>;
    final avatarUrl = map['avatar_url'] as String?;
    await getMe();
    return avatarUrl;
  }

  Future<void> deleteAvatar() async {
    await _client.delete(ApiConfig.avatarUrl);
    await getMe();
  }

  Future<void> logout() async {
    try {
      if (_client.isAuthenticated) {
        await _client.post(ApiConfig.logoutUrl);
      }
    } catch (_) {
      // Even if network fails, always clear local token
    } finally {
      await clearSession();
    }
  }
}
