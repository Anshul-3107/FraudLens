import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fraudlens/config/app_theme.dart';
import 'package:fraudlens/models/card.dart';
import 'package:fraudlens/models/investigation.dart';
import 'package:fraudlens/models/paginated_response.dart';
import 'package:fraudlens/models/transaction.dart';
import 'package:fraudlens/providers/alert_provider.dart';
import 'package:fraudlens/providers/auth_provider.dart';
import 'package:fraudlens/providers/card_provider.dart';
import 'package:fraudlens/providers/currency_provider.dart';
import 'package:fraudlens/providers/dashboard_provider.dart';
import 'package:fraudlens/providers/investigation_provider.dart';
import 'package:fraudlens/providers/theme_provider.dart';
import 'package:fraudlens/providers/transaction_provider.dart';
import 'package:fraudlens/screens/transactions/transactions_list_screen.dart';
import 'package:fraudlens/services/card_service.dart';
import 'package:fraudlens/services/currency_service.dart';
import 'package:fraudlens/services/transaction_service.dart';
import 'package:fraudlens/widgets/investigation_card.dart';
import 'package:fraudlens/widgets/metric_card.dart';
import 'package:fraudlens/widgets/transaction_card.dart';

// Mock TransactionService returning fast controlled pagination data without network requests
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

// Mock CardService returning controlled cards without network requests
class MockCardService extends CardService {
  @override
  Future<List<CardModel>> getAllCards() async => [];

  @override
  Future<PaginatedResponse<CardModel>> getCards({int page = 1}) async {
    return PaginatedResponse<CardModel>(
      count: 0,
      next: null,
      previous: null,
      results: [],
    );
  }
}

