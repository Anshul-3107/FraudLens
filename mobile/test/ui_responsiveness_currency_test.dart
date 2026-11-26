import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fraudlens/config/app_theme.dart';
import 'package:fraudlens/models/alert.dart';
import 'package:fraudlens/models/card.dart';
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
import 'package:fraudlens/screens/alerts/alert_detail_screen.dart';
import 'package:fraudlens/screens/cards/cards_list_screen.dart';
import 'package:fraudlens/screens/chat/richie_chat_sheet.dart';
import 'package:fraudlens/screens/dashboard/dashboard_screen.dart';
import 'package:fraudlens/screens/transactions/transaction_detail_screen.dart';
import 'package:fraudlens/screens/transactions/transactions_list_screen.dart';
import 'package:fraudlens/services/alert_service.dart';
import 'package:fraudlens/services/auth_service.dart';
import 'package:fraudlens/services/card_service.dart';
import 'package:fraudlens/services/currency_service.dart';
import 'package:fraudlens/services/summary_service.dart';
import 'package:fraudlens/services/transaction_service.dart';
import 'package:fraudlens/widgets/investigation_card.dart';
import 'package:fraudlens/widgets/metric_card.dart';
import 'package:fraudlens/widgets/transaction_card.dart';

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
  final SummaryModel summary;
  _MockSummaryService(this.summary);

  @override
  Future<SummaryModel> getSummary({
    int? cardId,
    String? dateFrom,
    String? dateTo,
  }) async => summary;
}

class MockTransactionService extends TransactionService {
  final List<TransactionModel> mockTransactions;
  final int totalCount;

  MockTransactionService({
    required this.mockTransactions,
    this.totalCount = 120,
  });

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
    return PaginatedResponse<TransactionModel>(
      count: totalCount,
      next: page < (totalCount / 50).ceil() ? '${page + 1}' : null,
      previous: page > 1 ? '${page - 1}' : null,
      results: mockTransactions,
    );
  }
}

class MockCardService extends CardService {
  final List<CardModel> mockCards;
  MockCardService({this.mockCards = const []});

  @override
  Future<List<CardModel>> getAllCards() async => mockCards;

