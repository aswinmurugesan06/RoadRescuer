import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'firebase/firestore_helpers.dart';
import 'firebase/firestore_profile_service.dart';

/// Firebase Auth + Firestore backed session/profile service.
///
/// This replaces the old Express/Postgres authentication flow. All user
/// credentials live in Firebase Authentication and the RoadRescue profile is
/// stored at `users/{uid}` in Cloud Firestore.
class AuthService {
  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'user_id';
  static const _userNameKey = 'user_name';
  static const _userRoleKey = 'user_role';
  static const _userEmailKey = 'user_email';
  static const _userMobileKey = 'user_mobile';

  static Map<String, dynamic>? _cachedProfile;
  static String? _cachedUid;
  static String? _pendingVerificationId;

  static FirebaseAuth get _auth => FirebaseAuth.instance;
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Firebase must be initialized before any Auth/Firestore call.
  static bool get _firebaseReady => Firebase.apps.isNotEmpty;

  static void _ensureFirebase() {
    if (!_firebaseReady) {
      throw const ApiException(
        statusCode: 503,
        message:
            'Firebase is not initialized. Restart the app after the Firebase configuration has loaded.',
      );
    }
  }

  /// Persists a local cache of the session for screens that read it directly.
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

  static Future<void> _cacheSession(Map<String, dynamic> profile) async {
    _cachedProfile = profile;
    _cachedUid = profile['uid'] as String?;
    final token = await _auth.currentUser?.getIdToken();
    await saveSession(
      token: token ?? '',
      userId: (profile['uid'] as String?) ?? '',
      name: (profile['name'] as String?) ?? 'RoadRescue User',
      role: ((profile['role'] as String?) ?? 'CUSTOMER').toUpperCase(),
      email: profile['email'] as String?,
      mobile: profile['mobile'] as String?,
    );
  }

