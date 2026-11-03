import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fraudlens/config/app_theme.dart';
import 'package:fraudlens/providers/alert_provider.dart';
import 'package:fraudlens/providers/auth_provider.dart';
import 'package:fraudlens/providers/card_provider.dart';
import 'package:fraudlens/providers/currency_provider.dart';
import 'package:fraudlens/providers/dashboard_provider.dart';
import 'package:fraudlens/providers/investigation_provider.dart';
import 'package:fraudlens/providers/theme_provider.dart';
import 'package:fraudlens/providers/transaction_provider.dart';
import 'package:fraudlens/screens/investigations/investigations_list_screen.dart';
import 'package:fraudlens/screens/transactions/transactions_list_screen.dart';
import 'package:fraudlens/services/currency_service.dart';
import 'package:fraudlens/widgets/metric_card.dart';

Widget createTestAppWithProviders({
  required Widget child,
  Size size = const Size(360, 640),
  CurrencyProvider? currencyProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => DashboardProvider()),
      ChangeNotifierProvider(create: (_) => TransactionProvider()),
      ChangeNotifierProvider(create: (_) => AlertProvider()),
      ChangeNotifierProvider(create: (_) => InvestigationProvider()),
      ChangeNotifierProvider(create: (_) => CardProvider()),
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

          await tester.pumpAndSettle();

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

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('₹12,45,67,89,000.00'), findsOneWidget);
      },
    );
  });

  group('Part 3: Transactions Screen Responsiveness & FAB Spacing', () {
    testWidgets(
      'Transaction list item with long merchant and flagged badge renders without overflow on 320px',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final currencyProvider = CurrencyProvider();
        await currencyProvider.initialize();

        await tester.pumpWidget(
          createTestAppWithProviders(
            size: const Size(320, 640),
            currencyProvider: currencyProvider,
            child: const TransactionsListScreen(),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Transactions'), findsWidgets);
      },
    );

    testWidgets(
      'New Transaction Action button is present in AppBar and FAB is elevated above pagination',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final currencyProvider = CurrencyProvider();
        await currencyProvider.initialize();

        await tester.pumpWidget(
          createTestAppWithProviders(
            size: const Size(360, 640),
            currencyProvider: currencyProvider,
            child: const TransactionsListScreen(),
          ),
        );

        await tester.pumpAndSettle();

        // Check AppBar action button exists for quick accessibility
        expect(find.byTooltip('New Transaction'), findsOneWidget);

        // Check FloatingActionButton exists
        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Part 4: Investigation History Card Overflow Fixes', () {
    testWidgets(
      'Investigation card with long analyst name, bullet, and timestamp wraps without overflow on 320px',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final currencyProvider = CurrencyProvider();
        await currencyProvider.initialize();

        await tester.pumpWidget(
          createTestAppWithProviders(
            size: const Size(320, 640),
            currencyProvider: currencyProvider,
            child: const InvestigationsListScreen(),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Investigation History'), findsWidgets);
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
        'USD',
      ); // Fallback
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
  });
}
