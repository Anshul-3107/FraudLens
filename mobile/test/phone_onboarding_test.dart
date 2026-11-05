import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fraudlens/config/app_theme.dart';
import 'package:fraudlens/models/card.dart';
import 'package:fraudlens/models/user.dart';
import 'package:fraudlens/providers/alert_provider.dart';
import 'package:fraudlens/providers/auth_provider.dart';
import 'package:fraudlens/providers/card_provider.dart';
import 'package:fraudlens/providers/currency_provider.dart';
import 'package:fraudlens/providers/dashboard_provider.dart';
import 'package:fraudlens/providers/investigation_provider.dart';
import 'package:fraudlens/providers/theme_provider.dart';
import 'package:fraudlens/providers/transaction_provider.dart';
import 'package:fraudlens/screens/auth/phone_onboarding_screen.dart';
import 'package:fraudlens/services/auth_service.dart';
import 'package:fraudlens/services/card_service.dart';

class MockAuthService extends AuthService {
  bool otpSent = false;
  bool otpVerified = false;
  bool bankLinked = false;

  @override
  Future<Map<String, dynamic>> sendOtp(String phone) async {
    otpSent = true;
    return {'detail': 'Verification code sent', 'phone': phone};
  }

  @override
  Future<AuthResponse> verifyOtp({
    required String phone,
    required String code,
  }) async {
    otpVerified = true;
    return AuthResponse(token: 'mock_token_123', username: 'user_test');
  }

  @override
  Future<UserMe> getMe() async {
    return UserMe(
      id: 1,
      username: 'user_test',
      email: 'test@example.com',
      isStaff: false,
      cardCount: 1,
    );
  }

  @override
  Future<Map<String, dynamic>> linkBankAccount({
    required String bankName,
    required String accountNumber,
    double? homeLat,
    double? homeLong,
  }) async {
    bankLinked = true;
    return {
      'id': 1,
      'label': '$bankName A/c •• ${accountNumber.substring(accountNumber.length - 4)}',
    };
  }
}

class MockCardService extends CardService {
  @override
  Future<List<CardModel>> getAllCards() async => [];
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('PhoneOnboardingScreen runs full 3-step onboarding flow', (tester) async {
    final mockAuth = MockAuthService();
    final authProvider = AuthProvider(authService: mockAuth);
    final cardProvider = CardProvider(cardService: MockCardService());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<CardProvider>.value(value: cardProvider),
          ChangeNotifierProvider<DashboardProvider>(create: (_) => DashboardProvider()),
          ChangeNotifierProvider<AlertProvider>(create: (_) => AlertProvider()),
          ChangeNotifierProvider<InvestigationProvider>(create: (_) => InvestigationProvider()),
          ChangeNotifierProvider<TransactionProvider>(create: (_) => TransactionProvider()),
          ChangeNotifierProvider<CurrencyProvider>(create: (_) => CurrencyProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const PhoneOnboardingScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Step 1: Verify Initial Screen
    expect(find.text('Verify Mobile Number'), findsOneWidget);
    expect(find.text('Send Verification Code'), findsOneWidget);

    // Enter 10-digit mobile number
    await tester.enterText(find.byType(TextFormField).first, '9876543210');
    await tester.tap(find.text('Send Verification Code'));
    await tester.pumpAndSettle();

    expect(mockAuth.otpSent, isTrue);

    // Step 2: Verify OTP Screen transitioned
    expect(find.text('Enter Verification Code'), findsOneWidget);
    expect(find.text('Verify & Continue'), findsOneWidget);

    // Enter 6-digit OTP
    await tester.enterText(find.byType(TextFormField).first, '123456');
    await tester.tap(find.text('Verify & Continue'));
    await tester.pumpAndSettle();

    expect(mockAuth.otpVerified, isTrue);

    // Step 3: Link Bank Account Screen transitioned
    expect(find.text('Link Primary Bank Account'), findsOneWidget);
    expect(find.text('Select Bank'), findsOneWidget);
    expect(find.text('Link Account & Start Monitoring'), findsOneWidget);

    // Enter Account number
    await tester.enterText(find.byType(TextFormField).first, '50100492819719');
    await tester.tap(find.text('Link Account & Start Monitoring'));
    await tester.pumpAndSettle();

    expect(mockAuth.bankLinked, isTrue);
  });
}
