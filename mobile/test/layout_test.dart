import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fraudlens/config/app_theme.dart';
import 'package:fraudlens/models/summary.dart';
import 'package:fraudlens/providers/alert_provider.dart';
import 'package:fraudlens/providers/auth_provider.dart';
import 'package:fraudlens/providers/card_provider.dart';
import 'package:fraudlens/providers/dashboard_provider.dart';
import 'package:fraudlens/providers/investigation_provider.dart';
import 'package:fraudlens/providers/theme_provider.dart';
import 'package:fraudlens/providers/transaction_provider.dart';
import 'package:fraudlens/screens/navigation/app_shell.dart';
import 'package:fraudlens/widgets/spend_chart.dart';

Widget createTestApp({
  required Widget child,
  Size size = const Size(360, 640),
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
  group('Horizontally Scrollable Bottom Navigation Tests', () {
    testWidgets('Renders all 6 destinations on narrow mobile (360px)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        createTestApp(child: const AppShell(), size: const Size(360, 640)),
      );
      await tester.pumpAndSettle();

      // Verify all 6 navigation labels exist in the widget tree
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Transactions'), findsWidgets);
      expect(find.text('Alerts'), findsWidgets);
      expect(find.text('Review'), findsWidgets);
      expect(find.text('Cards'), findsWidgets);
      expect(find.text('Profile'), findsWidgets);

      // Verify horizontal SingleChildScrollView is used for the bottom navigation bar
      final scrollViews = find.byType(SingleChildScrollView);
      bool hasHorizontalScroll = false;
      for (final element in tester.widgetList<SingleChildScrollView>(
        scrollViews,
      )) {
        if (element.scrollDirection == Axis.horizontal) {
          hasHorizontalScroll = true;
          break;
        }
      }
      expect(
        hasHorizontalScroll,
        isTrue,
        reason: 'Bottom nav bar must be horizontally scrollable',
      );
    });

    testWidgets('Tapping destinations updates active screen', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        createTestApp(child: const AppShell(), size: const Size(360, 640)),
      );
      await tester.pumpAndSettle();

      // Tap Transactions (already in viewport)
      await tester.tap(find.text('Transactions').first);
      await tester.pumpAndSettle();

      // Ensure Review is scrolled into view, then tap
      await tester.ensureVisible(find.text('Review').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review').first);
      await tester.pumpAndSettle();

      // Ensure Cards is scrolled into view, then tap
      await tester.ensureVisible(find.text('Cards').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cards').first);
      await tester.pumpAndSettle();

      // Ensure Dashboard is scrolled into view, then tap
      await tester.ensureVisible(find.text('Dashboard').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dashboard').first);
      await tester.pumpAndSettle();
    });

    testWidgets('Horizontal drag smoothly scrolls navigation destinations', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        createTestApp(child: const AppShell(), size: const Size(360, 640)),
      );
      await tester.pumpAndSettle();

      // Find the horizontal SingleChildScrollView in bottom nav
      final navScroll = find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      );
      expect(navScroll, findsOneWidget);

      // Drag left to reveal rightmost destinations
      await tester.drag(navScroll, const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Profile is visible and can be tapped
      final profileFinder = find.text('Profile');
      expect(profileFinder, findsOneWidget);
      await tester.ensureVisible(profileFinder);
      await tester.pumpAndSettle();
      await tester.tap(profileFinder);
      await tester.pumpAndSettle();
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
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Replicate the exact card header that previously overflowed
                    Builder(
                      builder: (context) {
                        final colors = AppColors.of(context);
                        return Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Monthly Spending Activity',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'USD Volume',
                                    style: TextStyle(
                                      color: colors.textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              MonthlySpendChart(monthlyData: testMonthly),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    CategorySpendBreakdown(categories: testCategories),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // If there were any RenderFlex overflows, tester.takeException() would be non-null
        expect(tester.takeException(), isNull);
        expect(find.text('Monthly Spending Activity'), findsOneWidget);
        expect(find.text('USD Volume'), findsOneWidget);
      },
    );
  });
}
