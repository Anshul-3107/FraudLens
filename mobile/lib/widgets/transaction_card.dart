import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/transaction.dart';
import '../providers/currency_provider.dart';

class TransactionCard extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;

  const TransactionCard({super.key, required this.transaction, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final currencyProvider = context.watch<CurrencyProvider>();
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    final isFlagged = transaction.hasAlert;
    final isUnregistered = transaction.cardLabel.toLowerCase().contains('unregistered');

    // Vibrant Red card for fraud / flagged ("Needs Action")
    // Vibrant Green card for safe, legitimate transactions
    final cardBgColor = isFlagged
        ? const Color(0xFFEF4444).withValues(alpha: 0.12)
        : const Color(0xFF10B981).withValues(alpha: 0.08);

    final cardBorderColor = isFlagged
        ? const Color(0xFFEF4444).withValues(alpha: 0.45)
        : const Color(0xFF10B981).withValues(alpha: 0.35);

    final statusTextColor = isFlagged
        ? const Color(0xFFEF4444)
        : const Color(0xFF10B981);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cardBorderColor,
            width: isFlagged ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Transaction Icon / Status indicator
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isFlagged
                    ? const Color(0xFFEF4444).withValues(alpha: 0.20)
                    : const Color(0xFF10B981).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isFlagged
                      ? const Color(0xFFEF4444).withValues(alpha: 0.35)
                      : const Color(0xFF10B981).withValues(alpha: 0.30),
                ),
              ),
              child: Icon(
                isFlagged ? Icons.warning_rounded : Icons.check_circle_rounded,
                size: 20,
                color: statusTextColor,
              ),
            ),
            const SizedBox(width: 12),

            // Merchant, Date, and Badges
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          transaction.merchant,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isFlagged) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                            ),
                          ),
                          child: const Text(
                            'NEEDS ACTION',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Text(
                            'SAFE',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (isUnregistered) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: colors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: colors.borderSubtle),
                          ),
                          child: Text(
                            'UNREGISTERED',
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          '${dateFormat.format(transaction.occurredAt)} • ${transaction.cardLabel}',
                          style: TextStyle(color: colors.textMuted, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Amount and Category
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 105),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      currencyProvider.format(transaction.amount),
                      style: TextStyle(
                        color: statusTextColor,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: colors.borderSubtle),
                    ),
                    child: Text(
                      transaction.formattedCategory,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
