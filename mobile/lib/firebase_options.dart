import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Firebase options for platforms that cannot read a native config file.
///
/// Android/iOS still use `google-services.json` / `GoogleService-Info.plist`.
/// Web uses these values when no `--dart-define-from-file` is supplied, so
/// `flutter run -d chrome` works out of the box.
class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions? get forCurrentPlatform {
    if (kIsWeb) return web;
    return null;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCSRfo2zyFmWSH0iGyVx5H5A0UXEla_DQw',
    appId: '1:366952442951:web:e8cc5676042d1d7d2d9562',
    messagingSenderId: '366952442951',
    projectId: 'road-rescuer',
    authDomain: 'road-rescuer.firebaseapp.com',
    storageBucket: 'road-rescuer.firebasestorage.app',
    measurementId: 'G-75TYDPH3GY',
  );
}