Widget createTestAppWithProviders({
  required Widget child,
  Size size = const Size(360, 640),
  CurrencyProvider? currencyProvider,
  TransactionService? transactionService,
  CardService? cardService,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => DashboardProvider()),
      ChangeNotifierProvider(
        create: (_) => TransactionProvider(
          transactionService:
              transactionService ??
              MockTransactionService(mockTransactions: []),
        ),
      ),
      ChangeNotifierProvider(create: (_) => AlertProvider()),
      ChangeNotifierProvider(create: (_) => InvestigationProvider()),
      ChangeNotifierProvider(
        create: (_) =>
            CardProvider(cardService: cardService ?? MockCardService()),
      ),
      ChangeNotifierProvider(
        create: (_) => currencyProvider ?? CurrencyProvider(),
      ),
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
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Part 1 & 2: MetricCard & Dashboard Overflow Verification Across Screen Sizes', () {
    final screenSizes = [
      const Size(320, 640), // Compact / Small Android
      const Size(360, 640), // Standard Android
      const Size(390, 844), // Modern Standard
      const Size(412, 915), // Large Android (e.g. Vivo, Pixel, Galaxy)
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
                      children: [
                        const MetricCard(
                          title: 'Total Volume',
                          value: '\$14,840,000.00',
                          subtitle: 'All-time processed volume',
                          icon: Icons.payments_rounded,
                        ),
                        const MetricCard(
                          title: 'Transactions',
                          value: '214,246',
                          subtitle: 'Monitored cards & points',
                          icon: Icons.receipt_long_rounded,
                        ),
                        const MetricCard(
                          title: 'Open Alerts',
                          value: '707',
                          subtitle: 'Needs analyst review',
                          icon: Icons.warning_amber_rounded,
                        ),
                        const MetricCard(
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

          // Must not trigger any bottom overflow exception
          expect(tester.takeException(), isNull);
          expect(find.text('Total Volume'), findsOneWidget);
          expect(find.text('Transactions'), findsOneWidget);
          expect(find.text('Open Alerts'), findsOneWidget);
          expect(find.text('Resolved'), findsOneWidget);
        },
      );
    }

    testWidgets(
      'MetricCard with extreme currency value fits and scales using FittedBox',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: Center(
                child: SizedBox(
                  width: 140,
                  height: 120,
                  child: MetricCard(
                    title: 'Total Volume',
                    value: '₹12,45,67,89,000.00',
                    subtitle: 'Indian Rupee volume',
                    icon: Icons.account_balance_wallet_rounded,
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('₹12,45,67,89,000.00'), findsOneWidget);
      },
    );
  });

  group('Part 3: Transactions Screen Responsiveness & FAB Spacing', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets(
      'Transaction list item with long merchant and flagged badge renders without overflow on 320px',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final currencyProvider = CurrencyProvider();
        await currencyProvider.initialize();

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

        // Must render cleanly with zero RenderFlex overflow on 320px width
        expect(tester.takeException(), isNull);
        expect(find.text('NEEDS ACTION'), findsOneWidget);
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
      'New Transaction Action button is present in AppBar and FAB is elevated above pagination',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final currencyProvider = CurrencyProvider();
        await currencyProvider.initialize();

        final sampleTxn = TransactionModel(
          id: 1,
          transRef: 'TXN-001',
          card: 1,
          cardLabel: 'Debit Card •• 1234',
          occurredAt: DateTime(2026, 11, 3, 10, 0),
          merchant: 'Acme Supermarket',
          category: 'groceries',
          amount: 54.20,
          source: 'simulated',
          hasAlert: false,
        );

        final mockTxnService = MockTransactionService(
          mockTransactions: [sampleTxn],
          totalCount: 120, // 3 pages total (totalPages > 1)
        );

        await tester.pumpWidget(
          createTestAppWithProviders(
            size: const Size(360, 640),
            currencyProvider: currencyProvider,
            transactionService: mockTxnService,
            child: const TransactionsListScreen(),
          ),
        );

        // Run postFrameCallback to complete initialization with mock data
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // 1. Verify AppBar contains New Transaction action button
        expect(find.byTooltip('New Transaction'), findsOneWidget);

        // 2. Verify FloatingActionButton exists
        expect(find.byType(FloatingActionButton), findsOneWidget);

        // 3. Verify pagination controls are visible and accessible
        expect(find.text('Prev'), findsOneWidget);
        expect(find.text('Next'), findsOneWidget);
        expect(find.text('Page 1 of 3'), findsNWidgets(2));

        // 4. Verify FAB has bottom margin so it does NOT obscure pagination controls
        final fabPadding = tester.widget<Padding>(
          find
              .ancestor(
                of: find.byType(FloatingActionButton),
                matching: find.byType(Padding),
              )
              .first,
        );
        expect((fabPadding.padding as EdgeInsets).bottom, 52);

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Part 4: Investigation History Card Overflow Fixes', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets(
      'Investigation card with long analyst name, bullet, and timestamp wraps without overflow on 320px',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final currencyProvider = CurrencyProvider();
        await currencyProvider.initialize();

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

        // Must render cleanly with zero RenderFlex overflow on 320px width
        expect(tester.takeException(), isNull);
        expect(find.text('Confirmed Fraud'), findsOneWidget);
        expect(find.text('Alert #707'), findsOneWidget);
        expect(
          find.text(
            'Global Transatlantic International Electronics Corporation Ltd',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'Analyst: Senior Lead Fraud Analyst Alexander Montgomery-Smith',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'Automated anomaly detected suspicious card velocity exceeding normal behavioral thresholds across multi-jurisdictional POS terminals.',
          ),
          findsOneWidget,
        );
        expect(find.text(currencyProvider.format(45999.00)), findsOneWidget);
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
      ); // Fallback
    });

    test(
      'CurrencyService automatically detects INR when system is in Indian Standard Timezone (IST)',
      () {
        // If system local time is in India (UTC +5:30), detectCurrencyFromLocale() returns INR
        if (DateTime.now().timeZoneOffset.inMinutes == 330 ||
            DateTime.now().timeZoneName.toUpperCase().contains('IST')) {
          expect(CurrencyService.detectCurrencyFromLocale(), 'INR');
        }
      },
    );

    test(
      'CurrencyService formats INR with correct Indian numbering and symbol',
      () {
        final formatted = CurrencyService.formatAmount(
          1484000.0,
          currencyCode: 'INR',
          isSourceUsd: false,
        );
        expect(formatted, contains('₹'));
        // In Indian numbering, 14,84,000.00
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
      // USD 100 at 86.50 rate = INR 8650
      final inrVal = CurrencyService.convertFromUsd(100.0, 'INR');
      expect(inrVal, 8650.0);

      // USD 100 at 0.92 rate = EUR 92
      final eurVal = CurrencyService.convertFromUsd(100.0, 'EUR');
      expect(eurVal, 92.0);

      // USD 100 at 0.79 rate = GBP 79
      final gbpVal = CurrencyService.convertFromUsd(100.0, 'GBP');
      expect(gbpVal, 79.0);

      // USD base remains 1.0
      final usdVal = CurrencyService.convertFromUsd(100.0, 'USD');
      expect(usdVal, 100.0);
    });

    test('CurrencyService compact format produces readable labels', () {
      final compactUsd = CurrencyService.formatCompactAmount(
        1500000.0,
        currencyCode: 'USD',
        isSourceUsd: false,
      );
      expect(compactUsd, contains('\$'));
      expect(compactUsd, contains('1.5M'));

      final compactInr = CurrencyService.formatCompactAmount(
        10000000.0,
        currencyCode: 'INR',
        isSourceUsd: false,
      );
      expect(compactInr, contains('₹'));
    });

    test('CurrencyProvider auto mode respects detected currency and manual mode allows override', () async {
      final provider = CurrencyProvider();
      await provider.initialize();

      // Default is auto mode
      expect(provider.mode, CurrencyMode.auto);
      expect(provider.isAuto, isTrue);

      // Set manual override to EUR
      await provider.setManualCurrency('EUR');
      expect(provider.mode, CurrencyMode.manual);
      expect(provider.activeCurrency, 'EUR');
      expect(provider.isAuto, isFalse);

      // Format USD 100 in manual EUR
      final eurFormatted = provider.format(100.0);
      expect(eurFormatted, contains('€'));
      expect(eurFormatted, contains('92.00'));

      // Return to auto mode
      await provider.setMode(CurrencyMode.auto);
      expect(provider.mode, CurrencyMode.auto);
      expect(provider.isAuto, isTrue);
    });

    test('CurrencyProvider persists preferences across instances', () async {
      final provider1 = CurrencyProvider();
      await provider1.initialize();
      await provider1.setManualCurrency('GBP');

      // Second instance should restore 'manual' and 'GBP'
      final provider2 = CurrencyProvider();
      await provider2.initialize();
      expect(provider2.mode, CurrencyMode.manual);
      expect(provider2.activeCurrency, 'GBP');
      expect(provider2.format(100.0), contains('£79.00'));
    });

    test('CurrencyProvider selectRegion sets region and matching currency', () async {
      final provider = CurrencyProvider();
      await provider.initialize();

      await provider.selectRegion('IN');
      expect(provider.activeRegionCode, 'IN');
      expect(provider.activeCurrency, 'INR');
      expect(provider.activeCurrencyInfo.symbol, '₹');

      await provider.selectRegion('GB');
      expect(provider.activeRegionCode, 'GB');
      expect(provider.activeCurrency, 'GBP');
      expect(provider.activeCurrencyInfo.symbol, '£');
    });
  });
}
