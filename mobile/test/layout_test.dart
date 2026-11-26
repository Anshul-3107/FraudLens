import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fraudlens/config/app_theme.dart';
import 'package:fraudlens/models/alert.dart';
import 'package:fraudlens/models/card.dart' as model;
import 'package:fraudlens/models/investigation.dart';
import 'package:fraudlens/models/paginated_response.dart';
import 'package:fraudlens/models/summary.dart';
import 'package:fraudlens/models/transaction.dart';
import 'package:fraudlens/models/user.dart';
import 'package:fraudlens/providers/alert_provider.dart';
import 'package:fraudlens/providers/auth_provider.dart';
import 'package:fraudlens/providers/card_provider.dart';
import 'package:fraudlens/providers/chat_provider.dart';
import 'package:fraudlens/providers/currency_provider.dart';
import 'package:fraudlens/providers/dashboard_provider.dart';
import 'package:fraudlens/providers/investigation_provider.dart';
import 'package:fraudlens/providers/theme_provider.dart';
import 'package:fraudlens/providers/transaction_provider.dart';
import 'package:fraudlens/screens/navigation/app_shell.dart';
import 'package:fraudlens/services/alert_service.dart';
import 'package:fraudlens/services/auth_service.dart';
import 'package:fraudlens/services/card_service.dart';
import 'package:fraudlens/services/investigation_service.dart';
import 'package:fraudlens/services/summary_service.dart';
import 'package:fraudlens/services/transaction_service.dart';
import 'package:fraudlens/widgets/spend_chart.dart';

class _MockAuthService extends AuthService {
  @override
  Future<UserMe> getMe() async => UserMe(
    id: 1,
    username: 'anshul',
    email: 'anshul@example.com',
    isStaff: false,
    cardCount: 1,
  );
}

class _MockSummaryService extends SummaryService {
  @override
  Future<SummaryModel> getSummary({
    int? cardId,
    String? dateFrom,
    String? dateTo,
  }) async {
    return SummaryModel(
      totalSpend: 14840.00,
      currency: 'INR',
      transactionCount: 18,
      alertsByStatus: AlertsByStatus(open: 2, inReview: 1, resolved: 5),
      byCategory: [
        CategorySpend(category: 'food_dining', total: 4200, count: 6),
        CategorySpend(category: 'grocery_pos', total: 6400, count: 8),
      ],
      monthly: [
        MonthlySpend(month: '2026-10', total: 7200, count: 9),
        MonthlySpend(month: '2026-11', total: 7640, count: 9),
      ],
    );
  }
}

class _MockCardService extends CardService {
  @override
  Future<List<model.CardModel>> getAllCards() async => [
    model.CardModel(id: 1, label: 'HDFC Bank A/c •• 9719'),
  ];

  @override
  Future<PaginatedResponse<model.CardModel>> getCards({int page = 1}) async {
    return PaginatedResponse(
      count: 1,
      next: null,
      previous: null,
      results: [model.CardModel(id: 1, label: 'HDFC Bank A/c •• 9719')],
    );
  }
}

class _MockTransactionService extends TransactionService {
  @override
  Future<PaginatedResponse<TransactionModel>> getTransactions({
    int page = 1,
    int? cardId,
    String? category,
    String? search,
    String? dateFrom,
    String? dateTo,
    double? minAmount,
    bool? flagged,
  }) async {
    return PaginatedResponse(
      count: 1,
      next: null,
      previous: null,
      results: [
        TransactionModel(
          id: 1,
          transRef: 'TXN-1',
          card: 1,
          cardLabel: 'HDFC •• 9719',
          occurredAt: DateTime(2026, 11, 26, 14, 15),
          merchant: 'Swiggy Instamart',
          category: 'grocery_pos',
          amount: 420.0,
          source: 'notification',
          hasAlert: false,
          currency: 'INR',
        ),
      ],
    );
  }
}

class _MockAlertService extends AlertService {
  @override
  Future<PaginatedResponse<AlertModel>> getAlerts({
    int page = 1,
    String? status,
    int? cardId,
    double? minScore,
    String? ordering,
  }) async {
    return PaginatedResponse(count: 0, next: null, previous: null, results: []);
  }
}

class _MockInvestigationService extends InvestigationService {
  @override
  Future<PaginatedResponse<InvestigationModel>> getInvestigations({
    int page = 1,
  }) async {
    return PaginatedResponse(count: 0, next: null, previous: null, results: []);
  }
}

Widget createTestApp({
  required Widget child,
  Size size = const Size(360, 640),
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(
        create: (_) => AuthProvider(authService: _MockAuthService()),
      ),
      ChangeNotifierProvider(
        create: (_) => DashboardProvider(summaryService: _MockSummaryService()),
      ),
      ChangeNotifierProvider(
        create: (_) =>
            TransactionProvider(transactionService: _MockTransactionService()),
      ),
      ChangeNotifierProvider(
        create: (_) => AlertProvider(alertService: _MockAlertService()),
      ),
      ChangeNotifierProvider(
        create: (_) => InvestigationProvider(
          investigationService: _MockInvestigationService(),
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => CardProvider(cardService: _MockCardService()),
      ),
      ChangeNotifierProvider(create: (_) => CurrencyProvider()),
      ChangeNotifierProvider(create: (_) => ChatProvider()),
    ],
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: SizedBox(width: size.width, height: size.height, child: child),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Fixed 4-Tab Navigation Tests', () {
    testWidgets('Warmup theme font loading', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.darkTheme, home: const SizedBox()),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
    });

    testWidgets(
      'Renders all 4 fixed destinations without horizontal scrolling on 320px and 360px',
      (tester) async {
        for (final width in [320.0, 360.0]) {
          final size = Size(width, 640);
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(
            createTestApp(child: const AppShell(), size: size),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));

          expect(tester.takeException(), isNull);
          expect(find.byType(NavigationBar), findsOneWidget);
          expect(find.text('Home'), findsWidgets);
          expect(find.text('Activity'), findsWidgets);
          expect(find.text('Alerts'), findsWidgets);
          expect(find.text('Accounts'), findsWidgets);
        }
      },
    );

    testWidgets('Tapping destinations switches active screen cleanly', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        createTestApp(child: const AppShell(), size: const Size(360, 640)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Activity').last);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Alerts').last);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Accounts').last);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Home').last);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tablet viewport (>= 768px) switches to NavigationRail', (
      tester,
    ) async {
      const tabletSize = Size(820, 900);
      await tester.binding.setSurfaceSize(tabletSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        createTestApp(child: const AppShell(), size: tabletSize),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Dashboard Spending Activity Layout & Overflow Tests', () {
    testWidgets(
      'MonthlySpendChart and CategorySpendBreakdown render without overflow on 320px width',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final testMonthly = <MonthlySpend>[
          MonthlySpend(month: '2026-01', total: 125000.50, count: 120),
          MonthlySpend(month: '2026-02', total: 154200.00, count: 145),
          MonthlySpend(month: '2026-03', total: 98000.00, count: 90),
        ];

        final testCategories = [
          CategorySpend(
            category: 'VERY_LONG_MERCHANT_CATEGORY_VERTICAL_NAME_TEST',
            count: 1420,
            total: 450000.0,
          ),
          CategorySpend(
            category: 'electronics_retail',
            count: 320,
            total: 85200.0,
          ),
        ];

        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => CurrencyProvider(),
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      MonthlySpendChart(monthlyData: testMonthly),
                      const SizedBox(height: 16),
                      CategorySpendBreakdown(categories: testCategories),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
        expect(find.text('1,420 payments'), findsOneWidget);
      },
    );
  });
}