  /// Returns a fresh Firebase ID token, or the cached token when signed out.
  static Future<String?> getToken() async {
    if (_firebaseReady) {
      final user = _auth.currentUser;
      if (user != null) return user.getIdToken();
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<String?> getUserId() async {
    if (_firebaseReady) {
      final user = _auth.currentUser;
      if (user != null) return user.uid;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  static Future<String?> _profileField(String field, String prefsKey) async {
    if (_firebaseReady) {
      final user = _auth.currentUser;
      if (user != null) {
        try {
          final profile = await _syncProfile(user);
          final value = profile[field];
          if (value is String && value.isNotEmpty) return value;
        } catch (_) {
          // Fall back to the local cache below.
        }
      }
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(prefsKey);
  }

  static Future<String?> getUserName() => _profileField('name', _userNameKey);

  static Future<String?> getUserRole() async {
    final role = await _profileField('role', _userRoleKey);
    return role?.toUpperCase();
  }

  static Future<String?> getUserEmail() =>
      _profileField('email', _userEmailKey);

  static Future<String?> getUserMobile() =>
      _profileField('mobile', _userMobileKey);

  /// Whether a Firebase session is active.
  static Future<bool> isLoggedIn() async {
    if (!_firebaseReady) return false;
    return _auth.currentUser != null;
  }

  // ── Email / password ──────────────────────────────────────────────────

  /// Signs in with the email address stored in Firebase Authentication.
  ///
  /// A mobile number is accepted as a convenience: the matching profile is
  /// looked up in Firestore to resolve its email, then Firebase signs in with
  /// that email and the supplied password.
  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
    String? role,
  }) async {
    _ensureFirebase();
    final trimmed = identifier.trim();
    if (trimmed.isEmpty || password.isEmpty) {
      throw const ApiException(
        statusCode: 400,
        message: 'Email and password are required.',
      );
    }

    try {
      var email = trimmed;
      if (!trimmed.contains('@')) {
        final mobile = normalizeMobile(trimmed);
        final query = await _db
            .collection('users')
            .where('mobile', isEqualTo: mobile)
            .limit(1)
            .get();
        if (query.docs.isEmpty) {
          throw const ApiException(
            statusCode: 401,
            message:
                'No account found for this mobile number. Sign in with your email or use phone OTP.',
          );
        }
        final resolved = query.docs.first.data()['email'] as String?;
        if (resolved == null || resolved.isEmpty) {
          throw const ApiException(
            statusCode: 401,
            message: 'This account has no email address. Use phone OTP.',
          );
        }
        email = resolved;
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: email.toLowerCase(),
        password: password,
      );
      final profile = await _syncProfile(
        credential.user!,
        fallbackRole: role,
      );
      await _cacheSession(profile);
      return {
        'user': profile,
        'token': await credential.user!.getIdToken(),
      };
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    } on FirebaseException catch (e) {
      throw ApiException(
        statusCode: 403,
        message:
            'Could not read the Firestore profile (${e.code}). Check the Firestore rules.',
      );
    }
  }

  /// Creates a Firebase Authentication account and its Firestore profile.
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
    _ensureFirebase();
    final normalizedRole = role.toUpperCase();
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      await credential.user!.updateDisplayName(name.trim());

      final profile = await FirestoreProfileService.instance.saveProfile(
        uid: credential.user!.uid,
        name: name.trim(),
        mobile: normalizeMobile(mobile),
        email: email.trim().toLowerCase(),
        role: normalizedRole,
        providerCategory: category,
        garageName: garageName,
      );
      await _cacheSession(profile);
      return {
        'user': profile,
        'token': await credential.user!.getIdToken(),
      };
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    } on FirebaseException catch (e) {
      throw ApiException(
        statusCode: 403,
        message:
            'Account created, but the Firestore profile could not be saved (${e.code}). Check the Firestore rules.',
      );
    }
  }

  // ── Google ────────────────────────────────────────────────────────────

  /// Signs in with Google and creates the Firestore profile on first use.
  static Future<Map<String, dynamic>> signInWithGoogle({
    String? role,
    String? mobile,
    String? providerCategory,
    String? garageName,
  }) async {
    _ensureFirebase();
    try {
      late final UserCredential credential;

      if (kIsWeb) {
        credential = await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          throw const ApiException(
            statusCode: 401,
            message: 'Google sign-in was cancelled.',
          );
        }
        final googleAuth = await googleUser.authentication;
        credential = await _auth.signInWithCredential(
          GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          ),
        );
      }

      var profile = await _syncProfile(
        credential.user!,
        fallbackRole: role,
        fallbackMobile: mobile,
      );

      if (providerCategory != null || garageName != null) {
        final patch = <String, dynamic>{};
        if (providerCategory != null && providerCategory.isNotEmpty) {
          patch['providerCategory'] = providerCategory.toUpperCase();
          patch['category'] = providerCategory.toUpperCase();
        }
        if (garageName != null && garageName.isNotEmpty) {
          patch['garageName'] = garageName;
        }
        if (patch.isNotEmpty) {
          profile = await FirestoreProfileService.instance.updateProfile(
                credential.user!.uid,
                patch,
              ) ??
              profile;
        }
      }

      await _cacheSession(profile);
      return {
        'user': profile,
        'token': await credential.user!.getIdToken(),
      };
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    } on PlatformException catch (e) {
      throw _googlePlatformMessage(e);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw const ApiException(
        statusCode: 400,
        message: 'Google sign-in failed. Please try again.',
      );
    }
  }

  // ── Phone OTP ─────────────────────────────────────────────────────────

  /// Sends a Firebase phone verification code.
  static Future<Map<String, dynamic>> sendOtp({required String mobile}) async {
    _ensureFirebase();
    final phone = mobile.trim().startsWith('+')
        ? mobile.trim()
        : '+91${normalizeMobile(mobile)}';
    final completer = Completer<Map<String, dynamic>>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          final result = await _auth.signInWithCredential(credential);
          final profile = await _syncProfile(result.user!);
          await _cacheSession(profile);
          if (!completer.isCompleted) {
            completer.complete({
              'autoVerified': true,
              'user': profile,
              'token': await result.user!.getIdToken(),
            });
          }
        } catch (e) {
          if (!completer.isCompleted) {
            completer.completeError(
              const ApiException(
                statusCode: 400,
                message: 'Phone verification failed. Please try again.',
              ),
            );
          }
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!completer.isCompleted) completer.completeError(_mapAuthError(e));
      },
      codeSent: (String verificationId, int? resendToken) {
        _pendingVerificationId = verificationId;
        if (!completer.isCompleted) {
          completer.complete({
            'verificationId': verificationId,
            'phone': phone,
          });
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _pendingVerificationId = verificationId;
      },
    );

    return completer.future;
  }

  /// Verifies the SMS code sent by [sendOtp].
  static Future<Map<String, dynamic>> verifyOtp({
    required String mobile,
    required String otp,
  }) async {
    _ensureFirebase();
    final verificationId = _pendingVerificationId;
    if (verificationId == null || verificationId.isEmpty) {
      throw const ApiException(
        statusCode: 400,
        message: 'OTP session expired. Please request a new code.',
      );
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp.trim(),
      );
      final result = await _auth.signInWithCredential(credential);
      final profile = await _syncProfile(
        result.user!,
        fallbackMobile: normalizeMobile(mobile),
      );
      await _cacheSession(profile);
      return {
        'user': profile,
        'token': await result.user!.getIdToken(),
      };
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    } finally {
      _pendingVerificationId = null;
    }
  }

  // ── Profile ───────────────────────────────────────────────────────────

  /// Reads the current Firestore profile, creating it if missing.
  static Future<Map<String, dynamic>> getMe() async {
    _ensureFirebase();
    final user = _auth.currentUser;
    if (user == null) {
      throw const ApiException(
        statusCode: 401,
        message: 'Please sign in to continue.',
      );
    }
    return _syncProfile(user);
  }

  static Future<Map<String, dynamic>> _syncProfile(
    User user, {
    String? fallbackMobile,
    String? fallbackRole,
  }) async {
    if (_cachedUid == user.uid && _cachedProfile != null) {
      return _cachedProfile!;
    }

    var profile = await FirestoreProfileService.instance.getProfile(user.uid);
    if (profile == null) {
      final claimRole = await _roleFromToken(user);
      profile = await FirestoreProfileService.instance.saveProfile(
        uid: user.uid,
        name: _displayName(user),
        mobile: normalizeMobile(user.phoneNumber ?? fallbackMobile ?? ''),
        email: user.email,
        role: (claimRole ?? fallbackRole ?? 'CUSTOMER').toUpperCase(),
      );
    }

    _cachedProfile = profile;
    _cachedUid = user.uid;
    return profile;
  }

  static String _displayName(User user) {
    final display = user.displayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final email = user.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return 'RoadRescue User';
  }

  static Future<String?> _roleFromToken(User user) async {
    try {
      final token = await user.getIdTokenResult();
      final role = token.claims?['role'];
      return role is String ? role.toUpperCase() : null;
    } catch (_) {
      return null;
    }
  }

  /// Clears the Firebase session and the local cache.
  static Future<void> clearSession() async {
    if (_firebaseReady) {
      await _auth.signOut();
    }
    _cachedProfile = null;
    _cachedUid = null;
    _pendingVerificationId = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userRoleKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userMobileKey);
  }

  static ApiException _googlePlatformMessage(PlatformException e) {
    switch (e.code) {
      case 'sign_in_canceled':
      case 'canceled':
        return const ApiException(
          statusCode: 401,
          message: 'Google sign-in was cancelled.',
        );
      case 'network_error':
        return const ApiException(
          statusCode: 503,
          message: 'Network error. Check your connection and try again.',
        );
      case 'sign_in_failed':
        return const ApiException(
          statusCode: 400,
          message:
              'Google sign-in could not start. Confirm Google sign-in is enabled in Firebase and the app signing certificate is registered.',
        );
      default:
        return const ApiException(
          statusCode: 400,
          message: 'Google sign-in failed. Please try again.',
        );
    }
  }

  static ApiException _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return const ApiException(
          statusCode: 409,
          message: 'This email is already registered. Please sign in instead.',
        );
      case 'invalid-email':
        return const ApiException(
          statusCode: 400,
          message: 'Please enter a valid email address.',
        );
      case 'weak-password':
        return const ApiException(
          statusCode: 400,
          message: 'Password is too weak (minimum 6 characters).',
        );
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return const ApiException(
          statusCode: 401,
          message:
              'Invalid email or password. Use the exact email/password registered in Firebase Authentication. If you created this account with Google, add a password in Firebase Authentication first.',
        );
      case 'user-disabled':
        return const ApiException(
          statusCode: 403,
          message: 'This account has been disabled in Firebase Authentication.',
        );
      case 'too-many-requests':
        return const ApiException(
          statusCode: 429,
          message: 'Too many attempts. Please wait and try again.',
        );
      case 'network-request-failed':
        return const ApiException(
          statusCode: 503,
          message: 'Network error. Check your connection and try again.',
        );
      case 'operation-not-allowed':
        return const ApiException(
          statusCode: 403,
          message:
              'This sign-in method is not enabled in Firebase Authentication.',
        );
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
      case 'web-context-cancelled':
        return const ApiException(
          statusCode: 401,
          message: 'Google sign-in was cancelled.',
        );
      case 'popup-blocked':
        return const ApiException(
          statusCode: 400,
          message:
              'The Google popup was blocked. Allow popups for this site and try again.',
        );
      case 'unauthorized-domain':
        return const ApiException(
          statusCode: 403,
          message:
              'This domain is not authorized for Google sign-in. Add it in Firebase Authentication → Settings → Authorized domains.',
        );
      case 'operation-not-supported-in-this-environment':
        return const ApiException(
          statusCode: 400,
          message:
              'Google sign-in is not supported in this browser. Try Chrome or the deployed web app.',
        );
      case 'argument-error':
        return const ApiException(
          statusCode: 400,
          message:
              'Google sign-in configuration is invalid. Check the Firebase web app configuration.',
        );
      case 'internal-error':
        return const ApiException(
          statusCode: 500,
          message: 'Firebase could not complete Google sign-in. Please try again.',
        );
      case 'account-exists-with-different-credential':
        return const ApiException(
          statusCode: 409,
          message:
              'An account already exists with this email using a different sign-in method. Sign in with that method first.',
        );
      case 'invalid-verification-code':
        return const ApiException(
          statusCode: 400,
          message: 'Invalid OTP code. Please check the SMS and try again.',
        );
      case 'invalid-phone-number':
        return const ApiException(
          statusCode: 400,
          message: 'Please enter a valid mobile number with country code.',
        );
      case 'missing-verification-id':
      case 'session-expired':
        return const ApiException(
          statusCode: 400,
          message: 'OTP session expired. Please request a new code.',
        );
      default:
        return ApiException(
          statusCode: 400,
          message: e.message ?? 'Authentication failed (${e.code}).',
        );
    }
  }
}
