import 'package:flutter/material.dart';

import '../config/app_theme.dart';

class FintechLoadingIndicator extends StatelessWidget {
  final String? label;

  const FintechLoadingIndicator({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(colors.tealPrimary),
              ),
            ),
            if (label != null) ...[
              const SizedBox(height: 12),
              Text(
                label!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
