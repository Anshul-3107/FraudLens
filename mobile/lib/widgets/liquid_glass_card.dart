import 'dart:ui';

import 'package:flutter/material.dart';

import '../config/app_theme.dart';

/// A reusable card widget that provides a subtle, refined liquid glass (frosted acrylic)
/// effect using BackdropFilter, light-sheen refraction gradients, and a frosted hairline border.
class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blurSigma;
  final Color? tintColor;
  final double? opacity;
  final Border? customBorder;
  final VoidCallback? onTap;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 16,
    this.blurSigma = 7.0, // subtle, refined frosted glass
    this.tintColor,
    this.opacity,
    this.customBorder,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final effectiveBase = tintColor ?? colors.surface;
    final topAlpha = opacity ?? (colors.isDark ? 0.78 : 0.85);
    final bottomAlpha = (topAlpha - 0.12).clamp(0.40, 0.95);

    final border =
        customBorder ??
        Border.all(
          color: colors.isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.65),
          width: 1.0,
        );

    Widget cardBody = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            effectiveBase.withValues(alpha: topAlpha),
            effectiveBase.withValues(alpha: bottomAlpha),
          ],
        ),
        border: border,
        boxShadow: colors.cardShadow,
      ),
      child: child,
    );

    if (onTap != null) {
      cardBody = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: colors.primary.withValues(alpha: 0.1),
          highlightColor: colors.primary.withValues(alpha: 0.05),
          child: cardBody,
        ),
      );
    }

    Widget glass = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: cardBody,
      ),
    );

    if (margin != null) {
      glass = Padding(padding: margin!, child: glass);
    }

    return glass;
  }
}
