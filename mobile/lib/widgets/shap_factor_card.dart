import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/alert.dart';

class ShapFactorCard extends StatelessWidget {
  final ShapReason reason;

  const ShapFactorCard({super.key, required this.reason});

  IconData _getFactorIcon(String factor) {
    switch (factor.toLowerCase()) {
      case 'amount':
        return Icons.payments_outlined;
      case 'time':
        return Icons.schedule_rounded;
      case 'category':
        return Icons.storefront_outlined;
      case 'velocity':
        return Icons.bolt_rounded;
      case 'novelty':
        return Icons.fiber_new_outlined;
      case 'rarity':
        return Icons.fingerprint_rounded;
      case 'location':
        return Icons.location_on_outlined;
      default:
        return Icons.analytics_outlined;
    }
  }

  String _formatFactorTitle(String factor) {
    switch (factor.toLowerCase()) {
      case 'amount':
        return 'Spend Amount Anomaly';
      case 'time':
        return 'Temporal Risk Pattern';
      case 'category':
        return 'Spending Category';
      case 'velocity':
        return 'Transaction Velocity';
      case 'novelty':
        return 'Novelty / First-time';
      case 'rarity':
        return 'Multivariate Rarity';
      case 'location':
        return 'Geographic Distance';
      default:
        return factor.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final normalizedImpact = (reason.impact / 1.5).clamp(0.05, 1.0);
    final isStrong = reason.impact >= 0.5;
    final barColor = isStrong ? colors.riskCritical : colors.riskMedium;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getFactorIcon(reason.factor),
                size: 15,
                color: isStrong ? colors.riskCritical : colors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatFactorTitle(reason.factor),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '+${reason.impact.toStringAsFixed(2)} Risk Impact',
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  fontFeatures: AppTheme.tabularFigures,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 23),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reason.text,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: normalizedImpact,
                    backgroundColor: colors.surfaceMuted,
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    minHeight: 4,
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
