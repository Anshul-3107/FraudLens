import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/summary.dart';
import '../providers/currency_provider.dart';

class MonthlySpendChart extends StatelessWidget {
  final List<MonthlySpend> monthlyData;
  final bool isSourceUsd;

  const MonthlySpendChart({
    super.key,
    required this.monthlyData,
    this.isSourceUsd = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final currencyProvider = context.watch<CurrencyProvider>();

    if (monthlyData.isEmpty) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        child: Text(
          'No monthly activity yet.',
          style: TextStyle(color: colors.textMuted, fontSize: 13),
        ),
      );
    }

    final data = monthlyData.length > 8
        ? monthlyData.sublist(monthlyData.length - 8)
        : monthlyData;

    double maxSpend = 100.0;
    final convertedTotals = <double>[];
    for (final m in data) {
      final displayTotal = isSourceUsd
          ? currencyProvider.convertFromUsd(m.total)
          : m.total;
      convertedTotals.add(displayTotal);
      if (displayTotal > maxSpend) maxSpend = displayTotal;
    }
    final maxY = maxSpend * 1.15;

    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), convertedTotals[i]));
    }

    final double safeMaxX = data.length <= 1
        ? 1.0
        : (data.length - 1).toDouble();

    return SizedBox(
      height: 170,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4 > 0 ? maxY / 4 : 25,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: colors.borderSubtle, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                interval: maxY / 4 > 0 ? maxY / 4 : 25,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      currencyProvider.formatCompact(value, isSourceUsd: false),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        fontFeatures: AppTheme.tabularFigures,
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (value == index && index >= 0 && index < data.length) {
                    final monthStr = data[index].month;
                    final parts = monthStr.split('-');
                    final label = parts.length == 2 && parts[0].length >= 4
                        ? '${parts[1]}/${parts[0].substring(2)}'
                        : monthStr;
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          fontFeatures: AppTheme.tabularFigures,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: safeMaxX,
          minY: 0,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: data.length > 2,
              curveSmoothness: 0.3,
              color: colors.tealPrimary,
              barWidth: 2.6,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: data.length <= 4,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                      radius: 3.5,
                      color: colors.tealPrimary,
                      strokeWidth: 2,
                      strokeColor: colors.surface,
                    ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colors.tealPrimary.withValues(
                      alpha: colors.isDark ? 0.24 : 0.14,
                    ),
                    colors.tealPrimary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategorySpendBreakdown extends StatelessWidget {
  final List<CategorySpend> categories;
  final bool isSourceUsd;

  const CategorySpendBreakdown({
    super.key,
    required this.categories,
    this.isSourceUsd = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final currencyProvider = context.watch<CurrencyProvider>();

    if (categories.isEmpty) {
      return Container(
        height: 90,
        alignment: Alignment.center,
        child: Text(
          'No category spending recorded yet.',
          style: TextStyle(color: colors.textMuted, fontSize: 13),
        ),
      );
    }

    double maxTotal = 1.0;
    for (final c in categories) {
      if (c.total > maxTotal) maxTotal = c.total;
    }

    final topCategories = categories.take(6).toList();

    return Column(
      children: topCategories.map((c) {
        final progress = (c.total / maxTotal).clamp(0.03, 1.0);
        final catColor = colors.getCategoryColor(c.category);
        final catBg = colors.getCategoryBg(c.category);
        final catIcon = colors.getCategoryIcon(c.category);
        final label = AppColors.friendlyCategoryName(c.category);
        final amountText = currencyProvider.format(
          c.total,
          isSourceUsd: isSourceUsd,
          decimalDigits: 0,
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: catBg,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(catIcon, size: 16, color: catColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 135),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            amountText,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              fontFeatures: AppTheme.tabularFigures,
                            ),
                            maxLines: 1,
                          ),
                        ),
                        Text(
                          '${NumberFormat.decimalPattern().format(c.count)} ${c.count == 1 ? 'payment' : 'payments'}',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: catBg,
                  valueColor: AlwaysStoppedAnimation<Color>(catColor),
                  minHeight: 4.5,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
