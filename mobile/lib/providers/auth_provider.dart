import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthStatus _status = AuthStatus.initial;
  bool _isInitializing = true;
  bool _isLoading = false;
  UserMe? _user;
  String? _token;
  String? _errorMessage;

  AuthProvider({AuthService? authService})
    : _authService = authService ?? AuthService() {
    ApiClient.instance.onUnauthorized = _handleUnauthorized;
  }

  AuthStatus get status => _status;
  bool get isInitializing => _isInitializing;
  UserMe? get user => _user;
  String? get token => _token;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated =>
      _status == AuthStatus.authenticated && _token != null;
  bool get isLoading => _isLoading;

  void _handleUnauthorized() {
    _status = AuthStatus.unauthenticated;
    _token = null;
    _user = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> initialize() async {
    _isInitializing = true;
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final savedToken = await _authService.getStoredToken();
      if (savedToken != null && savedToken.isNotEmpty) {
        _token = savedToken;
        ApiClient.instance.setToken(savedToken);

        // Try getting cached user first for instant UI response
        _user = await _authService.getStoredUser();

        // Validate token by fetching fresh profile
        try {
          final freshUser = await _authService.getMe();
          _user = freshUser;
          _status = AuthStatus.authenticated;
        } catch (e) {
          if (e is ApiException && e.statusCode == 401) {
            await _authService.clearSession();
            _token = null;
            _user = null;
            _status = AuthStatus.unauthenticated;
          } else {
            // Offline or server temporarily unreachable; keep authenticated if cached user exists
            if (_user != null) {
              _status = AuthStatus.authenticated;
            } else {
              _status = AuthStatus.unauthenticated;
            }
          }
        }
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (_) {
      _status = AuthStatus.unauthenticated;
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final authResp = await _authService.login(
        username: username,
        password: password,
      );
      _token = authResp.token;
      ApiClient.instance.setToken(_token);

      final me = await _authService.getMe();
      _user = me;
      _status = AuthStatus.authenticated;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(
    String username,
    String password, {
    String? email,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final authResp = await _authService.register(
        username: username,
        password: password,
        email: email,
      );
      _token = authResp.token;
      ApiClient.instance.setToken(_token);

      final me = await _authService.getMe();
      _user = me;
      _status = AuthStatus.authenticated;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshProfile() async {
    try {
      final me = await _authService.getMe();
      _user = me;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await _authService.logout();
    _token = null;
    _user = null;
    _status = AuthStatus.unauthenticated;
    _isLoading = false;
    notifyListeners();
  }
}
