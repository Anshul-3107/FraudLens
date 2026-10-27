import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/card.dart';
import '../../providers/auth_provider.dart';
import '../../providers/card_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/spend_chart.dart';
import '../transactions/create_transaction_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int tabIndex)? onNavigateTab;

  const DashboardScreen({super.key, this.onNavigateTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadSummary();
      context.read<CardProvider>().loadCards();
    });
  }

  void _showFilterModal() {
    final colors = AppColors.of(context);
    final dashProvider = context.read<DashboardProvider>();
    final cardProvider = context.read<CardProvider>();
    CardModel? tempCard = dashProvider.selectedCard;
    final dateFromController = TextEditingController(
      text: dashProvider.dateFrom ?? '',
    );
    final dateToController = TextEditingController(
      text: dashProvider.dateTo ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Dashboard Metrics',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 20,
                          color: colors.textSecondary,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Card Selector
                  DropdownButtonFormField<CardModel?>(
                    initialValue: tempCard,
                    decoration: const InputDecoration(
                      labelText: 'Filter by Card',
                      prefixIcon: Icon(Icons.credit_card_rounded, size: 20),
                    ),
                    items: [
                      const DropdownMenuItem<CardModel?>(
                        value: null,
                        child: Text('All Cards (Portfolio-wide)'),
                      ),
                      ...cardProvider.cards.map(
                        (c) => DropdownMenuItem<CardModel?>(
                          value: c,
                          child: Text(c.label),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setModalState(() => tempCard = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Date From
                  TextField(
                    controller: dateFromController,
                    decoration: const InputDecoration(
                      labelText: 'Date From (YYYY-MM-DD)',
                      hintText: '2020-01-01',
                      prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Date To
                  TextField(
                    controller: dateToController,
                    decoration: const InputDecoration(
                      labelText: 'Date To (YYYY-MM-DD)',
                      hintText: '2021-12-31',
                      prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            dashProvider.clearFilters();
                            Navigator.pop(ctx);
                          },
                          child: const Text('Reset All'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            dashProvider.setCardFilter(tempCard);
                            dashProvider.setDateRange(
                              dateFromController.text.trim().isEmpty
                                  ? null
                                  : dateFromController.text.trim(),
                              dateToController.text.trim().isEmpty
                                  ? null
                                  : dateToController.text.trim(),
                            );
                            Navigator.pop(ctx);
                          },
                          child: const Text('Apply Filter'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final authProvider = context.watch<AuthProvider>();
    final dashProvider = context.watch<DashboardProvider>();
    final summary = dashProvider.summary;

    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    );
    final countFormat = NumberFormat.decimalPattern();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Icon(
                Icons.shield_outlined,
                color: colors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'FraudLens Overview',
                    style: TextStyle(fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (authProvider.user != null)
                    Text(
                      'Analyst: ${authProvider.user!.username}${authProvider.user!.isStaff ? " (Staff)" : ""}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textMuted,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: dashProvider.hasActiveFilters,
              backgroundColor: colors.primary,
              child: const Icon(Icons.filter_list_rounded),
            ),
            tooltip: 'Filter Metrics',
            onPressed: _showFilterModal,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => dashProvider.loadSummary(),
          ),
        ],
      ),
      body: dashProvider.isLoading && summary == null
          ? const FintechLoadingIndicator(label: 'Loading financial metrics...')
          : dashProvider.errorMessage != null && summary == null
          ? ErrorView(
              message: dashProvider.errorMessage!,
              onRetry: () => dashProvider.loadSummary(),
            )
          : RefreshIndicator(
              onRefresh: () => dashProvider.loadSummary(),
              color: colors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Active Filter Chips
                    if (dashProvider.hasActiveFilters) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: colors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.filter_alt_outlined,
                              size: 16,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Filtered by: '
                                '${dashProvider.selectedCard != null ? dashProvider.selectedCard!.label : ""}'
                                '${dashProvider.dateFrom != null ? " from ${dashProvider.dateFrom}" : ""}'
                                '${dashProvider.dateTo != null ? " to ${dashProvider.dateTo}" : ""}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => dashProvider.clearFilters(),
                              child: Icon(
                                Icons.clear,
                                size: 16,
                                color: colors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Key Metrics Grid
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 600;
                        final crossAxisCount = isWide ? 4 : 2;

                        return GridView.count(
                          crossAxisCount: crossAxisCount,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: isWide ? 1.6 : 1.35,
                          children: [
                            MetricCard(
                              title: 'Total Volume',
                              value: currencyFormat.format(
                                summary?.totalSpend ?? 0,
                              ),
                              subtitle: 'Aggregate transaction spend',
                              icon: Icons.payments_outlined,
                              iconColor: colors.primary,
                            ),
                            MetricCard(
                              title: 'Transactions',
                              value: countFormat.format(
                                summary?.transactionCount ?? 0,
                              ),
                              subtitle: 'Processed records',
                              icon: Icons.receipt_long_outlined,
                              iconColor: colors.textSecondary,
                              onTap: () => widget.onNavigateTab?.call(1),
                            ),
                            MetricCard(
                              title: 'Open Alerts',
                              value: countFormat.format(
                                summary?.alertsByStatus.open ?? 0,
                              ),
                              subtitle: 'Requiring analyst review',
                              icon: Icons.warning_amber_rounded,
                              iconColor: colors.riskCritical,
                              iconBg: colors.riskCriticalBg,
                              onTap: () => widget.onNavigateTab?.call(2),
                            ),
                            MetricCard(
                              title: 'Resolved',
                              value: countFormat.format(
                                summary?.alertsByStatus.resolved ?? 0,
                              ),
                              subtitle:
                                  '${summary?.alertsByStatus.inReview ?? 0} in review',
                              icon: Icons.verified_user_outlined,
                              iconColor: colors.riskLow,
                              iconBg: colors.riskLowBg,
                              onTap: () => widget.onNavigateTab?.call(2),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Action Quick Bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: colors.borderSubtle,
                          width: 1,
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 320;
                          if (isNarrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Live ML Transaction Scoring',
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Test real-time Isolation Forest + XGBoost inference',
                                  style: TextStyle(
                                    color: colors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const CreateTransactionScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.bolt_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Score Transaction'),
                                ),
                              ],
                            );
                          }
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Live ML Transaction Scoring',
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Test real-time Isolation Forest + XGBoost inference',
                                      style: TextStyle(
                                        color: colors.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const CreateTransactionScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.bolt_rounded, size: 16),
                                label: const Text('Score Transaction'),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Monthly Spending Trends Chart Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: colors.borderSubtle,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Monthly Spending Activity',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 14,
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
                          MonthlySpendChart(
                            monthlyData: summary?.monthly ?? [],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Category Breakdown Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: colors.borderSubtle,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Top Spending Categories',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Transaction distribution across merchant verticals',
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 16),
                          CategorySpendBreakdown(
                            categories: summary?.byCategory ?? [],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}
