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
              icon: Icons.credit_card_outlined,
              title: 'No Cards or Accounts Yet',
              message: 'Cards are automatically linked when transactions occur via UPI notifications, Bank SMS, or manual recording.',
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

                  // Curated fintech card gradients
                  final List<List<Color>> cardGradients = [
                    [const Color(0xFF0F2E25), const Color(0xFF134E4A), const Color(0xFF0F172A)],
                    [const Color(0xFF1E1B4B), const Color(0xFF312E81), const Color(0xFF0F172A)],
                    [const Color(0xFF1E293B), const Color(0xFF334155), const Color(0xFF0F172A)],
                    [const Color(0xFF4C0519), const Color(0xFF701A75), const Color(0xFF0F172A)],
                    [const Color(0xFF1E3A5F), const Color(0xFF0284C7), const Color(0xFF0F172A)],
                  ];
                  final gradient = cardGradients[index % cardGradients.length];

                  return Container(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border, width: 1),
                      boxShadow: colors.cardShadow,
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Aesthetic Digital Payment Card Representation
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: gradient,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: gradient[0].withValues(alpha: 0.35),
                                offset: const Offset(0, 4),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // EMV Chip graphic & Contactless
                                  Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFBBF24).withValues(alpha: 0.85),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: const Color(0xFFD97706),
                                            width: 1,
                                          ),
                                        ),
                                        child: Center(
                                          child: Container(
                                            width: 24,
                                            height: 1,
                                            color: const Color(0xFFB45309).withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.contactless_rounded,
                                        color: Colors.white.withValues(alpha: 0.85),
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'CARD #${card.id}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Text(
                                card.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    '•••• •••• •••• 4242',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12.5,
                                      fontFamily: 'monospace',
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF34D399),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'PROTECTED',
                                        style: TextStyle(
                                          color: Color(0xFF34D399),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
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
                                  horizontal: 14,
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
                                  horizontal: 14,
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
