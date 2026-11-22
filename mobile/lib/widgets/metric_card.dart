import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import 'liquid_glass_card.dart';

class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final Color? iconBg;
  final Color? accentColor;
  final VoidCallback? onTap;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    this.iconColor,
    this.iconBg,
    this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final effectiveAccent = accentColor ?? iconColor ?? colors.tealPrimary;
    final effectiveIconColor = iconColor ?? effectiveAccent;
    final effectiveIconBg = iconBg ??
        (colors.isDark
            ? effectiveAccent.withValues(alpha: 0.16)
            : effectiveAccent.withValues(alpha: 0.10));

    return LiquidGlassCard(
      onTap: onTap,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: effectiveIconBg,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: effectiveIconColor.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Icon(icon, size: 16, color: effectiveIconColor),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(
                subtitle!,
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      );
    }
  }
