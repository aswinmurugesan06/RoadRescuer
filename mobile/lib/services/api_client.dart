import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Base URL of the RoadRescue backend.
///
/// Override it for a physical device or a deployed API:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000/api
///
/// Defaults to `localhost` on web and `10.0.2.2` on the Android emulator.
const String _kConfiguredBaseUrl = String.fromEnvironment('API_BASE_URL');
final String _kBaseUrl = _kConfiguredBaseUrl.isNotEmpty
    ? _kConfiguredBaseUrl
    : (kIsWeb
        ? 'http://localhost:3000/api'
        : 'http://10.0.2.2:3000/api');

/// Thrown when the server returns a non-2xx response.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final List<String>? errors;

  const ApiException({
    required this.statusCode,
    required this.message,
    this.errors,
  });

  @override
  String toString() =>
      'ApiException($statusCode): $message${errors != null ? '\n${errors!.join('\n')}' : ''}';
}

/// Low-level HTTP client that injects the auth token and handles errors.
class ApiClient {
  static final _client = http.Client();

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{
      HttpHeaders.contentTypeHeader: 'application/json',
      HttpHeaders.acceptHeader: 'application/json',
    };
    if (auth) {
      final token = await AuthService.getToken();
      if (token != null) {
        headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
      }
    }
    return headers;
  }

  static Map<String, dynamic> _parse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    final errors = (body['errors'] as List<dynamic>?)?.cast<String>();
    final serverMessage = body['message'] as String? ?? 'Unknown error';
    final fullMessage = (errors != null && errors.isNotEmpty)
        ? '$serverMessage: ${errors.join(", ")}'
        : serverMessage;
    throw ApiException(
      statusCode: response.statusCode,
      message: fullMessage,
      errors: errors,
    );
  }

  static Future<Map<String, dynamic>> get(
    String path, {
    bool auth = true,
  }) async {
    final response = await _client.get(
      Uri.parse('$_kBaseUrl$path'),
      headers: await _headers(auth: auth),
    );
    return _parse(response);
  }

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final response = await _client.post(
      Uri.parse('$_kBaseUrl$path'),
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    );
    return _parse(response);
  }

  static Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final response = await _client.put(
      Uri.parse('$_kBaseUrl$path'),
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    );
    return _parse(response);
  }

  static Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final response = await _client.patch(
      Uri.parse('$_kBaseUrl$path'),
      headers: await _headers(auth: auth),
      body: body != null ? jsonEncode(body) : null,
    );
    return _parse(response);
  }

  static Future<Map<String, dynamic>> delete(
    String path, {
    bool auth = true,
  }) async {
    final response = await _client.delete(
      Uri.parse('$_kBaseUrl$path'),
      headers: await _headers(auth: auth),
    );
    return _parse(response);
  }
}
