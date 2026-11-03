import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import 'firestore_profile_service.dart';

/// Result of an auth operation.
class FirebaseAuthResult {
  final bool success;
  final String? message;
  final Map<String, dynamic>? user;
  final String? role;

  const FirebaseAuthResult({
    required this.success,
    this.message,
    this.user,
    this.role,
  });

  factory FirebaseAuthResult.failure(String message) =>
      FirebaseAuthResult(success: false, message: message);
}

/// Firebase Authentication service for RoadRescue.
///
/// Credentials are handled **client-side** by Firebase Auth:
///   • Email + password  → `createUserWithEmailAndPassword` / `signInWithEmailAndPassword`
///   • Mobile + SMS OTP  → `verifyPhoneNumber` / `PhoneAuthProvider`
///
/// After the Firebase user exists, the RoadRescue profile (name, mobile, role,
/// provider category) is stored directly in Cloud Firestore at `users/{uid}`.
/// No Cloud Functions deployment is required for this flow.
///
/// The role is read from the Firestore profile. Custom claims are still
/// supported as a fallback if a trusted backend sets them with the Admin SDK
/// (a client app cannot set custom claims itself).
///
/// This class is additive — the existing [AuthService]/[ApiClient] (custom JWT
/// backend) are left untouched.
class FirebaseAuthService {
  FirebaseAuthService._();
  static final FirebaseAuthService instance = FirebaseAuthService._();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Email + password ────────────────────────────────────────────────

  /// Register a new account with email/password and create the profile.
  Future<FirebaseAuthResult> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    required String mobile,
    String role = 'CUSTOMER',
    String? providerCategory,
    String? garageName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.updateDisplayName(name);

      await _createProfile(
        name: name,
        mobile: mobile,
        role: role,
        providerCategory: providerCategory,
        garageName: garageName,
      );

      return FirebaseAuthResult(
        success: true,
        message: 'Account created',
        user: await getMe(),
        role: role.toUpperCase(),
      );
    } on FirebaseAuthException catch (e) {
      return FirebaseAuthResult.failure(_mapAuthError(e));
    } catch (e) {
      return FirebaseAuthResult.failure(e.toString());
    }
  }

  /// Sign in with email/password.
  Future<FirebaseAuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      // Ensure a profile exists (idempotent) and return it.
      final user = await _syncProfile();
      return FirebaseAuthResult(
        success: true,
        message: 'Signed in',
        user: user,
        role: (user?['role'] as String?)?.toUpperCase(),
      );
    } on FirebaseAuthException catch (e) {
      return FirebaseAuthResult.failure(_mapAuthError(e));
    } catch (e) {
      return FirebaseAuthResult.failure(e.toString());
    }
  }

  // ── Mobile + SMS OTP ────────────────────────────────────────────────

  int? _resendToken;

  /// Send an SMS OTP to [phoneNumber] (E.164, e.g. +919876543210).
  ///
  /// Returns the verificationId to pass to [verifyMobileOtp]. On many Android
  /// devices auto-retrieval completes without a code; in that case this returns
  /// null and the user is already signed in.
  Future<String?> sendMobileOtp({
    required String phoneNumber,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final completer = Completer<String?>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: timeout,
      forceResendingToken: _resendToken,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
        if (!completer.isCompleted) completer.complete(null);
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!completer.isCompleted) completer.completeError(_mapAuthError(e));
      },
      codeSent: (String verificationId, int? resendToken) {
        _resendToken = resendToken;
        if (!completer.isCompleted) completer.complete(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
    );

    return completer.future;
  }

  /// Verify the SMS code and create/sync the RoadRescue profile.
  Future<FirebaseAuthResult> verifyMobileOtp({
    required String verificationId,
    required String smsCode,
    String? name,
    String? mobile,
    String role = 'CUSTOMER',
    String? providerCategory,
    String? garageName,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      await _auth.signInWithCredential(credential);

      // If profile details were supplied, create the profile; otherwise sync.
      Map<String, dynamic>? user;
      if (name != null && mobile != null) {
        await _createProfile(
          name: name,
          mobile: mobile,
          role: role,
          providerCategory: providerCategory,
          garageName: garageName,
        );
        user = await getMe();
      } else {
        user = await _syncProfile();
      }

      return FirebaseAuthResult(
        success: true,
        message: 'Mobile number verified',
        user: user,
        role: user?['role'] as String?,
      );
    } on FirebaseAuthException catch (e) {
      return FirebaseAuthResult.failure(_mapAuthError(e));
    } catch (e) {
      return FirebaseAuthResult.failure(e.toString());
    }
  }

  // ── Profile / session ───────────────────────────────────────────────

  Future<Map<String, dynamic>?> _createProfile({
    required String name,
    required String mobile,
    required String role,
    String? providerCategory,
    String? garageName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No Firebase user is signed in.');
    }

    return FirestoreProfileService.instance.saveProfile(
      uid: user.uid,
      name: name,
      mobile: mobile,
      email: user.email,
      role: role.toUpperCase(),
      providerCategory: providerCategory?.toUpperCase(),
      garageName: garageName,
    );
  }

  /// Ensures a Firestore profile exists for the signed-in Firebase user.
  ///
  /// This covers users created before the Firestore profile was added, and
  /// mobile users whose profile was not written during verification.
  Future<Map<String, dynamic>?> _syncProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final existing =
        await FirestoreProfileService.instance.getProfile(user.uid);
    if (existing != null) return existing;

    return FirestoreProfileService.instance.saveProfile(
      uid: user.uid,
      name: user.displayName ?? 'RoadRescue User',
      mobile: user.phoneNumber ?? '',
      email: user.email,
      role: (await _roleFromToken()) ?? 'CUSTOMER',
    );
  }

  /// Reads the profile from Firestore, creating it if it is missing.
  Future<Map<String, dynamic>?> getMe() => _syncProfile();

  /// Updates the profile document in Firestore.
  Future<Map<String, dynamic>?> updateProfile(
      Map<String, dynamic> patch) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return FirestoreProfileService.instance.updateProfile(user.uid, patch);
  }

  /// Current role: the Firestore profile is authoritative. A custom claim is
  /// used as a fallback for projects whose admin backend sets one.
  Future<String?> currentRole({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final profile = await FirestoreProfileService.instance.getProfile(user.uid);
    final profileRole = profile?['role'] as String?;
    if (profileRole != null && profileRole.isNotEmpty) {
      return profileRole.toUpperCase();
    }
    return _roleFromToken(forceRefresh);
  }

  Future<String?> _roleFromToken([bool forceRefresh = false]) async {
    try {
      final token = await _auth.currentUser?.getIdTokenResult(forceRefresh);
      return (token?.claims?['role'] as String?)?.toUpperCase();
    } on FirebaseAuthException {
      return null;
    }
  }

  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return user.getIdToken(forceRefresh);
  }

  Future<void> signOut() => _auth.signOut();

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak (minimum 6 characters).';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-verification-code':
        return 'Invalid OTP code.';
      case 'invalid-phone-number':
        return 'Please enter a valid mobile number.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase.';
      default:
        return e.message ?? 'Authentication failed (${e.code}).';
    }
  }
}
