import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/card_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_indicator.dart';

class CardsListScreen extends StatefulWidget {
  final Function(int tabIndex)? onNavigateTab;

  const CardsListScreen({super.key, this.onNavigateTab});

  @override
  State<CardsListScreen> createState() => _CardsListScreenState();
}

class _CardsListScreenState extends State<CardsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cardProvider = context.read<CardProvider>();
      if (cardProvider.cards.isEmpty) {
        cardProvider.loadCards();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cardProvider = context.watch<CardProvider>();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Payment Cards'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => cardProvider.loadCards(),
          ),
        ],
      ),
      body: cardProvider.isLoading && cardProvider.cards.isEmpty
          ? const FintechLoadingIndicator(label: 'Loading cards...')
          : cardProvider.errorMessage != null && cardProvider.cards.isEmpty
          ? ErrorView(
              message: cardProvider.errorMessage!,
              onRetry: () => cardProvider.loadCards(),
            )
          : cardProvider.cards.isEmpty
          ? const EmptyStateView(
              icon: Icons.credit_card_off_rounded,
              title: 'No Cards Assigned',
              message: 'There are no active payment cards assigned to your user account.',
            )
          : RefreshIndicator(
              onRefresh: () => cardProvider.loadCards(),
              color: colors.primary,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: cardProvider.cards.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final card = cardProvider.cards[index];

                  return Container(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.borderSubtle, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: colors.shadow,
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: colors.riskLow,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'MONITORED CARD',
                                  style: TextStyle(
                                    color: colors.textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: colors.borderSubtle),
                              ),
                              child: Text(
                                '#${card.id}',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 11,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Icon(
                              Icons.credit_card_rounded,
                              size: 20,
                              color: colors.textSecondary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                card.label,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Divider(height: 1, color: colors.borderSubtle),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                context.read<DashboardProvider>().setCardFilter(
                                  card,
                                );
                                widget.onNavigateTab?.call(0);
                              },
                              icon: const Icon(
                                Icons.analytics_outlined,
                                size: 14,
                              ),
                              label: const Text('Analytics'),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: () {
                                context.read<TransactionProvider>().setCard(
                                  card.id,
                                );
                                widget.onNavigateTab?.call(1);
                              },
                              icon: const Icon(
                                Icons.receipt_long_rounded,
                                size: 14,
                              ),
                              label: const Text('Transactions'),
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
