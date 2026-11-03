import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/investigation_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/investigation_card.dart';
import '../../widgets/loading_indicator.dart';

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
                Expanded(
                  child: Text(
                    '${NumberFormat.decimalPattern().format(invProvider.count)} investigations logged',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                        return InvestigationCard(investigation: inv);
                      },
                    ),
                  ),
          ),

          // Pagination Bar at Bottom
          if (totalPages > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    icon: const Icon(Icons.chevron_left_rounded, size: 16),
                    label: const Text('Prev'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'Page ${invProvider.page} of $totalPages',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: invProvider.hasNext && !invProvider.isLoading
                        ? () => invProvider.nextPage()
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded, size: 16),
                    label: const Text('Next'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
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
