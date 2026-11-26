import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/transaction.dart';
import '../providers/currency_provider.dart';

class TransactionCard extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;
  final bool compact;

  const TransactionCard({
    super.key,
    required this.transaction,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final currencyProvider = context.watch<CurrencyProvider>();
    final timeFormat = DateFormat('h:mm a');
    final dateFormat = DateFormat('MMM d');
    final isFlagged = transaction.hasAlert;
    final isUnregistered = transaction.cardLabel.toLowerCase().contains(
      'unregistered',
    );

    final catColor = colors.getCategoryColor(transaction.category);
    final catBg = colors.getCategoryBg(transaction.category);
    final catIcon = colors.getCategoryIcon(transaction.category);

    final Color iconBg = isFlagged
        ? colors.riskCriticalBg
        : (transaction.isReceived ? colors.riskLowBg : catBg);

    final Color iconColor = isFlagged
        ? colors.riskCritical
        : (transaction.isReceived ? colors.riskLow : catColor);

    final IconData iconData = isFlagged
        ? Icons.priority_high_rounded
        : (transaction.isReceived ? Icons.south_west_rounded : catIcon);

    final amountStr =
        '${transaction.isReceived ? '+' : ''}${currencyProvider.format(transaction.amount, isSourceUsd: transaction.isSourceUsd)}';

    final friendlyCat = AppColors.friendlyCategoryName(transaction.category);
    final timeLabel =
        '${dateFormat.format(transaction.occurredAt)} · ${timeFormat.format(transaction.occurredAt)}';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Tastefully colored GPay-inspired category/status circle
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(iconData, size: 19, color: iconColor),
            ),
            const SizedBox(width: 12),

            // Merchant & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    transaction.merchant,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '$friendlyCat · $timeLabel',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (transaction.merchLat != null &&
                          transaction.merchLong != null) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: colors.textMuted,
                        ),
                      ],
                    ],
                  ),
                  if (isUnregistered) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Unlinked account',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Amount & Status / Account Right Column
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 118),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      amountStr,
                      style: TextStyle(
                        color: transaction.isReceived
                            ? colors.riskLow
                            : (isFlagged
                                  ? colors.riskCritical
                                  : colors.textPrimary),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        fontFeatures: AppTheme.tabularFigures,
                      ),
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (isFlagged)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.riskCriticalBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Needs review',
                        style: TextStyle(
                          color: colors.riskCritical,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    Text(
                      transaction.cardLabel,
                      style: TextStyle(color: colors.textMuted, fontSize: 11.5),
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
