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
    final isUnregistered =
        transaction.cardLabel.toLowerCase().contains('unregistered');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFlagged
                ? colors.riskCritical.withValues(alpha: 0.35)
                : colors.borderSubtle,
            width: 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Transaction icon container (clean & restrained)
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isFlagged
                    ? colors.riskCriticalBg
                    : (transaction.isReceived
                        ? colors.riskLowBg
                        : colors.surfaceSubtle),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isFlagged
                    ? Icons.warning_amber_rounded
                    : (transaction.isReceived
                        ? Icons.south_west_rounded
                        : Icons.north_east_rounded),
                size: 18,
                color: isFlagged
                    ? colors.riskCritical
                    : (transaction.isReceived
                        ? colors.riskLow
                        : colors.textSecondary),
              ),
            ),
            const SizedBox(width: 12),

            // Merchant & Metadata
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
                            letterSpacing: -0.1,
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
                            color: colors.riskCriticalBg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: colors.riskCritical.withValues(alpha: 0.3),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            'NEEDS ACTION',
                            style: TextStyle(
                              color: colors.riskCritical,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          margin: const EdgeInsets.only(right: 5),
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
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          '${transaction.formattedCategory} • ${dateFormat.format(transaction.occurredAt)}',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11.5,
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
            const SizedBox(width: 10),

            // Amount and Card Source
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${transaction.isReceived ? '+' : ''}${currencyProvider.format(transaction.amount, isSourceUsd: transaction.isSourceUsd)}',
                      style: TextStyle(
                        color: transaction.isReceived
                            ? colors.riskLow
                            : (isFlagged
                                ? colors.riskCritical
                                : colors.textPrimary),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    transaction.cardLabel,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
