import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Firebase bootstrap for the RoadRescue app.
///
/// The Firebase backend is a **parallel** implementation of the existing
/// Express/Prisma backend. Existing services and screens keep using the REST
/// [ApiClient]; the Firebase paths live under `lib/services/firebase/` and can
/// be adopted incrementally.
///
/// Native setup (Android/iOS):
///   1. Put `google-services.json` in `android/app/`.
///   2. Put `GoogleService-Info.plist` in `ios/Runner/`.
///   3. Call [FirebaseBootstrap.initialize] from `main()`.
///
/// Web setup: pass the web [FirebaseOptions], either explicitly or through
/// [initializeFromEnvironment] with the `FIREBASE_*` dart-defines. Web apps
/// cannot use the native config files.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  /// Project ID of the initialised Firebase app, or null before initialisation.
  static String? get projectId =>
      _initialized ? Firebase.app().options.projectId : null;

  /// Whether `FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID` and `FIREBASE_APP_ID`
  /// were supplied through `--dart-define` / `--dart-define-from-file`.
  static bool get hasEnvironmentConfig {
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    return apiKey.isNotEmpty && projectId.isNotEmpty && appId.isNotEmpty;
  }

  /// Initialise Firebase with the right source for the current platform.
  ///
  /// Native builds (Android/iOS) use `google-services.json` /
  /// `GoogleService-Info.plist`. Web builds use the `FIREBASE_*` dart-defines.
  static Future<void> initializeForCurrentPlatform() async {
    if (kIsWeb) {
      if (hasEnvironmentConfig) {
        await initializeFromEnvironment();
      } else {
        await initialize(options: DefaultFirebaseOptions.web);
      }
    } else {
      await initialize();
    }
  }

  /// Initialise Firebase using native config files (Android/iOS) or the
  /// provided [options] (required on web).
  ///
  /// Call this once from `main()` before `runApp` if you want the app to use
  /// Firebase (auth / Firestore / FCM):
  ///
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await FirebaseBootstrap.initialize();
  ///   runApp(const RoadRescueApp());
  /// }
  /// ```
  static Future<void> initialize({FirebaseOptions? options}) async {
    if (_initialized) return;
    await Firebase.initializeApp(options: options);
    _initialized = true;
  }

  /// Initialise Firebase from `--dart-define` / `--dart-define-from-file`
  /// values. Useful for web builds and integration tests.
  ///
  /// Required: `FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID`,
  /// `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_APP_ID`.
  /// Optional: `FIREBASE_AUTH_DOMAIN`, `FIREBASE_STORAGE_BUCKET`,
  /// `FIREBASE_MEASUREMENT_ID`.
  static Future<void> initializeFromEnvironment() async {
    if (_initialized) return;

    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
    const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
    const measurementId = String.fromEnvironment('FIREBASE_MEASUREMENT_ID');

    if (!hasEnvironmentConfig) {
      throw StateError(
        'FIREBASE_API_KEY, FIREBASE_PROJECT_ID and FIREBASE_APP_ID must be '
        'provided with --dart-define / --dart-define-from-file.',
      );
    }

    await initialize(
      options: FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: senderId,
        projectId: projectId,
        authDomain:
            authDomain.isNotEmpty ? authDomain : '$projectId.firebaseapp.com',
        storageBucket:
            storageBucket.isNotEmpty ? storageBucket : '$projectId.appspot.com',
        measurementId: measurementId.isEmpty ? null : measurementId,
      ),
    );
  }

  /// Connect the default Firebase app to the local Emulator Suite.
  ///
  /// Only call this after [initialize]. Use `10.0.2.2` as [host] from the
  /// Android emulator and `localhost` from web/iOS simulators.
  static void useEmulators({
    String host = 'localhost',
    int authPort = 9099,
    int firestorePort = 8080,
  }) {
    if (!_initialized) {
      throw StateError('Call FirebaseBootstrap.initialize() first.');
    }
    FirebaseAuth.instance.useAuthEmulator(host, authPort);
    FirebaseFirestore.instance.useFirestoreEmulator(host, firestorePort);
  }
}
