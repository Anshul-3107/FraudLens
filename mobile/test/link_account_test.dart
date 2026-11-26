import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fraudlens/config/app_theme.dart';
import 'package:fraudlens/models/card.dart';
import 'package:fraudlens/models/paginated_response.dart';
import 'package:fraudlens/models/user.dart';
import 'package:fraudlens/providers/auth_provider.dart';
import 'package:fraudlens/providers/card_provider.dart';
import 'package:fraudlens/screens/cards/link_account_screen.dart';
import 'package:fraudlens/services/auth_service.dart';
import 'package:fraudlens/services/card_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends AuthService {
  bool bankLinked = false;
  String? linkedBankName;

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
    linkedBankName = bankName;
    return {
      'id': 1,
      'label':
          '$bankName A/c •• ${accountNumber.substring(accountNumber.length - 4)}',
    };
  }
}

class _MockCardService extends CardService {
  @override
  Future<List<CardModel>> getAllCards() async => [];

  @override
  Future<PaginatedResponse<CardModel>> getCards({int page = 1}) async {
    return PaginatedResponse(count: 0, next: null, previous: null, results: []);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('LinkAccountScreen links bank account without OTP steps', (
    tester,
  ) async {
    final mockAuth = _MockAuthService();
    final authProvider = AuthProvider(authService: mockAuth);
    final cardProvider = CardProvider(cardService: _MockCardService());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<CardProvider>.value(value: cardProvider),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LinkAccountScreen(),
                      ),
                    );
                  },
                  child: const Text('Open Link'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    await tester.tap(find.text('Open Link'));
    await tester.pumpAndSettle();

    expect(find.text('Link Bank Account'), findsOneWidget);
    expect(find.text('Connect an Account'), findsOneWidget);
    expect(find.text('Sign in with Phone'), findsNothing);
    expect(find.text('Send Code'), findsNothing);

    await tester.enterText(find.byType(TextFormField).first, '50100492819719');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Link Account'));
    await tester.pumpAndSettle();

    expect(mockAuth.bankLinked, isTrue);
    expect(mockAuth.linkedBankName, 'HDFC Bank');
    expect(find.text('HDFC Bank linked successfully'), findsOneWidget);
  });
}
