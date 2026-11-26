import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/card.dart';
import '../../providers/auth_provider.dart';
import '../../providers/card_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/api_client.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/spend_chart.dart';
import '../chat/richie_chat_sheet.dart';
import '../profile/profile_screen.dart';

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
              border: Border.all(color: colors.border),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Filter Overview',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                          ),
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
                  const SizedBox(height: 14),

                  DropdownButtonFormField<CardModel?>(
                    isExpanded: true,
                    initialValue: tempCard,
                    decoration: const InputDecoration(
                      labelText: 'Account / Card',
                      prefixIcon: Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 20,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<CardModel?>(
                        value: null,
                        child: Text(
                          'All Accounts',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ...cardProvider.cards.map(
                        (c) => DropdownMenuItem<CardModel?>(
                          value: c,
                          child: Text(c.label, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (val) => setModalState(() => tempCard = val),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: dateFromController,
                    decoration: const InputDecoration(
                      labelText: 'From date (YYYY-MM-DD)',
                      hintText: '2026-01-01',
                      prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: dateToController,
                    decoration: const InputDecoration(
                      labelText: 'To date (YYYY-MM-DD)',
                      hintText: '2026-12-31',
                      prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
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
                          child: const Text('Reset'),
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
                          child: const Text('Apply'),
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

  Widget _buildStatTile({
    required AppColors colors,
    required String label,
    required String value,
    required Color dotColor,
    VoidCallback? onTap,
    Color? valueColor,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? colors.textPrimary,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    fontFeatures: AppTheme.tabularFigures,
                  ),
                  maxLines: 1,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final dashProvider = context.watch<DashboardProvider>();
    final currencyProvider = context.watch<CurrencyProvider>();
    final authProvider = context.watch<AuthProvider>();
    final summary = dashProvider.summary;
    final user = authProvider.user;

    final countFormat = NumberFormat.decimalPattern();
    final openAlerts = summary?.alertsByStatus.open ?? 0;
    final inReviewAlerts = summary?.alertsByStatus.inReview ?? 0;
    final resolvedAlerts = summary?.alertsByStatus.resolved ?? 0;
    final txnCount = summary?.transactionCount ?? 0;

    final userInitial = (user?.username.isNotEmpty == true)
        ? user!.username.substring(0, 1).toUpperCase()
        : 'U';

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Flexible(
              child: Text(
                user?.username.isNotEmpty == true
                    ? 'Hi, ${user!.username}'
                    : 'FraudLens',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: dashProvider.hasActiveFilters,
              backgroundColor: colors.primary,
              child: const Icon(Icons.tune_rounded),
            ),
            tooltip: 'Filter',
            onPressed: _showFilterModal,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => dashProvider.loadSummary(),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
              borderRadius: BorderRadius.circular(18),
              child: Semantics(
                label: 'Account & Settings',
                button: true,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: colors.primaryBg,
                  backgroundImage:
                      (user?.avatarUrl != null &&
                          user!.avatarUrl!.trim().isNotEmpty)
                      ? NetworkImage(
                          user.avatarUrl!,
                          headers: ApiClient.instance.authHeaders,
                        )
                      : null,
                  onBackgroundImageError:
                      (user?.avatarUrl != null &&
                          user!.avatarUrl!.trim().isNotEmpty)
                      ? (_, _) {}
                      : null,
                  child:
                      (user?.avatarUrl == null ||
                          user!.avatarUrl!.trim().isEmpty)
                      ? Text(
                          userInitial,
                          style: TextStyle(
                            color: colors.isDark
                                ? colors.tealLight
                                : colors.tealPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
      body: dashProvider.isLoading && summary == null
          ? const FintechLoadingIndicator(label: 'Loading overview...')
          : dashProvider.errorMessage != null && summary == null
          ? ErrorView(
              message: dashProvider.errorMessage!,
              onRetry: () => dashProvider.loadSummary(),
            )
          : RefreshIndicator(
              onRefresh: () => dashProvider.loadSummary(),
              color: colors.primary,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Active Filter Strip
                        if (dashProvider.hasActiveFilters) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: colors.surfaceMuted,
                              borderRadius: BorderRadius.circular(10),
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
                                    'Filtered: '
                                    '${dashProvider.selectedCard != null ? dashProvider.selectedCard!.label : "All accounts"}'
                                    '${dashProvider.dateFrom != null ? " · from ${dashProvider.dateFrom}" : ""}'
                                    '${dashProvider.dateTo != null ? " · to ${dashProvider.dateTo}" : ""}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => dashProvider.clearFilters(),
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: colors.textMuted,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 28,
                                    minHeight: 28,
                                  ),
                                  tooltip: 'Clear filters',
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Conditional Alert Banner (ONLY shown when open alerts exist)
                        if (openAlerts > 0) ...[
                          Material(
                            color: colors.riskCriticalBg,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: () => widget.onNavigateTab?.call(2),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: colors.riskCritical.withValues(
                                      alpha: 0.25,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: colors.riskCritical.withValues(
                                          alpha: 0.14,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.priority_high_rounded,
                                        size: 18,
                                        color: colors.riskCritical,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$openAlerts ${openAlerts == 1 ? 'payment needs' : 'payments need'} review',
                                            style: TextStyle(
                                              color: colors.riskCritical,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            'Confirm or report unusual charges',
                                            style: TextStyle(
                                              color: colors.textSecondary,
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 20,
                                      color: colors.riskCritical,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Hero Spending Summary Card
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Total spending',
                                      style: TextStyle(
                                        color: colors.textSecondary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.primaryBg,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      currencyProvider.activeCurrency,
                                      style: TextStyle(
                                        color: colors.isDark
                                            ? colors.tealLight
                                            : colors.tealPrimary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  currencyProvider.format(
                                    summary?.totalSpend ?? 0,
                                    isSourceUsd: summary?.isSourceUsd ?? false,
                                  ),
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.8,
                                    fontFeatures: AppTheme.tabularFigures,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                              if ((summary?.isSourceUsd ?? false) &&
                                  currencyProvider.isConvertedFromUsd) ...[
                                const SizedBox(height: 3),
                                Text(
                                  'Converted from \$${NumberFormat.compact().format(summary?.totalSpend ?? 0)} USD base',
                                  style: TextStyle(
                                    color: colors.textMuted,
                                    fontSize: 11.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 14),
                              Divider(color: colors.borderSubtle, height: 1),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _buildStatTile(
                                    colors: colors,
                                    label: 'Transactions',
                                    value: countFormat.format(txnCount),
                                    dotColor: colors.cyan,
                                    onTap: () => widget.onNavigateTab?.call(1),
                                  ),
                                  _buildStatTile(
                                    colors: colors,
                                    label: 'In review',
                                    value: countFormat.format(inReviewAlerts),
                                    dotColor: colors.amber,
                                    valueColor: inReviewAlerts > 0
                                        ? colors.amber
                                        : null,
                                    onTap: () => widget.onNavigateTab?.call(2),
                                  ),
                                  _buildStatTile(
                                    colors: colors,
                                    label: 'Resolved',
                                    value: countFormat.format(resolvedAlerts),
                                    dotColor: colors.emerald,
                                    onTap: () => widget.onNavigateTab?.call(2),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Spending Over Time Chart
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Spending over time',
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    currencyProvider.activeCurrency,
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
                                isSourceUsd: summary?.isSourceUsd ?? false,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Top Categories
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Top categories',
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        widget.onNavigateTab?.call(1),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      minimumSize: const Size(0, 32),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text('See activity'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              CategorySpendBreakdown(
                                categories: summary?.byCategory ?? [],
                                isSourceUsd: summary?.isSourceUsd ?? false,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => RichieChatSheet.show(context),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.auto_awesome_rounded, size: 19),
        label: const Text(
          'Ask Richie',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
        ),
      ),
    );
  }
}
