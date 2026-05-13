import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'token_service.dart';

/// Centralised HTTP client for the FLOW backend API.
///
/// • Automatically attaches the Bearer token.
/// • On 401 it attempts a silent token refresh and retries the request once.
/// • Parses the standard `{ success, data, error }` envelope.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  // ── Base URL ────────────────────────────────────────────────────────────────
  // Change this to your EC2 public IP for production.
  // Android emulator uses 10.0.2.2 to reach host localhost.
  static String get baseUrl {
    if (kIsWeb) return 'http://52.39.196.46:3000/api';
    if (Platform.isAndroid) return 'http://52.39.196.46:3000/api';
    return 'http://52.39.196.46:3000/api'; // iOS simulator / desktop
  }

  final TokenService _tokens = TokenService();

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Map<String, String> _headers({bool auth = true, bool json = true}) {
    final h = <String, String>{};
    if (json) h['Content-Type'] = 'application/json';
    if (auth && _tokens.accessToken != null) {
      h['Authorization'] = 'Bearer ${_tokens.accessToken}';
    }
    return h;
  }

  /// Attempts to refresh the access token using the stored refresh token.
  Future<bool> _refreshToken() async {
    final refresh = _tokens.refreshToken;
    if (refresh == null || refresh.isEmpty) return false;

    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refresh}),
      );
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        if (body['success'] == true) {
          final data = body['data'] as Map<String, dynamic>;
          await _tokens.saveTokens(
            accessToken: data['accessToken'],
            refreshToken: data['refreshToken'] ?? refresh,
          );
          return true;
        }
      }
    } catch (e) {
      debugPrint('[ApiClient] token refresh error: $e');
    }
    return false;
  }

  // ── Core request method ─────────────────────────────────────────────────────

  /// Sends an HTTP request and returns the parsed `data` field on success.
  ///
  /// Throws [ApiException] on failure.
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    bool auth = true,
    bool retry = true,
  }) async {
    var uri = Uri.parse('$baseUrl$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    http.Response resp;
    try {
      resp = await _send(method, uri, body: body, auth: auth);
    } catch (e) {
      throw ApiException(message: 'Network error: $e');
    }

    // ── 401 → try refresh once ──────────────────────────────────────────────
    if (resp.statusCode == 401 && auth && retry) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        resp = await _send(method, uri, body: body, auth: auth);
      } else {
        throw ApiException(message: 'Session expired. Please login again.');
      }
    }

    // ── Parse envelope ──────────────────────────────────────────────────────
    final parsed = _tryDecode(resp.body);
    if (parsed is Map<String, dynamic>) {
      if (parsed['success'] == true) {
        return parsed['data'];
      }
      // Error envelope
      final error = parsed['error'];
      String message = 'Request failed';
      String? code;
      if (error is Map<String, dynamic>) {
        message = error['message']?.toString() ?? message;
        code = error['code']?.toString();
      } else if (error is String) {
        message = error;
      }
      throw ApiException(
        message: message,
        statusCode: resp.statusCode,
        code: code,
      );
    }

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return parsed;
    }

    if (resp.statusCode == 403) {
      if (parsed is Map<String, dynamic> && parsed['error']?['code'] == 'ONBOARDING_REQUIRED') {
        throw ApiException(
          message: 'Please complete your business profile onboarding to access this feature.',
          statusCode: 403,
          code: 'ONBOARDING_REQUIRED',
        );
      }
    }

    throw ApiException(
      message: 'Server error (${resp.statusCode})',
      statusCode: resp.statusCode,
    );
  }

  Future<http.Response> _send(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final headers = _headers(auth: auth);
    final encodedBody = body != null ? jsonEncode(body) : null;

    switch (method.toUpperCase()) {
      case 'GET':
        return http.get(uri, headers: headers);
      case 'POST':
        return http.post(uri, headers: headers, body: encodedBody);
      case 'PATCH':
        return http.patch(uri, headers: headers, body: encodedBody);
      case 'PUT':
        return http.put(uri, headers: headers, body: encodedBody);
      case 'DELETE':
        return http.delete(uri, headers: headers, body: encodedBody);
      default:
        return http.get(uri, headers: headers);
    }
  }

  dynamic _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  // ── Convenience wrappers ────────────────────────────────────────────────────

  Future<dynamic> get(String path,
          {Map<String, String>? query, bool auth = true}) =>
      request('GET', path, queryParams: query, auth: auth);

  Future<dynamic> post(String path,
          {Map<String, dynamic>? body, bool auth = true}) =>
      request('POST', path, body: body, auth: auth);

  Future<dynamic> patch(String path,
          {Map<String, dynamic>? body, bool auth = true}) =>
      request('PATCH', path, body: body, auth: auth);

  Future<dynamic> put(String path,
          {Map<String, dynamic>? body, bool auth = true}) =>
      request('PUT', path, body: body, auth: auth);

  Future<dynamic> delete(String path,
          {Map<String, dynamic>? body, bool auth = true}) =>
      request('DELETE', path, body: body, auth: auth);

  // ── Multipart file upload ─────────────────────────────────────────────────

  /// Uploads a file via multipart/form-data.
  ///
  /// [filePath] — absolute path to the local file.
  /// [fieldName] — the form field name (default: 'file').
  /// [fields] — additional text fields to attach (e.g. type, loadId).
  ///
  /// Returns the parsed `data` payload from the server envelope.
  Future<dynamic> uploadFile(
    String path, {
    required String filePath,
    String fieldName = 'file',
    Map<String, String>? fields,
  }) async {
    final uri = Uri.parse('$baseUrl$path');

    final req = http.MultipartRequest('POST', uri);

    // Attach auth header
    if (_tokens.accessToken != null) {
      req.headers['Authorization'] = 'Bearer ${_tokens.accessToken}';
    }

    // Attach the file
    req.files.add(await http.MultipartFile.fromPath(fieldName, filePath));

    // Attach extra form fields
    if (fields != null) {
      req.fields.addAll(fields);
    }

    http.StreamedResponse streamed;
    try {
      streamed = await req.send();
    } catch (e) {
      throw ApiException(message: 'Upload network error: $e');
    }

    final respBody = await streamed.stream.bytesToString();
    final parsed = _tryDecode(respBody);

    // Handle 401 → retry once after refresh
    if (streamed.statusCode == 401) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        // Rebuild the request with the new token
        final retryReq = http.MultipartRequest('POST', uri);
        retryReq.headers['Authorization'] = 'Bearer ${_tokens.accessToken}';
        retryReq.files.add(
            await http.MultipartFile.fromPath(fieldName, filePath));
        if (fields != null) retryReq.fields.addAll(fields);

        final retryResp = await retryReq.send();
        final retryBody = await retryResp.stream.bytesToString();
        final retryParsed = _tryDecode(retryBody);

        if (retryParsed is Map<String, dynamic> &&
            retryParsed['success'] == true) {
          return retryParsed['data'];
        }
        throw ApiException(
          message: 'Upload failed after retry',
          statusCode: retryResp.statusCode,
        );
      }
      throw ApiException(message: 'Session expired. Please login again.');
    }

    // Parse envelope
    if (parsed is Map<String, dynamic>) {
      if (parsed['success'] == true) {
        return parsed['data'];
      }
      final error = parsed['error'];
      String message = 'Upload failed';
      if (error is Map<String, dynamic>) {
        message = error['message']?.toString() ?? message;
      }
      throw ApiException(message: message, statusCode: streamed.statusCode);
    }

    if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
      return parsed;
    }

    throw ApiException(
      message: 'Upload error (${streamed.statusCode})',
      statusCode: streamed.statusCode,
    );
  }
}

/// Exception thrown by [ApiClient] for non-2xx or envelope errors.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  ApiException({
    required this.message,
    this.statusCode,
    this.code,
  });

  @override
  String toString() => message;
}
