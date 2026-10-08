import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_rescue/widgets/app_logo.dart';
import 'package:road_rescue/main.dart';

void main() {
  testWidgets('RoadRescue AppLogo widget test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppLogo.splash(),
        ),
      ),
    );

    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('RoadRescue splash screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RoadRescueApp());
    expect(find.byType(AppLogo), findsOneWidget);
  });
}
