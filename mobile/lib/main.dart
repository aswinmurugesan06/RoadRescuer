import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_routes.dart';

void main() {
  runApp(const RoadRescueApp());
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
      themeMode: ThemeMode.system,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}
