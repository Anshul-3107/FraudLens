import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/alert_provider.dart';
import '../../providers/card_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/investigation_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/risk_badge.dart';
import '../investigations/investigations_list_screen.dart';
import 'alert_detail_screen.dart';

class AlertsListScreen extends StatefulWidget {
  const AlertsListScreen({super.key});

  @override
  State<AlertsListScreen> createState() => _AlertsListScreenState();
}

class _AlertsListScreenState extends State<AlertsListScreen> {
  int _selectedSection = 0; // 0 = Alerts, 1 = Review History

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
                          'Filter Alerts',
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

                  DropdownButtonFormField<int?>(
                    isExpanded: true,
                    initialValue: tempCardId,
                    decoration: const InputDecoration(
                      labelText: 'Account / Card',
                      prefixIcon: Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 20,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text(
                          'All Accounts',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ...cardProvider.cards.map(
                        (c) => DropdownMenuItem<int?>(
                          value: c.id,
                          child: Text(c.label, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (val) => setModalState(() => tempCardId = val),
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<double?>(
                    isExpanded: true,
                    initialValue: tempMinScore,
                    decoration: const InputDecoration(
                      labelText: 'Minimum Risk Score',
                      prefixIcon: Icon(Icons.speed_outlined, size: 20),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All scores')),
                      DropdownMenuItem(
                        value: 0.50,
                        child: Text('50% or higher'),
                      ),
                      DropdownMenuItem(
                        value: 0.65,
                        child: Text('65% or higher'),
                      ),
                      DropdownMenuItem(
                        value: 0.80,
                        child: Text('80% or higher (Critical)'),
                      ),
                      DropdownMenuItem(
                        value: 0.90,
                        child: Text('90% or higher'),
                      ),
                    ],
                    onChanged: (val) => setModalState(() => tempMinScore = val),
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<String?>(
                    isExpanded: true,
                    initialValue: tempOrdering,
                    decoration: const InputDecoration(
                      labelText: 'Sort Order',
                      prefixIcon: Icon(Icons.sort_rounded, size: 20),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: '-created_at',
                        child: Text('Newest first'),
                      ),
                      DropdownMenuItem(
                        value: '-score',
                        child: Text('Highest risk first'),
                      ),
                      DropdownMenuItem(
                        value: 'created_at',
                        child: Text('Oldest first'),
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
                            alertProvider.setOrdering(
                              tempOrdering ?? '-created_at',
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

  Widget _buildSectionTab({
    required AppColors colors,
    required String label,
    required int index,
  }) {
    final selected = _selectedSection == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedSection = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? colors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected ? colors.cardShadow : const [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? colors.textPrimary : colors.textMuted,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final alertProvider = context.watch<AlertProvider>();
    final currencyProvider = context.watch<CurrencyProvider>();
    final dateFormat = DateFormat('MMM d, yyyy · h:mm a');
    final activeStatus = alertProvider.statusFilter;
    final totalPages = (alertProvider.count / 50).ceil();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          if (_selectedSection == 0)
            IconButton(
              icon: Badge(
                isLabelVisible: alertProvider.hasActiveFilters,
                backgroundColor: colors.primary,
                child: const Icon(Icons.tune_rounded),
              ),
              tooltip: 'Filter',
              onPressed: _showFilterModal,
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              if (_selectedSection == 0) {
                alertProvider.loadAlerts(page: alertProvider.page);
              } else {
                final invProvider = context.read<InvestigationProvider>();
                invProvider.loadInvestigations(page: invProvider.page);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Mode Switcher: Active Alerts vs Past History
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildSectionTab(
                        colors: colors,
                        label: 'Alerts',
                        index: 0,
                      ),
                      _buildSectionTab(
                        colors: colors,
                        label: 'History',
                        index: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (_selectedSection == 1)
            const Expanded(child: InvestigationsFeedView())
          else ...[
            // Status Filter Strip
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _StatusFilterChip(
                      label: 'All',
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

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${NumberFormat.decimalPattern().format(alertProvider.count)} ${alertProvider.count == 1 ? 'alert' : 'alerts'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textMuted,
                        fontWeight: FontWeight.w500,
                        fontFeatures: AppTheme.tabularFigures,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (totalPages > 1)
                    Text(
                      'Page ${alertProvider.page} of $totalPages',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textMuted,
                        fontFeatures: AppTheme.tabularFigures,
                      ),
                    ),
                ],
              ),
            ),

            Expanded(
              child: alertProvider.isLoading && alertProvider.alerts.isEmpty
                  ? const FintechLoadingIndicator(label: 'Loading alerts...')
                  : alertProvider.errorMessage != null &&
                        alertProvider.alerts.isEmpty
                  ? ErrorView(
                      message: alertProvider.errorMessage!,
                      onRetry: () => alertProvider.loadAlerts(),
                    )
                  : alertProvider.alerts.isEmpty
                  ? EmptyStateView(
                      icon: Icons.verified_user_outlined,
                      title: 'No Alerts Found',
                      message: alertProvider.hasActiveFilters
                          ? 'No alerts match your current filters.'
                          : 'Everything looks normal across your accounts.',
                      actionLabel: alertProvider.hasActiveFilters
                          ? 'Clear filters'
                          : null,
                      onAction: alertProvider.hasActiveFilters
                          ? () => alertProvider.resetFilters()
                          : null,
                    )
                  : RefreshIndicator(
                      onRefresh: () =>
                          alertProvider.loadAlerts(page: alertProvider.page),
                      color: colors.primary,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                            itemCount: alertProvider.alerts.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final alert = alertProvider.alerts[index];
                              final txn = alert.transaction;
                              final topReason = alert.reasons.isNotEmpty
                                  ? alert.reasons.first
                                  : null;
                              final amountText = currencyProvider.format(
                                txn?.amount ?? 0,
                                isSourceUsd: txn?.isSourceUsd ?? true,
                              );

                              return Material(
                                color: colors.surface,
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            AlertDetailScreen(alert: alert),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.all(15),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: alert.status == 'open'
                                            ? colors.riskCritical.withValues(
                                                alpha: 0.3,
                                              )
                                            : colors.border,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: double.infinity,
                                          child: Wrap(
                                            alignment:
                                                WrapAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            spacing: 8,
                                            runSpacing: 6,
                                            children: [
                                              RiskScoreBadge(
                                                score: alert.score,
                                                threshold: alert.threshold,
                                              ),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 4,
                                                children: [
                                                  AlertStatusBadge(
                                                    status: alert.status,
                                                  ),
                                                  if (alert.latestVerdict !=
                                                      null)
                                                    VerdictBadge(
                                                      verdict:
                                                          alert.latestVerdict!,
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),

                                        // Merchant & Amount
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    txn?.merchant ??
                                                        'Unknown Merchant',
                                                    style: TextStyle(
                                                      color: colors.textPrimary,
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
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
                                                      fontSize: 12,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: 118,
                                              ),
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment:
                                                    Alignment.centerRight,
                                                child: Text(
                                                  amountText,
                                                  style: TextStyle(
                                                    color: colors.textPrimary,
                                                    fontSize: 15.5,
                                                    fontWeight: FontWeight.w700,
                                                    fontFeatures:
                                                        AppTheme.tabularFigures,
                                                  ),
                                                  maxLines: 1,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),

                                        if (topReason != null) ...[
                                          const SizedBox(height: 10),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 7,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colors.surfaceMuted,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              topReason.text,
                                              style: TextStyle(
                                                color: colors.textSecondary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],

                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                txn?.cardLabel ??
                                                    'Alert #${alert.id}',
                                                style: TextStyle(
                                                  color: colors.textMuted,
                                                  fontSize: 11.5,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Review',
                                                  style: TextStyle(
                                                    color: colors.primary,
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                Icon(
                                                  Icons.chevron_right_rounded,
                                                  size: 17,
                                                  color: colors.primary,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
            ),

            if (totalPages > 1)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(
                    top: BorderSide(color: colors.border, width: 1),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton.icon(
                        onPressed:
                            alertProvider.hasPrevious &&
                                !alertProvider.isLoading
                            ? () => alertProvider.previousPage()
                            : null,
                        icon: const Icon(Icons.chevron_left_rounded, size: 18),
                        label: const Text('Prev'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'Page ${alertProvider.page} of $totalPages',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontFeatures: AppTheme.tabularFigures,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            alertProvider.hasNext && !alertProvider.isLoading
                            ? () => alertProvider.nextPage()
                            : null,
                        icon: const Icon(Icons.chevron_right_rounded, size: 18),
                        label: const Text('Next'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
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
    final effectiveColor = color ?? colors.textPrimary;
    final selectedFg = (color != null || !colors.isDark)
        ? Colors.white
        : const Color(0xFF0F0F11);

    return Material(
      color: isSelected ? effectiveColor : colors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? effectiveColor : colors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? selectedFg : colors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