  @override
  Future<PaginatedResponse<CardModel>> getCards({int page = 1}) async {
    return PaginatedResponse<CardModel>(
      count: mockCards.length,
      next: null,
      previous: null,
      results: mockCards,
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

Widget createTestAppWithProviders({
  required Widget child,
  Size size = const Size(360, 640),
  CurrencyProvider? currencyProvider,
  TransactionService? transactionService,
  CardService? cardService,
  SummaryService? summaryService,
  AlertService? alertService,
  EdgeInsets viewInsets = EdgeInsets.zero,
  double textScale = 1.0,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(
        create: (_) => AuthProvider(authService: _MockAuthService()),
      ),
      ChangeNotifierProvider(
        create: (_) => DashboardProvider(
          summaryService:
              summaryService ??
              _MockSummaryService(
                SummaryModel(
                  totalSpend: 1200,
                  currency: 'INR',
                  transactionCount: 4,
                  alertsByStatus: AlertsByStatus(
                    open: 1,
                    inReview: 0,
                    resolved: 1,
                  ),
                  byCategory: [
                    CategorySpend(
                      category: 'food_dining',
                      total: 1200,
                      count: 4,
                    ),
                  ],
                  monthly: [
                    MonthlySpend(month: '2026-11', total: 1200, count: 4),
                  ],
                ),
              ),
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => TransactionProvider(
          transactionService:
              transactionService ??
              MockTransactionService(mockTransactions: []),
        ),
      ),
      ChangeNotifierProvider(
        create: (_) =>
            AlertProvider(alertService: alertService ?? _MockAlertService()),
      ),
      ChangeNotifierProvider(create: (_) => InvestigationProvider()),
      ChangeNotifierProvider(
        create: (_) =>
            CardProvider(cardService: cardService ?? MockCardService()),
      ),
      ChangeNotifierProvider(
        create: (_) => currencyProvider ?? CurrencyProvider(),
      ),
      ChangeNotifierProvider(create: (_) => ChatProvider()),
    ],
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          viewInsets: viewInsets,
          textScaler: TextScaler.linear(textScale),
        ),
        child: SizedBox(width: size.width, height: size.height, child: child),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Part 1 & 2: MetricCard & Home Overflow Verification Across Screen Sizes', () {
    testWidgets('Warmup font and surface bindings', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.darkTheme, home: const SizedBox()),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
    });

    final screenSizes = [
      const Size(320, 640),
      const Size(360, 640),
      const Size(390, 844),
      const Size(412, 915),
    ];

    for (final size in screenSizes) {
      testWidgets(
        'Metric cards grid renders without bottom overflow on ${size.width}px width',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final isWide = size.width >= 600;
          final childAspectRatio = isWide
              ? 1.6
              : (size.width < 360 ? 1.12 : 1.25);

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                body: SizedBox(
                  width: size.width,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: GridView.count(
                      crossAxisCount: isWide ? 4 : 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: childAspectRatio,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: const [
                        MetricCard(
                          title: 'Total Volume',
                          value: '\$14,840,000.00',
                          subtitle: 'All-time processed volume',
                          icon: Icons.payments_rounded,
                        ),
                        MetricCard(
                          title: 'Transactions',
                          value: '214,246',
                          subtitle: 'Monitored cards & points',
                          icon: Icons.receipt_long_rounded,
                        ),
                        MetricCard(
                          title: 'Open Alerts',
                          value: '707',
                          subtitle: 'Needs analyst review',
                          icon: Icons.warning_amber_rounded,
                        ),
                        MetricCard(
                          title: 'Resolved',
                          value: '1,429',
                          subtitle: 'Closed investigations',
                          icon: Icons.verified_user_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(find.text('Total Volume'), findsOneWidget);
        },
      );
    }

    testWidgets(
      'Home screen renders INR summary without double conversion or overflow on 320px + 1.25x font scale',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final currencyProvider = CurrencyProvider();
        await currencyProvider.initialize(syncNetwork: false);
        await currencyProvider.selectRegion('IN');

        final inrSummary = SummaryModel(
          totalSpend: 1500.0,
          currency: 'INR',
          transactionCount: 5,
          alertsByStatus: AlertsByStatus(open: 2, inReview: 0, resolved: 3),
          byCategory: [
            CategorySpend(category: 'food_dining', total: 1500.0, count: 5),
          ],
          monthly: [MonthlySpend(month: '2026-11', total: 1500.0, count: 5)],
        );

        await tester.pumpWidget(
          createTestAppWithProviders(
            size: const Size(320, 640),
            textScale: 1.25,
            currencyProvider: currencyProvider,
            summaryService: _MockSummaryService(inrSummary),
            child: const DashboardScreen(),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
        expect(find.text('2 payments need review'), findsOneWidget);
        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(find.text('Ask Richie'), findsOneWidget);
        // Should show exact ₹1,500.00 (NOT 1500 * 86.50 = ₹1,29,750.00)
        expect(find.text('₹1,500.00'), findsOneWidget);
      },
    );

    testWidgets(
      'Home screen hides calm status banner when openAlerts == 0 and keeps Ask Richie FAB without overflow on 320px',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final currencyProvider = CurrencyProvider();
        await currencyProvider.initialize(syncNetwork: false);
        await currencyProvider.selectRegion('IN');

        final cleanSummary = SummaryModel(
          totalSpend: 420.0,
          currency: 'INR',
          transactionCount: 2,
          alertsByStatus: AlertsByStatus(open: 0, inReview: 0, resolved: 1),
          byCategory: [
            CategorySpend(category: 'food_dining', total: 420.0, count: 2),
          ],
          monthly: [MonthlySpend(month: '2026-11', total: 420.0, count: 2)],
        );

        await tester.pumpWidget(
          createTestAppWithProviders(
            size: const Size(320, 640),
            textScale: 1.0,
            currencyProvider: currencyProvider,
            summaryService: _MockSummaryService(cleanSummary),
            child: const DashboardScreen(),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
        expect(find.text('All recent activity looks normal'), findsNothing);
        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(find.text('Ask Richie'), findsOneWidget);
        expect(find.text('₹420.00'), findsOneWidget);
      },
    );
  });

  group('Part 3: Activity Screen Responsiveness & Unobstructed Pagination', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets(
      'TransactionCard with long merchant and flagged status renders cleanly on 320px width',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final currencyProvider = CurrencyProvider();
        await currencyProvider.initialize(syncNetwork: false);

        final mockTxn = TransactionModel(
          id: 101,
          transRef: 'TXN-LONG-REF-998877665544',
          card: 42,
          cardLabel: 'Visa Platinum •• 4242',
          occurredAt: DateTime(2026, 11, 3, 14, 30),
          merchant: 'Global International Merchant Services & Transatlantic Logistics Corporation Limited',
          category: 'entertainment_ticketing',
          amount: 14840.50,
          source: 'simulated',
          hasAlert: true,
          currency: 'USD',
        );

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: currencyProvider,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 320,
                    child: TransactionCard(transaction: mockTxn),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('Needs review'), findsOneWidget);
        expect(
          find.text(
            'Global International Merchant Services & Transatlantic Logistics Corporation Limited',
          ),
          findsOneWidget,
        );
        expect(find.text(currencyProvider.format(14840.50)), findsOneWidget);
      },
    );

    testWidgets(
      'Activity screen has New transaction action in AppBar and unobstructed pagination controls',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final currencyProvider = CurrencyProvider();
        await currencyProvider.initialize(syncNetwork: false);

        final sampleTxn = TransactionModel(
          id: 1,
          transRef: 'TXN-001',
          card: 1,
          cardLabel: 'Debit Card •• 1234',
          occurredAt: DateTime.now(),
          merchant: 'Acme Supermarket',
          category: 'grocery_pos',
          amount: 54.20,
          source: 'notification',
          hasAlert: false,
          currency: 'INR',
        );

        final mockTxnService = MockTransactionService(
          mockTransactions: [sampleTxn],
          totalCount: 120,
        );

        await tester.pumpWidget(
          createTestAppWithProviders(
            size: const Size(360, 640),
            currencyProvider: currencyProvider,
            transactionService: mockTxnService,
            child: const TransactionsListScreen(),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
        expect(find.byTooltip('New transaction'), findsOneWidget);
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(find.text('Today'), findsOneWidget);
        expect(find.text('Prev'), findsOneWidget);
        expect(find.text('Next'), findsOneWidget);
        expect(find.text('Page 1 of 3'), findsNWidgets(2));
      },
    );
  });

  group('Part 4: Investigation Card, Accounts, Details & Richie Overflow Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets(
      'Investigation card with long analyst name, bullet, and timestamp wraps without overflow on 320px',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final currencyProvider = CurrencyProvider();
        await currencyProvider.initialize(syncNetwork: false);

        final mockInv = InvestigationModel(
          id: 501,
          alert: 707,
          analystName: 'Senior Lead Fraud Analyst Alexander Montgomery-Smith',
          verdict: 'confirmed_fraud',
          notes: 'Automated anomaly detected suspicious card velocity exceeding normal behavioral thresholds across multi-jurisdictional POS terminals.',
          createdAt: DateTime(2026, 11, 3, 15, 45),
          merchant:
              'Global Transatlantic International Electronics Corporation Ltd',
          amount: 45999.00,
          occurredAt: DateTime(2026, 11, 3, 14, 0),
        );

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: currencyProvider,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 320,
                    child: InvestigationCard(investigation: mockInv),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('Confirmed Fraud'), findsOneWidget);
        expect(find.text('Alert #707'), findsOneWidget);
      },
    );

