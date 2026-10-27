import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? details;

  ApiException({required this.statusCode, required this.message, this.details});

  @override
  String toString() => message;
}

class ApiClient {
  static final ApiClient instance = ApiClient._internal();
  ApiClient._internal();

  static const Duration defaultTimeout = Duration(seconds: 15);

  String? _token;
  VoidCallback? onUnauthorized;

  void setToken(String? token) {
    _token = token;
  }

  String? get token => _token;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  Map<String, String> _buildHeaders({bool isJson = true}) {
    final headers = <String, String>{'Accept': 'application/json'};
    if (isJson) {
      headers['Content-Type'] = 'application/json';
    }
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Token $_token';
    }
    return headers;
  }

  Future<dynamic> get(String url, {Map<String, dynamic>? queryParams}) async {
    Uri uri = Uri.parse(url);
    if (queryParams != null && queryParams.isNotEmpty) {
      final sanitizedParams = <String, String>{};
      queryParams.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty) {
          sanitizedParams[key] = value.toString();
        }
      });
      uri = uri.replace(
        queryParameters: {...uri.queryParameters, ...sanitizedParams},
      );
    }

    try {
      final response = await http
          .get(uri, headers: _buildHeaders())
          .timeout(defaultTimeout);
      return _handleResponse(response);
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint(
          '[ApiClient] Request timeout (${defaultTimeout.inSeconds}s) GET $url',
        );
      }
      throw ApiException(
        statusCode: 408,
        message:
            'Request timed out after ${defaultTimeout.inSeconds}s. Please check if the server is running at ${uri.host}:${uri.port}.',
      );
    } on SocketException catch (e) {
      if (kDebugMode) {
        debugPrint('[ApiClient] SocketException GET $url: ${e.message}');
      }
      throw ApiException(
        statusCode: 0,
        message:
            'Cannot reach server at ${uri.host}:${uri.port}. Please check your connection or server URL. (${e.message})',
      );
    } on http.ClientException catch (e) {
      if (kDebugMode) {
        debugPrint('[ApiClient] ClientException GET $url: ${e.message}');
      }
      throw ApiException(
        statusCode: 0,
        message: 'Network client error: ${e.message}',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      if (kDebugMode) {
        debugPrint('[ApiClient] Unexpected error GET $url: $e');
      }
      throw ApiException(statusCode: 0, message: 'Network error: $e');
    }
  }

  Future<dynamic> post(String url, {dynamic body}) async {
    final uri = Uri.parse(url);
    try {
      final response = await http
          .post(
            uri,
            headers: _buildHeaders(isJson: true),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(defaultTimeout);
      return _handleResponse(response);
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint(
          '[ApiClient] Request timeout (${defaultTimeout.inSeconds}s) POST $url',
        );
      }
      throw ApiException(
        statusCode: 408,
        message:
            'Request timed out after ${defaultTimeout.inSeconds}s. Please check if the server is running at ${uri.host}:${uri.port}.',
      );
    } on SocketException catch (e) {
      if (kDebugMode) {
        debugPrint('[ApiClient] SocketException POST $url: ${e.message}');
      }
      throw ApiException(
        statusCode: 0,
        message:
            'Cannot reach server at ${uri.host}:${uri.port}. Please check your connection or server URL. (${e.message})',
      );
    } on http.ClientException catch (e) {
      if (kDebugMode) {
        debugPrint('[ApiClient] ClientException POST $url: ${e.message}');
      }
      throw ApiException(
        statusCode: 0,
        message: 'Network client error: ${e.message}',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      if (kDebugMode) {
        debugPrint('[ApiClient] Unexpected error POST $url: $e');
      }
      throw ApiException(statusCode: 0, message: 'Network error: $e');
    }
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode == 401) {
      onUnauthorized?.call();
      throw ApiException(
        statusCode: 401,
        message: 'Authentication session expired or invalid credentials.',
      );
    }

    dynamic decodedBody;
    if (response.body.isNotEmpty) {
      try {
        decodedBody = jsonDecode(response.body);
      } catch (_) {
        decodedBody = response.body;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decodedBody;
    }

    // Parse DRF errors
    String errorMessage = 'Request failed (${response.statusCode})';
    Map<String, dynamic>? detailsMap;

    if (decodedBody is Map<String, dynamic>) {
      detailsMap = decodedBody;
      if (decodedBody.containsKey('detail')) {
        errorMessage = decodedBody['detail'].toString();
      } else if (decodedBody.containsKey('non_field_errors')) {
        final list = decodedBody['non_field_errors'];
        errorMessage = (list is List) ? list.join(' ') : list.toString();
      } else {
        // Concatenate field errors
        final fieldErrors = <String>[];
        decodedBody.forEach((k, v) {
          if (v is List) {
            fieldErrors.add('$k: ${v.join(", ")}');
          } else {
            fieldErrors.add('$k: $v');
          }
        });
        if (fieldErrors.isNotEmpty) {
          errorMessage = fieldErrors.join('\n');
        }
      }
    } else if (decodedBody is String && decodedBody.isNotEmpty) {
      final trimmed = decodedBody.trimLeft();
      if (trimmed.startsWith('<')) {
        // Raw HTML returned by server (e.g. 500 error or 400 DisallowedHost)
        errorMessage =
            'Server error (${response.statusCode}). Please check backend status.';
      } else {
        errorMessage = decodedBody;
      }
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: errorMessage,
      details: detailsMap,
    );
  }
}
