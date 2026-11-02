import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

/// Manages JWT token storage and authentications with SharedPreferences.
class AuthService {
  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'user_id';
  static const _userNameKey = 'user_name';
  static const _userRoleKey = 'user_role';
  static const _userEmailKey = 'user_email';
  static const _userMobileKey = 'user_mobile';

  /// Save auth token and user info after login/register.
  static Future<void> saveSession({
    required String token,
    required String userId,
    required String name,
    required String role,
    String? email,
    String? mobile,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_userNameKey, name);
    await prefs.setString(_userRoleKey, role);
    if (email != null) await prefs.setString(_userEmailKey, email);
    if (mobile != null) await prefs.setString(_userMobileKey, mobile);
  }

  /// Retrieve the stored JWT token.
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Retrieve the stored user ID.
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  /// Retrieve the stored user name.
  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }

  /// Retrieve the stored role.
  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userRoleKey);
  }

  /// Retrieve the stored email.
  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  /// Retrieve the stored mobile.
  static Future<String?> getUserMobile() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userMobileKey);
  }

  /// Whether the user is currently logged in.
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Log in with email or mobile identifier + password.
  /// If [expectedRole] is specified, verifies that authenticated user matches [expectedRole].
  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
    String? expectedRole,
  }) async {
    final body = <String, dynamic>{
      'identifier': identifier,
      'password': password,
    };
    if (expectedRole != null && expectedRole.isNotEmpty) {
      body['expectedRole'] = expectedRole.toUpperCase();
    }

    final res = await ApiClient.post(
      '/auth/login',
      body,
      auth: false,
    );

    final data = res['data'] as Map<String, dynamic>;
    final token = data['token'] as String;
    final user = data['user'] as Map<String, dynamic>;
    final actualRole = (user['role'] as String? ?? '').toUpperCase();

    // Secondary client-side guard against role mismatch
    if (expectedRole != null && expectedRole.isNotEmpty) {
      final normalizedExpected = expectedRole.toUpperCase();
      if (actualRole != normalizedExpected) {
        throw ApiException(
          statusCode: 403,
          message:
              'Access denied: This account is registered as ${_formatRoleLabel(actualRole)}. Please select ${_formatRoleLabel(actualRole)} on the role selection screen to sign in.',
        );
      }
    }

    await saveSession(
      token: token,
      userId: user['id'] as String,
      name: user['name'] as String,
      role: actualRole,
      email: user['email'] as String?,
      mobile: user['mobile'] as String?,
    );

    return data;
  }

  static String _formatRoleLabel(String role) {
    switch (role.toUpperCase()) {
      case 'PROVIDER':
        return 'Service Provider';
      case 'ADMIN':
        return 'Platform Admin';
      case 'CUSTOMER':
        return 'Vehicle User';
      default:
        return role;
    }
  }

  /// Register a new account.
  static Future<Map<String, dynamic>> register({
    required String name,
    required String mobile,
    required String email,
    required String password,
    String? confirmPassword,
    required String role,
    String? category,
    String? garageName,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'mobile': mobile,
      'email': email,
      'password': password,
      'confirmPassword': confirmPassword ?? password,
      'role': role.toUpperCase(),
    };
    if (category != null && category.isNotEmpty) {
      body['providerCategory'] = category.toUpperCase();
      body['category'] = category.toUpperCase();
    }
    if (garageName != null && garageName.isNotEmpty) {
      body['garageName'] = garageName;
    }

    final res = await ApiClient.post('/auth/register', body, auth: false);
    final data = res['data'] as Map<String, dynamic>;
    final token = data['token'] as String?;
    final user = data['user'] as Map<String, dynamic>?;

    if (token != null && user != null) {
      await saveSession(
        token: token,
        userId: user['id'] as String,
        name: user['name'] as String,
        role: (user['role'] as String).toUpperCase(),
        email: user['email'] as String?,
        mobile: user['mobile'] as String?,
      );
    }

    return data;
  }

  /// Send OTP.
  static Future<Map<String, dynamic>> sendOtp({required String mobile}) async {
    return await ApiClient.post('/auth/send-otp', {'mobile': mobile}, auth: false);
  }

  /// Verify OTP.
  static Future<Map<String, dynamic>> verifyOtp({
    required String mobile,
    required String otp,
  }) async {
    return await ApiClient.post('/auth/verify-otp', {'mobile': mobile, 'otp': otp}, auth: false);
  }

  /// Get currently authenticated profile.
  static Future<Map<String, dynamic>> getMe() async {
    final res = await ApiClient.get('/auth/me');
    return res['data'] as Map<String, dynamic>;
  }

  /// Clear all stored session data (logout).
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userRoleKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userMobileKey);
  }
}
