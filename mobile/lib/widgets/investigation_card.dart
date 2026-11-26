import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/investigation.dart';
import '../providers/currency_provider.dart';
import 'risk_badge.dart';

class InvestigationCard extends StatelessWidget {
  final InvestigationModel investigation;
  final VoidCallback? onTap;

  const InvestigationCard({super.key, required this.investigation, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final currencyProvider = context.watch<CurrencyProvider>();
    final dateFormat = DateFormat('MMM d, yyyy · h:mm a');

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row stretching full width safely
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    VerdictBadge(verdict: investigation.verdict),
                    Text(
                      'Alert #${investigation.alert}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: colors.textMuted,
                        fontWeight: FontWeight.w500,
                        fontFeatures: AppTheme.tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Merchant and Amount
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      investigation.merchant,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 115),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        currencyProvider.format(investigation.amount),
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFeatures: AppTheme.tabularFigures,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Analyst & Timestamp cleanly wrapped for 320px viewports
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 13.5,
                          color: colors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            investigation.analystName != null
                                ? 'Reviewed by ${investigation.analystName}'
                                : 'System review',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Text('·', style: TextStyle(color: colors.textMuted)),
                    Text(
                      dateFormat.format(investigation.createdAt),
                      style: TextStyle(color: colors.textMuted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),

              if (investigation.notes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    investigation.notes,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
