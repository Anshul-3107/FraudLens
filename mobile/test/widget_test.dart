import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fraudlens/providers/auth_provider.dart';
import 'package:fraudlens/screens/auth/login_screen.dart';

void main() {
  testWidgets(
    'LoginScreen smoke test: displays brand, inputs, and submit button',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      // Verify Brand title & subtitle
      expect(find.text('FraudLens'), findsOneWidget);
      expect(find.text('AI-Powered Financial Fraud Detection'), findsOneWidget);

      // Verify Form Fields
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);

      // Verify Sign In heading and button
      expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);

      // Verify Registration link
      expect(find.text('Register'), findsOneWidget);
    },
  );
}
