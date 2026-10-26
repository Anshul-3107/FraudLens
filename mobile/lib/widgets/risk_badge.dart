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
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: fg.withValues(alpha: 0.25), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              percentStr,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label ($percentStr)',
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
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
        icon = Icons.help_outline_rounded;
        break;
      default:
        bg = colors.surfaceMuted;
        fg = colors.textSecondary;
        label = verdict;
        icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.2), width: 1),
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
