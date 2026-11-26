import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/card_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_indicator.dart';
import '../profile/profile_screen.dart';
import 'link_account_screen.dart';

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

  String _accountInitials(String label) {
    final cleaned = label.trim().toUpperCase();
    if (cleaned.isEmpty) return 'AC';
    final words = cleaned
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.length >= 2 && words[0].isNotEmpty && words[1].isNotEmpty) {
      final first = words[0][0];
      final second = words[1][0];
      if (RegExp(r'[A-Z]').hasMatch(first) &&
          RegExp(r'[A-Z]').hasMatch(second)) {
        return '$first$second';
      }
    }
    final alpha = cleaned.replaceAll(RegExp(r'[^A-Z]'), '');
    if (alpha.length >= 2) return alpha.substring(0, 2);
    if (alpha.length == 1) return alpha;
    return 'AC';
  }

  Color _badgeTint(AppColors colors, int index) {
    final tints = [
      colors.tealPrimary,
      colors.indigo,
      colors.cyan,
      colors.emerald,
      colors.violet,
    ];
    return tints[index % tints.length];
  }

  Future<void> _openLinkBank() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LinkAccountScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cardProvider = context.watch<CardProvider>();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Link bank or card',
            onPressed: _openLinkBank,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Account & Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => cardProvider.loadCards(),
          ),
        ],
      ),
      body: cardProvider.isLoading && cardProvider.cards.isEmpty
          ? const FintechLoadingIndicator(label: 'Loading accounts...')
          : cardProvider.errorMessage != null && cardProvider.cards.isEmpty
          ? ErrorView(
              message: cardProvider.errorMessage!,
              onRetry: () => cardProvider.loadCards(),
            )
          : cardProvider.cards.isEmpty
          ? EmptyStateView(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No Accounts Linked',
              message: 'Link a bank account or card, or let FraudLens automatically add accounts from payment notifications.',
              actionLabel: 'Link bank account',
              onAction: _openLinkBank,
            )
          : RefreshIndicator(
              onRefresh: () => cardProvider.loadCards(),
              color: colors.primary,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: cardProvider.cards.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final card = cardProvider.cards[index];
                      final isUnregistered = card.label.toLowerCase().contains(
                        'unregistered',
                      );
                      final accent = _badgeTint(colors, index);

                      return Container(
                        padding: const EdgeInsets.all(16),
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
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: accent.withValues(
                                      alpha: colors.isDark ? 0.16 : 0.10,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _accountInitials(card.label),
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        card.label,
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: isUnregistered
                                                  ? colors.riskMedium
                                                  : colors.riskLow,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              isUnregistered
                                                  ? 'Unlinked · Auto-captured'
                                                  : 'Monitored · ID #${card.id}',
                                              style: TextStyle(
                                                color: colors.textMuted,
                                                fontSize: 12,
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
                              ],
                            ),
                            const SizedBox(height: 14),
                            Divider(color: colors.borderSubtle, height: 1),
                            const SizedBox(height: 12),
                            // Wrap guarantees zero horizontal overflow at 320px or high font scale
                            SizedBox(
                              width: double.infinity,
                              child: Wrap(
                                alignment: WrapAlignment.start,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      context
                                          .read<TransactionProvider>()
                                          .setCard(card.id);
                                      widget.onNavigateTab?.call(1);
                                    },
                                    icon: const Icon(
                                      Icons.receipt_long_outlined,
                                      size: 16,
                                    ),
                                    label: const Text('Activity'),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 38),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      context
                                          .read<DashboardProvider>()
                                          .setCardFilter(card);
                                      widget.onNavigateTab?.call(0);
                                    },
                                    icon: const Icon(
                                      Icons.bar_chart_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('Insights'),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 38),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
    );
  }
}
