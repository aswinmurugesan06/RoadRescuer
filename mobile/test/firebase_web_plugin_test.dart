@TestOn('browser')
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/firebase_web.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerFirebaseWebPlugins();

  test('firebase_core_web plugin is registered', () async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'fake-api-key',
          appId: '1:1:web:1',
          messagingSenderId: '1',
          projectId: 'demo-roadrescue',
        ),
      );
    }

    expect(Firebase.apps, isNotEmpty);
    expect(Firebase.app().options.projectId, 'demo-roadrescue');
  });
}
