import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/investigation_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/risk_badge.dart';

class InvestigationsListScreen extends StatefulWidget {
  const InvestigationsListScreen({super.key});

  @override
  State<InvestigationsListScreen> createState() =>
      _InvestigationsListScreenState();
}

class _InvestigationsListScreenState extends State<InvestigationsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final invProvider = context.read<InvestigationProvider>();
      if (invProvider.investigations.isEmpty) {
        invProvider.loadInvestigations();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final invProvider = context.watch<InvestigationProvider>();
    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    );
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    final totalPages = (invProvider.count / 50).ceil();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Investigation History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () =>
                invProvider.loadInvestigations(page: invProvider.page),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${NumberFormat.decimalPattern().format(invProvider.count)} investigations logged',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (totalPages > 1)
                  Text(
                    'Page ${invProvider.page} of $totalPages',
                    style: TextStyle(fontSize: 12, color: colors.textMuted),
                  ),
              ],
            ),
          ),

          // Main List
          Expanded(
            child: invProvider.isLoading && invProvider.investigations.isEmpty
                ? const FintechLoadingIndicator(
                    label: 'Loading investigation history...',
                  )
                : invProvider.errorMessage != null &&
                      invProvider.investigations.isEmpty
                ? ErrorView(
                    message: invProvider.errorMessage!,
                    onRetry: () => invProvider.loadInvestigations(),
                  )
                : invProvider.investigations.isEmpty
                ? const EmptyStateView(
                    icon: Icons.gavel_rounded,
                    title: 'No Investigations Yet',
                    message: 'When analysts review and record verdicts on alerts, the full audit trail appears here.',
                  )
                : RefreshIndicator(
                    onRefresh: () =>
                        invProvider.loadInvestigations(page: invProvider.page),
                    color: colors.primary,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      itemCount: invProvider.investigations.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final inv = invProvider.investigations[index];

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colors.borderSubtle,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  VerdictBadge(verdict: inv.verdict),
                                  Text(
                                    'Alert #${inv.alert}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.textMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Merchant and Amount
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      inv.merchant,
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    currencyFormat.format(inv.amount),
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // Analyst info and date
                              Row(
                                children: [
                                  Icon(
                                    Icons.person_pin_rounded,
                                    size: 14,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    inv.analystName != null
                                        ? 'Analyst: ${inv.analystName}'
                                        : 'System review',
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '•',
                                    style: TextStyle(color: colors.textMuted),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    dateFormat.format(inv.createdAt),
                                    style: TextStyle(
                                      color: colors.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),

                              // Notes if provided
                              if (inv.notes.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceSubtle,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: colors.borderSubtle,
                                    ),
                                  ),
                                  child: Text(
                                    inv.notes,
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 12,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ],
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
                    onPressed: invProvider.hasPrevious && !invProvider.isLoading
                        ? () => invProvider.previousPage()
                        : null,
                    icon: const Icon(Icons.chevron_left_rounded, size: 18),
                    label: const Text('Previous'),
                  ),
                  Text(
                    'Page ${invProvider.page} of $totalPages',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: invProvider.hasNext && !invProvider.isLoading
                        ? () => invProvider.nextPage()
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                    label: const Text('Next'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
