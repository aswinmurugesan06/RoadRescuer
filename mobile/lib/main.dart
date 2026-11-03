import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_routes.dart';
import 'services/firebase/firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeFirebase();
  runApp(const RoadRescueApp());
}

/// Connect the app to the `road-rescuer` Firebase project before the first
/// frame. Native builds read `android/app/google-services.json`; web builds
/// read the `FIREBASE_*` values passed with `--dart-define-from-file`.
///
/// A Firebase failure is logged instead of crashing so the app can still run
/// while the project configuration is being completed.
Future<void> _initializeFirebase() async {
  try {
    await FirebaseBootstrap.initializeForCurrentPlatform();
    debugPrint(
      'Firebase connected: project=${FirebaseBootstrap.projectId}',
    );
  } catch (error, stackTrace) {
    debugPrint('Firebase initialisation failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class RoadRescueApp extends StatelessWidget {
  const RoadRescueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RoadRescue',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.generateRoute,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final scale = media.textScaler.scale(1).clamp(0.9, 1.1);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
