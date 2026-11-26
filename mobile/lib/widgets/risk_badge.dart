import 'package:flutter/material.dart';

import '../config/app_theme.dart';

class RiskScoreBadge extends StatelessWidget {
  final double score;
  final double threshold;
  final bool compact;

  const RiskScoreBadge({
    super.key,
    required this.score,
    this.threshold = 0.65,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    Color bg;
    Color fg;
    String label;

    if (score >= 0.80) {
      bg = colors.riskCriticalBg;
      fg = colors.riskCritical;
      label = 'CRITICAL';
    } else if (score >= threshold) {
      bg = colors.riskHighBg;
      fg = colors.riskHigh;
      label = 'HIGH RISK';
    } else if (score >= 0.35) {
      bg = colors.riskMediumBg;
      fg = colors.riskMedium;
      label = 'ELEVATED';
    } else {
      bg = colors.riskLowBg;
      fg = colors.riskLow;
      label = 'LOW RISK';
    }

    final percentStr = '${(score * 100).toStringAsFixed(1)}%';

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          percentStr,
          style: TextStyle(
            color: fg,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            fontFeatures: AppTheme.tabularFigures,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label ($percentStr)',
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFeatures: AppTheme.tabularFigures,
        ),
      ),
    );
  }
}

class AlertStatusBadge extends StatelessWidget {
  final String status;

  const AlertStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'open':
        bg = colors.riskCriticalBg;
        fg = colors.riskCritical;
        label = 'Open';
        break;
      case 'in_review':
        bg = colors.riskMediumBg;
        fg = colors.riskMedium;
        label = 'In Review';
        break;
      case 'resolved':
        bg = colors.riskLowBg;
        fg = colors.riskLow;
        label = 'Resolved';
        break;
      default:
        bg = colors.surfaceMuted;
        fg = colors.textSecondary;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class VerdictBadge extends StatelessWidget {
  final String verdict;

  const VerdictBadge({super.key, required this.verdict});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (verdict.toLowerCase()) {
      case 'confirmed_fraud':
        bg = colors.riskCriticalBg;
        fg = colors.riskCritical;
        label = 'Confirmed Fraud';
        icon = Icons.block_rounded;
        break;
      case 'false_positive':
        bg = colors.riskLowBg;
        fg = colors.riskLow;
        label = 'False Positive';
        icon = Icons.check_circle_outline_rounded;
        break;
      case 'needs_info':
        bg = colors.riskMediumBg;
        fg = colors.riskMedium;
        label = 'Needs Info';
        icon = Icons.schedule_rounded;
        break;
      default:
        bg = colors.surfaceMuted;
        fg = colors.textSecondary;
        label = verdict;
        icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
