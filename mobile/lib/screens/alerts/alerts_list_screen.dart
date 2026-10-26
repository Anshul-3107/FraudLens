import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/alert_provider.dart';
import '../../providers/card_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/risk_badge.dart';
import 'alert_detail_screen.dart';

class AlertsListScreen extends StatefulWidget {
  const AlertsListScreen({super.key});

  @override
  State<AlertsListScreen> createState() => _AlertsListScreenState();
}

class _AlertsListScreenState extends State<AlertsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final alertProvider = context.read<AlertProvider>();
      if (alertProvider.alerts.isEmpty) {
        alertProvider.loadAlerts();
      }
      context.read<CardProvider>().loadCards();
    });
  }

  void _showFilterModal() {
    final colors = AppColors.of(context);
    final alertProvider = context.read<AlertProvider>();
    final cardProvider = context.read<CardProvider>();

    int? tempCardId = alertProvider.cardId;
    double? tempMinScore = alertProvider.minScore;
    String? tempOrdering = alertProvider.ordering;

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
                        'Filter & Order Alerts',
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
                  const SizedBox(height: 14),

                  // Card Selector
                  DropdownButtonFormField<int?>(
                    initialValue: tempCardId,
                    decoration: const InputDecoration(
                      labelText: 'Card',
                      prefixIcon: Icon(Icons.credit_card_rounded, size: 20),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('All Cards'),
                      ),
                      ...cardProvider.cards.map(
                        (c) => DropdownMenuItem<int?>(
                          value: c.id,
                          child: Text(c.label),
                        ),
                      ),
                    ],
                    onChanged: (val) => setModalState(() => tempCardId = val),
                  ),
                  const SizedBox(height: 14),

                  // Min Score Selector
                  DropdownButtonFormField<double?>(
                    initialValue: tempMinScore,
                    decoration: const InputDecoration(
                      labelText: 'Minimum Risk Score',
                      prefixIcon: Icon(Icons.speed_rounded, size: 20),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: null,
                        child: Text('All Scores (>= 0%)'),
                      ),
                      DropdownMenuItem(
                        value: 0.50,
                        child: Text('>= 50% Elevated Risk'),
                      ),
                      DropdownMenuItem(
                        value: 0.65,
                        child: Text('>= 65% Threshold'),
                      ),
                      DropdownMenuItem(
                        value: 0.80,
                        child: Text('>= 80% Critical Risk'),
                      ),
                      DropdownMenuItem(
                        value: 0.90,
                        child: Text('>= 90% High Confidence'),
                      ),
                    ],
                    onChanged: (val) => setModalState(() => tempMinScore = val),
                  ),
                  const SizedBox(height: 14),

                  // Ordering Selector
                  DropdownButtonFormField<String?>(
                    initialValue: tempOrdering,
                    decoration: const InputDecoration(
                      labelText: 'Sort Order',
                      prefixIcon: Icon(Icons.sort_rounded, size: 20),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: null,
                        child: Text('Newest Transaction First (Default)'),
                      ),
                      DropdownMenuItem(
                        value: '-score',
                        child: Text('Risk Score (Highest First)'),
                      ),
                      DropdownMenuItem(
                        value: 'score',
                        child: Text('Risk Score (Lowest First)'),
                      ),
                      DropdownMenuItem(
                        value: '-created_at',
                        child: Text('Alert Created Time (Newest)'),
                      ),
                      DropdownMenuItem(
                        value: 'created_at',
                        child: Text('Alert Created Time (Oldest)'),
                      ),
                    ],
                    onChanged: (val) => setModalState(() => tempOrdering = val),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            alertProvider.resetFilters();
                            Navigator.pop(ctx);
                          },
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            alertProvider.setCard(tempCardId);
                            alertProvider.setMinScore(tempMinScore);
                            alertProvider.setOrdering(tempOrdering);
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

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final alertProvider = context.watch<AlertProvider>();
    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    );
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');

    final totalPages = (alertProvider.count / 50).ceil();
    final activeStatus = alertProvider.statusFilter;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Fraud Alerts'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: alertProvider.hasActiveFilters,
              backgroundColor: colors.primary,
              child: const Icon(Icons.filter_list_rounded),
            ),
            tooltip: 'Filter',
            onPressed: _showFilterModal,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => alertProvider.loadAlerts(page: alertProvider.page),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Selector Segmented Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(
                bottom: BorderSide(color: colors.borderSubtle, width: 1),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _StatusFilterChip(
                    label: 'All Alerts',
                    isSelected: activeStatus == null || activeStatus.isEmpty,
                    onTap: () => alertProvider.setStatus(null),
                  ),
                  const SizedBox(width: 8),
                  _StatusFilterChip(
                    label: 'Open',
                    isSelected: activeStatus == 'open',
                    color: colors.riskCritical,
                    onTap: () => alertProvider.setStatus('open'),
                  ),
                  const SizedBox(width: 8),
                  _StatusFilterChip(
                    label: 'In Review',
                    isSelected: activeStatus == 'in_review',
                    color: colors.riskMedium,
                    onTap: () => alertProvider.setStatus('in_review'),
                  ),
                  const SizedBox(width: 8),
                  _StatusFilterChip(
                    label: 'Resolved',
                    isSelected: activeStatus == 'resolved',
                    color: colors.riskLow,
                    onTap: () => alertProvider.setStatus('resolved'),
                  ),
                ],
              ),
            ),
          ),

          // Count and page bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${NumberFormat.decimalPattern().format(alertProvider.count)} total alerts',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (totalPages > 1)
                  Text(
                    'Page ${alertProvider.page} of $totalPages',
                    style: TextStyle(fontSize: 12, color: colors.textMuted),
                  ),
              ],
            ),
          ),

          // Main Alerts List
          Expanded(
            child: alertProvider.isLoading && alertProvider.alerts.isEmpty
                ? const FintechLoadingIndicator(
                    label: 'Loading fraud alerts...',
                  )
                : alertProvider.errorMessage != null &&
                      alertProvider.alerts.isEmpty
                ? ErrorView(
                    message: alertProvider.errorMessage!,
                    onRetry: () => alertProvider.loadAlerts(),
                  )
                : alertProvider.alerts.isEmpty
                ? EmptyStateView(
                    icon: Icons.verified_user_rounded,
                    title: 'No Fraud Alerts Found',
                    message: alertProvider.hasActiveFilters
                        ? 'No alerts match the selected status or filters.'
                        : 'All transactions are currently clear of fraud alerts.',
                    actionLabel: alertProvider.hasActiveFilters
                        ? 'Clear Filters'
                        : null,
                    onAction: alertProvider.hasActiveFilters
                        ? () => alertProvider.resetFilters()
                        : null,
                  )
                : RefreshIndicator(
                    onRefresh: () =>
                        alertProvider.loadAlerts(page: alertProvider.page),
                    color: colors.primary,
                    child: ListView.separated(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 4,
                        bottom: 20,
                      ),
                      itemCount: alertProvider.alerts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final alert = alertProvider.alerts[index];
                        final txn = alert.transaction;
                        final topReason = alert.reasons.isNotEmpty
                            ? alert.reasons.first
                            : null;

                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AlertDetailScreen(alert: alert),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: alert.status == 'open'
                                    ? colors.riskCritical.withValues(
                                        alpha: 0.35,
                                      )
                                    : colors.borderSubtle,
                                width: alert.status == 'open' ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header Row: Score Badge + Status
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    RiskScoreBadge(
                                      score: alert.score,
                                      threshold: alert.threshold,
                                    ),
                                    Row(
                                      children: [
                                        AlertStatusBadge(status: alert.status),
                                        if (alert.latestVerdict != null) ...[
                                          const SizedBox(width: 6),
                                          VerdictBadge(
                                            verdict: alert.latestVerdict!,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Merchant and Amount
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            txn?.merchant ?? 'Unknown Merchant',
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            txn != null
                                                ? dateFormat.format(
                                                    txn.occurredAt,
                                                  )
                                                : '',
                                            style: TextStyle(
                                              color: colors.textMuted,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      currencyFormat.format(txn?.amount ?? 0),
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),

                                // Top SHAP explanation text snippet
                                if (topReason != null) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.surfaceSubtle,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: colors.borderSubtle,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.psychology_outlined,
                                          size: 14,
                                          color: colors.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            topReason.text,
                                            style: TextStyle(
                                              color: colors.textSecondary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 10),

                                // Card label & investigate prompt
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      txn?.cardLabel ?? 'Alert #${alert.id}',
                                      style: TextStyle(
                                        color: colors.textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          'Investigate',
                                          style: TextStyle(
                                            color: colors.primary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          size: 16,
                                          color: colors.primary,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),

          // Pagination Bar at Bottom
          if (totalPages > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  top: BorderSide(color: colors.borderSubtle, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed:
                        alertProvider.hasPrevious && !alertProvider.isLoading
                        ? () => alertProvider.previousPage()
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded, size: 18),
                    label: const Text('Previous'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                  Text(
                    'Page ${alertProvider.page} of $totalPages',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: alertProvider.hasNext && !alertProvider.isLoading
                        ? () => alertProvider.nextPage()
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                    label: const Text('Next'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _StatusFilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final effectiveColor = color ?? colors.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? effectiveColor : colors.surfaceSubtle,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? effectiveColor : colors.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : colors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