    testWidgets(
      'Accounts screen renders linked cards and action Wrap without overflow on 320px width',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final currencyProvider = CurrencyProvider();
        await currencyProvider.initialize(syncNetwork: false);

        await tester.pumpWidget(
          createTestAppWithProviders(
            size: const Size(320, 640),
            textScale: 1.2,
            currencyProvider: currencyProvider,
            cardService: MockCardService(
              mockCards: [
                CardModel(id: 1, label: 'HDFC Bank Savings Account •• 9719'),
                CardModel(id: 2, label: 'Unregistered UPI Bank •• 0041'),
              ],
            ),
            child: const CardsListScreen(),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
        expect(find.text('HDFC Bank Savings Account •• 9719'), findsOneWidget);
        expect(find.text('Activity'), findsNWidgets(2));
        expect(find.text('Insights'), findsNWidgets(2));
      },
    );

    testWidgets(
      'AlertDetailScreen preserves INR amount and wraps USD conversion note cleanly on 320px',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final currencyProvider = CurrencyProvider();
        await currencyProvider.initialize(syncNetwork: false);
        await currencyProvider.selectRegion('IN');

        // Simulated USD alert -> converts USD 100 -> ₹8,650.00 and wraps rate cleanly
        final usdAlert = AlertModel(
          id: 99,
          score: 0.91,
          threshold: 0.65,
          reasons: [
            ShapReason(
              factor: 'amount',
              impact: 0.72,
              text: 'Spend is 3.5x higher than your usual average',
            ),
          ],
          status: 'open',
          createdAt: DateTime(2026, 11, 26, 12, 0),
          transaction: AlertTransaction(
            id: 50,
            card: 1,
            cardLabel: 'HDFC Bank A/c •• 9719',
            occurredAt: DateTime(2026, 11, 26, 11, 59),
            merchant: 'International Digital Goods Store',
            category: 'shopping_net',
            amount: 100.0,
            source: 'simulated',
            currency: 'USD',
          ),
        );

        await tester.pumpWidget(
          createTestAppWithProviders(
            size: const Size(320, 640),
            currencyProvider: currencyProvider,
            child: AlertDetailScreen(alert: usdAlert),
          ),
        );

        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('₹8,650.00'), findsOneWidget);
        expect(find.text('Yes, this was me'), findsOneWidget);
        expect(find.text('No, report as fraud'), findsOneWidget);
      },
    );

    testWidgets(
      'TransactionDetailScreen preserves exact INR UPI amount without double conversion on 320px',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final currencyProvider = CurrencyProvider();
        await currencyProvider.initialize(syncNetwork: false);
        await currencyProvider.selectRegion('IN');

        final upiTxn = TransactionModel(
          id: 77,
          transRef: 'UPI-778899',
          card: 1,
          cardLabel: 'HDFC •• 9719',
          occurredAt: DateTime(2026, 11, 26, 15, 0),
          merchant: 'Starbucks India',
          category: 'food_dining',
          amount: 450.0,
          source: 'notification',
          hasAlert: false,
          currency: 'INR',
        );

        await tester.pumpWidget(
          createTestAppWithProviders(
            size: const Size(320, 640),
            currencyProvider: currencyProvider,
            child: TransactionDetailScreen(transaction: upiTxn),
          ),
        );

        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('₹450.00'), findsOneWidget);
        expect(find.text('Ask Richie about this payment'), findsOneWidget);
      },
    );

    testWidgets(
      'RichieChatSheet avoids keyboard overflow and uses clean Richie branding',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          createTestAppWithProviders(
            size: const Size(360, 640),
            viewInsets: const EdgeInsets.only(bottom: 300),
            child: const Scaffold(body: RichieChatSheet()),
          ),
        );

        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('Richie'), findsOneWidget);
        expect(find.text('AI ASSISTANT'), findsNothing);
        expect(find.text('FraudLens Security Copilot'), findsNothing);
      },
    );
  });

  group('Part 5: Automatic Regional Currency Service & Provider Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('CurrencyService maps locales to appropriate currency codes', () {
      expect(
        CurrencyService.detectCurrencyFromLocale(const Locale('en', 'IN')),
        'INR',
      );
      expect(
        CurrencyService.detectCurrencyFromLocale(const Locale('hi', 'IN')),
        'INR',
      );
      expect(
        CurrencyService.detectCurrencyFromLocale(const Locale('en', 'US')),
        'USD',
      );
      expect(
        CurrencyService.detectCurrencyFromLocale(const Locale('en', 'GB')),
        'GBP',
      );
      expect(
        CurrencyService.detectCurrencyFromLocale(const Locale('de', 'DE')),
        'EUR',
      );
      expect(
        CurrencyService.detectCurrencyFromLocale(const Locale('fr', 'FR')),
        'EUR',
      );
      expect(
        CurrencyService.detectCurrencyFromLocale(const Locale('es', 'ES')),
        'EUR',
      );
      expect(
        CurrencyService.detectCurrencyFromLocale(const Locale('ja', 'JP')),
        'JPY',
      );
      expect(
        CurrencyService.detectCurrencyFromLocale(const Locale('xx', 'ZZ')),
        'USD',
      );
    });

    test(
      'CurrencyService formats INR with correct Indian numbering and symbol',
      () {
        final formatted = CurrencyService.formatAmount(
          1484000.0,
          currencyCode: 'INR',
          isSourceUsd: false,
        );
        expect(formatted, contains('₹'));
        expect(formatted, contains('14,84,000'));
      },
    );

    test('CurrencyService formats USD with standard commas', () {
      final formatted = CurrencyService.formatAmount(
        14840.50,
        currencyCode: 'USD',
        isSourceUsd: false,
      );
      expect(formatted, contains('\$'));
      expect(formatted, contains('14,840.50'));
    });

    test('CurrencyService performs accurate dynamic currency conversion from USD base', () {
      expect(CurrencyService.convertFromUsd(100.0, 'INR'), 8650.0);
      expect(CurrencyService.convertFromUsd(100.0, 'EUR'), 92.0);
      expect(CurrencyService.convertFromUsd(100.0, 'GBP'), 79.0);
      expect(CurrencyService.convertFromUsd(100.0, 'USD'), 100.0);
    });

    test('CurrencyProvider auto mode respects detected currency and manual mode allows override', () async {
      final provider = CurrencyProvider();
      await provider.initialize(syncNetwork: false);

      expect(provider.mode, CurrencyMode.auto);
      expect(provider.isAuto, isTrue);

      await provider.setManualCurrency('EUR');
      expect(provider.mode, CurrencyMode.manual);
      expect(provider.activeCurrency, 'EUR');
      expect(provider.isAuto, isFalse);

      final eurFormatted = provider.format(100.0);
      expect(eurFormatted, contains('€'));
      expect(eurFormatted, contains('92.00'));

      await provider.setMode(CurrencyMode.auto);
      expect(provider.mode, CurrencyMode.auto);
      expect(provider.isAuto, isTrue);
    });

    test('CurrencyProvider persists preferences across instances', () async {
      final provider1 = CurrencyProvider();
      await provider1.initialize(syncNetwork: false);
      await provider1.setManualCurrency('GBP');

      final provider2 = CurrencyProvider();
      await provider2.initialize(syncNetwork: false);
      expect(provider2.mode, CurrencyMode.manual);
      expect(provider2.activeCurrency, 'GBP');
      expect(provider2.format(100.0), contains('£79.00'));
    });

    test(
      'CurrencyProvider selectRegion sets region and matching currency',
      () async {
        final provider = CurrencyProvider();
        await provider.initialize(syncNetwork: false);

        await provider.selectRegion('IN');
        expect(provider.activeRegionCode, 'IN');
        expect(provider.activeCurrency, 'INR');
        expect(provider.activeCurrencyInfo.symbol, '₹');

        await provider.selectRegion('GB');
        expect(provider.activeRegionCode, 'GB');
        expect(provider.activeCurrency, 'GBP');
        expect(provider.activeCurrencyInfo.symbol, '£');
      },
    );
  });
}
