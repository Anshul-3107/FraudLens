import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/user.dart';
import 'api_client.dart';

class AuthService {
  static const String _kPrefAuthToken = 'fraudlens_auth_token';
  static const String _kPrefUserCache = 'fraudlens_user_cache';

  final ApiClient _client = ApiClient.instance;

  Future<String?> getStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPrefAuthToken);
  }

  Future<UserMe?> getStoredUser() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kPrefUserCache);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefAuthToken, token);
    _client.setToken(token);
  }

  Future<void> saveUser(UserMe user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefUserCache, jsonEncode(user.toJson()));
  }

  Future<void> clearSession() async {
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

  Future<UserMe> getMe() async {
    final response = await _client.get(ApiConfig.meUrl);
    final user = UserMe.fromJson(response as Map<String, dynamic>);
    await saveUser(user);
    return user;
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
