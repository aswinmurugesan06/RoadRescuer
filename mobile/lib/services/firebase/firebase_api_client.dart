import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Base URL of the **Firebase** backend (Cloud Functions HTTPS endpoint).
///
/// The function is named `api`, so the public base URL ends in `/api` and the
/// client appends `/auth/...`, `/health`, etc. Deploy with
/// `cd firebase && firebase deploy --only functions` and copy the `api`
/// function URL here. The emulator URL (Android emulator) is
/// `http://10.0.2.2:5001/<projectId>/asia-south1/api`.
const String kFirebaseApiBaseUrl = String.fromEnvironment(
  'FIREBASE_API_BASE_URL',
  defaultValue: 'https://asia-south1-<project-id>.cloudfunctions.net/api',
);

/// Thrown when the Firebase backend returns a non-2xx response.
class FirebaseApiException implements Exception {
  final int statusCode;
  final String message;
  final List<String>? errors;

  const FirebaseApiException({
    required this.statusCode,
    required this.message,
    this.errors,
  });

  @override
  String toString() => 'FirebaseApiException($statusCode): $message'
      '${errors != null ? '\n${errors!.join('\n')}' : ''}';
}

/// HTTP client for the Firebase backend. It is API-compatible with the old
/// [ApiClient] but authenticates with a **Firebase ID token** instead of the
/// custom JWT, and can force a token refresh.
class FirebaseApiClient {
  FirebaseApiClient._();
  static final http.Client _client = http.Client();

  static Future<Map<String, String>> _headers({
    bool auth = true,
    bool forceRefresh = false,
  }) async {
    final headers = <String, String>{
      HttpHeaders.contentTypeHeader: 'application/json',
      HttpHeaders.acceptHeader: 'application/json',
    };
    if (auth) {
      final token = await getIdToken(forceRefresh: forceRefresh);
      if (token != null) {
        headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
      }
    }
    return headers;
  }

  /// Returns the current Firebase ID token (JWT), or null if signed out.
  static Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return user.getIdToken(forceRefresh);
  }

  static Map<String, dynamic> _parse(http.Response response) {
    final body = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    final errors = (body['errors'] as List<dynamic>?)?.cast<String>();
    final serverMessage = body['message'] as String? ?? 'Unknown error';
    final fullMessage = (errors != null && errors.isNotEmpty)
        ? '$serverMessage: ${errors.join(", ")}'
        : serverMessage;
    throw FirebaseApiException(
      statusCode: response.statusCode,
      message: fullMessage,
      errors: errors,
    );
  }

  static Future<Map<String, dynamic>> get(
    String path, {
    bool auth = true,
    bool forceRefresh = false,
  }) async {
    final response = await _client.get(
      Uri.parse('$kFirebaseApiBaseUrl$path'),
      headers: await _headers(auth: auth, forceRefresh: forceRefresh),
    );
    return _parse(response);
  }

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final response = await _client.post(
      Uri.parse('$kFirebaseApiBaseUrl$path'),
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
      Uri.parse('$kFirebaseApiBaseUrl$path'),
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
      Uri.parse('$kFirebaseApiBaseUrl$path'),
      headers: await _headers(auth: auth),
    );
    return _parse(response);
  }
}
