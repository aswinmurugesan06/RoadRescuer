@TestOn('browser')
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_rescue/services/firebase/firebase_auth_service.dart';
import 'package:road_rescue/services/firebase/firestore_profile_service.dart';

import 'support/firebase_web.dart';

// End-to-end check of the Firebase auth + Firestore profile layer used by the
// mobile app. This exercises the real `FirebaseAuthService` (not just the raw
// SDK): email/password sign-up and sign-in, ID token issuance, profile
// creation/read/update in Cloud Firestore (`users/{uid}`), and role lookup.
//
// Run it against your project from `mobile/`:
//
//   flutter test --platform chrome test/firebase_auth_db_test.dart \
//     --dart-define-from-file=firebase_test_config.json
//
// Copy `firebase_test_config.example.json` to `firebase_test_config.json` and
// fill in the values from Firebase Console → Project settings → Your apps.
//
// It uses a throw-away account and deletes it at the end.

const String _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
const String _authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
const String _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
const String _storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
const String _messagingSenderId =
    String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
const String _appId = String.fromEnvironment('FIREBASE_APP_ID');
const String _measurementId = String.fromEnvironment('FIREBASE_MEASUREMENT_ID');
const bool _useEmulators = bool.fromEnvironment('FIREBASE_USE_EMULATORS');
const String _emulatorHost =
    String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: 'localhost');

const String _password = 'RoadRescue!Test123';

bool get _hasConfig =>
    _useEmulators ||
    (_apiKey.isNotEmpty &&
        _projectId.isNotEmpty &&
        _appId.isNotEmpty &&
        _messagingSenderId.isNotEmpty);

String get _skipReason =>
    'Missing Firebase config. Pass --dart-define-from-file=firebase_test_config.json '
    '(FIREBASE_API_KEY, FIREBASE_PROJECT_ID, FIREBASE_APP_ID, '
    'FIREBASE_MESSAGING_SENDER_ID, ...), or set FIREBASE_USE_EMULATORS=true.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerFirebaseWebPlugins();

  final bool configured = _hasConfig;
  final String email =
      'roadrescue.e2e.${DateTime.now().microsecondsSinceEpoch}@example.com';

  late FirebaseAuth auth;
  late FirebaseFirestore db;
  final service = FirebaseAuthService.instance;
  String? uid;

  setUpAll(() async {
    if (!configured) return;

    if (Firebase.apps.isEmpty) {
      const projectId = _useEmulators ? 'demo-roadrescue' : _projectId;
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: _useEmulators ? 'demo-api-key' : _apiKey,
          authDomain: _useEmulators
              ? 'localhost'
              : (_authDomain.isNotEmpty
                  ? _authDomain
                  : '$_projectId.firebaseapp.com'),
          projectId: projectId,
          storageBucket: _useEmulators
              ? '$projectId.appspot.com'
              : (_storageBucket.isNotEmpty
                  ? _storageBucket
                  : '$_projectId.appspot.com'),
          messagingSenderId: _useEmulators ? '1' : _messagingSenderId,
          appId: _useEmulators ? '1:1:web:1' : _appId,
          measurementId: _measurementId.isEmpty ? null : _measurementId,
        ),
      );
    }

    auth = FirebaseAuth.instance;
    db = FirebaseFirestore.instance;

    if (_useEmulators) {
      auth.useAuthEmulator(_emulatorHost, 9099);
      db.useFirestoreEmulator(_emulatorHost, 8080);
    }
  });

  tearDownAll(() async {
    if (!configured) return;

    final user = auth.currentUser;
    final id = uid ?? user?.uid;
    if (id != null) {
      try {
        await FirestoreProfileService.instance.deleteProfile(id);
      } catch (_) {
        // Best-effort cleanup; deleting the auth user is what matters.
      }
    }

    if (user == null) return;
    try {
      await user.delete();
    } on FirebaseAuthException {
      // Recent-login can still be required on some projects.
      await auth.signOut();
    }
  });

  group('Firebase auth + Firestore', () {
    test('sign-up creates a Firestore profile and a valid ID token', () async {
      final result = await service.signUpWithEmail(
        email: email,
        password: _password,
        name: 'RoadRescue E2E',
        mobile: '+919999999999',
        role: 'CUSTOMER',
      );

      expect(result.success, isTrue, reason: result.message);
      expect(service.currentUser, isNotNull);

      uid = service.currentUser!.uid;
      expect(uid, isNotEmpty);

      final profile = await service.getMe();
      expect(profile, isNotNull, reason: 'users/{uid} should exist');
      expect(profile!['uid'], uid);
      expect(profile['name'], 'RoadRescue E2E');
      expect(profile['mobile'], '+919999999999');
      expect(profile['email'], email);
      expect(profile['role'], 'CUSTOMER');

      final token = await auth.currentUser!.getIdTokenResult(true);
      expect(token.token, isNotNull);
      expect(token.token, isNotEmpty);
      expect(token.claims?['user_id'] ?? token.claims?['sub'], uid);

      expect(await service.currentRole(), 'CUSTOMER');
    }, skip: configured ? false : _skipReason);

    test('profile update is persisted in Firestore', () async {
      expect(uid, isNotNull, reason: 'sign-up test must run first');

      final updated = await service.updateProfile(<String, dynamic>{
        'name': 'RoadRescue E2E Updated',
        'garageName': 'E2E Garage',
      });

      expect(updated, isNotNull);
      expect(updated!['name'], 'RoadRescue E2E Updated');
      expect(updated['garageName'], 'E2E Garage');
      expect(updated['uid'], uid);
      expect(updated['createdAt'], isA<Timestamp>(),
          reason: 'the document should keep its original creation time');

      final direct = await db.collection('users').doc(uid).get();
      expect(direct.exists, isTrue);
      expect(direct.data()!['name'], 'RoadRescue E2E Updated');
      expect(direct.data()!['role'], 'CUSTOMER');
    }, skip: configured ? false : _skipReason);

    test('sign-out and sign-in keep the same uid and profile', () async {
      await service.signOut();
      expect(service.currentUser, isNull);
      expect(await service.getIdToken(), isNull);

      final result = await service.signInWithEmail(
        email: email,
        password: _password,
      );

      expect(result.success, isTrue, reason: result.message);
      expect(service.currentUser!.uid, uid);
      expect(result.role, 'CUSTOMER');
      expect(result.user?['name'], 'RoadRescue E2E Updated');
    }, skip: configured ? false : _skipReason);

    test('role cannot be escalated by the client', () async {
      await expectLater(
        service.updateProfile(<String, dynamic>{'role': 'ADMIN'}),
        throwsA(isA<FirebaseException>()),
      );

      expect(await service.currentRole(), 'CUSTOMER');
    }, skip: configured ? false : _skipReason);

    test('unauthenticated reads are denied', () async {
      await service.signOut();

      await expectLater(
        db.collection('users').doc(uid).get(),
        throwsA(isA<FirebaseException>()),
      );

      // Restore the session so tearDownAll can delete the test account.
      final result = await service.signInWithEmail(
        email: email,
        password: _password,
      );
      expect(result.success, isTrue, reason: result.message);
    }, skip: configured ? false : _skipReason);
  });
}
