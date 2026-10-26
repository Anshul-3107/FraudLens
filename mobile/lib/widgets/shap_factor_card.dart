import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/alert.dart';

class ShapFactorCard extends StatelessWidget {
  final ShapReason reason;

  const ShapFactorCard({super.key, required this.reason});

  IconData _getFactorIcon(String factor) {
    switch (factor.toLowerCase()) {
      case 'amount':
        return Icons.attach_money_rounded;
      case 'time':
        return Icons.schedule_rounded;
      case 'category':
        return Icons.storefront_rounded;
      case 'velocity':
        return Icons.speed_rounded;
      case 'novelty':
        return Icons.fiber_new_rounded;
      case 'rarity':
        return Icons.fingerprint_rounded;
      case 'location':
        return Icons.location_on_rounded;
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: colors.riskCriticalBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  _getFactorIcon(reason.factor),
                  size: 15,
                  color: colors.riskCritical,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatFactorTitle(reason.factor),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '+${reason.impact.toStringAsFixed(2)} SHAP',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            reason.text,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: normalizedImpact,
              backgroundColor: colors.surfaceMuted,
              valueColor: AlwaysStoppedAnimation<Color>(
                reason.impact >= 0.5 ? colors.riskCritical : colors.riskHigh,
              ),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }
}
