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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isFlagged
                ? colors.riskCritical.withValues(alpha: 0.35)
                : colors.borderSubtle,
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Transaction Icon / Flag indicator
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isFlagged ? colors.riskCriticalBg : colors.surfaceSubtle,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isFlagged
                      ? colors.riskCritical.withValues(alpha: 0.25)
                      : colors.borderSubtle,
                ),
              ),
              child: Icon(
                isFlagged ? Icons.warning_rounded : Icons.storefront_rounded,
                size: 18,
                color: isFlagged ? colors.riskCritical : colors.textSecondary,
              ),
            ),
            const SizedBox(width: 10),

            // Merchant and date
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
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.riskCriticalBg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: colors.riskCritical.withValues(
                                alpha: 0.25,
                              ),
                            ),
                          ),
                          child: Text(
                            'FLAGGED',
                            style: TextStyle(
                              color: colors.riskCritical,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${dateFormat.format(transaction.occurredAt)} • ${transaction.cardLabel}',
                    style: TextStyle(color: colors.textMuted, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                        color: isFlagged
                            ? colors.riskCritical
                            : colors.textPrimary,
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
