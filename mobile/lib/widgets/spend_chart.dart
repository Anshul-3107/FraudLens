import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_theme.dart';
import '../models/summary.dart';

class MonthlySpendChart extends StatelessWidget {
  final List<MonthlySpend> monthlyData;

  const MonthlySpendChart({super.key, required this.monthlyData});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (monthlyData.isEmpty) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        child: Text(
          'No monthly spending data available.',
          style: TextStyle(color: colors.textMuted, fontSize: 12),
        ),
      );
    }

    final data = monthlyData.length > 8
        ? monthlyData.sublist(monthlyData.length - 8)
        : monthlyData;

    double maxSpend = 100.0;
    for (final m in data) {
      if (m.total > maxSpend) maxSpend = m.total;
    }
    final maxY = maxSpend * 1.15;

    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[i].total));
    }

    final currencyFormat = NumberFormat.compactSimpleCurrency();

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4 > 0 ? maxY / 4 : 25,
            getDrawingHorizontalLine: (value) => FlLine(
              color: colors.border,
              strokeWidth: 1,
              dashArray: const [3, 3],
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                interval: maxY / 4 > 0 ? maxY / 4 : 25,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return Text(
                    currencyFormat.format(value),
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < data.length) {
                    final monthStr = data[index].month;
                    final parts = monthStr.split('-');
                    final label = parts.length == 2
                        ? '${parts[1]}/${parts[0].substring(2)}'
                        : monthStr;
                    return Padding(
                      padding: const EdgeInsets.only(top: 5.0),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
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
          maxX: (data.length - 1).toDouble().clamp(0.0, 100.0),
          minY: 0,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: colors.tealPrimary,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                      radius: 3,
                      color: colors.tealPrimary,
                      strokeWidth: 1.5,
                      strokeColor: colors.surface,
                    ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: colors.tealPrimary.withValues(
                  alpha: colors.isDark ? 0.12 : 0.06,
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

  const CategorySpendBreakdown({super.key, required this.categories});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (categories.isEmpty) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        child: Text(
          'No category spending recorded yet.',
          style: TextStyle(color: colors.textMuted, fontSize: 12),
        ),
      );
    }

    double maxTotal = 1.0;
    for (final c in categories) {
      if (c.total > maxTotal) maxTotal = c.total;
    }

    final topCategories = categories.take(6).toList();
    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 0,
    );

    return Column(
      children: topCategories.map((c) {
        final progress = (c.total / maxTotal).clamp(0.02, 1.0);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      c.formattedCategory,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${currencyFormat.format(c.total)} (${c.count} txns)',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: colors.surfaceMuted,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.tealPrimary),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
