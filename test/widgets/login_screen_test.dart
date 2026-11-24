import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:urban_pets_verify/features/auth/presentation/screens/login_screen.dart';

void main() {
  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );
    // Let the AuthController's session-restore future settle.
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows validation errors on empty/invalid input instead of submitting',
    (tester) async {
      await pumpLogin(tester);

      expect(find.text('Login'), findsOneWidget);

      // Tap Login with empty fields.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    },
  );

  testWidgets('shows an email format error for a badly formed email', (
    tester,
  ) async {
    await pumpLogin(tester);

    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.enterText(find.byType(TextFormField).last, 'somepassword');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address'), findsOneWidget);
  });
}
