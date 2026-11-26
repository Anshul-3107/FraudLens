import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/investigation_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/investigation_card.dart';
import '../../widgets/loading_indicator.dart';

/// Reusable Investigation History list view used both standalone and inside Alerts > History.
class InvestigationsFeedView extends StatefulWidget {
  const InvestigationsFeedView({super.key});

  @override
  State<InvestigationsFeedView> createState() => _InvestigationsFeedViewState();
}

class _InvestigationsFeedViewState extends State<InvestigationsFeedView> {
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${NumberFormat.decimalPattern().format(invProvider.count)} past reviews',
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
                  'Page ${invProvider.page} of $totalPages',
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
          child: invProvider.isLoading && invProvider.investigations.isEmpty
              ? const FintechLoadingIndicator(
                  label: 'Loading review history...',
                )
              : invProvider.errorMessage != null &&
                    invProvider.investigations.isEmpty
              ? ErrorView(
                  message: invProvider.errorMessage!,
                  onRetry: () => invProvider.loadInvestigations(),
                )
              : invProvider.investigations.isEmpty
              ? const EmptyStateView(
                  icon: Icons.history_rounded,
                  title: 'No Review History',
                  message: 'Decisions you record on flagged transactions will appear here for reference.',
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      invProvider.loadInvestigations(page: invProvider.page),
                  color: colors.primary,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        itemCount: invProvider.investigations.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return InvestigationCard(
                            investigation: invProvider.investigations[index],
                          );
                        },
                      ),
                    ),
                  ),
                ),
        ),
        if (totalPages > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(top: BorderSide(color: colors.border, width: 1)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: invProvider.hasPrevious && !invProvider.isLoading
                        ? () => invProvider.previousPage()
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
                        'Page ${invProvider.page} of $totalPages',
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
                    onPressed: invProvider.hasNext && !invProvider.isLoading
                        ? () => invProvider.nextPage()
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
    );
  }
}

class InvestigationsListScreen extends StatelessWidget {
  const InvestigationsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final invProvider = context.read<InvestigationProvider>();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Review History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () =>
                invProvider.loadInvestigations(page: invProvider.page),
          ),
        ],
      ),
      body: const InvestigationsFeedView(),
    );
  }
}
