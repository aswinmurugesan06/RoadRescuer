import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_rescue/features/auth/screens/login_screen.dart';
import 'package:road_rescue/features/auth/screens/register_screen.dart';

void main() {
  testWidgets('login screen shows Google sign-in', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen(initialRole: 'CUSTOMER')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('register screen shows Google sign-up', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: RegisterScreen(initialRole: 'customer')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign up with Google'), findsOneWidget);
  });
}
