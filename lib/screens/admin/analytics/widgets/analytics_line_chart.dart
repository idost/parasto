import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:myna/models/analytics_models.dart';
import 'package:myna/theme/app_theme.dart';

/// Line chart widget for displaying daily listening trends
class AnalyticsLineChart extends StatelessWidget {
  final List<DailyListening> data;
  final String yAxisLabel;
  final double height;

  const AnalyticsLineChart({
    super.key,
    required this.data,
    this.yAxisLabel = 'ساعت',
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Container(
        height: height,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: const Center(
          child: Text(
            'داده‌ای موجود نیست',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final spots = data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.hours);
    }).toList();

    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: _calculateYInterval(spots),
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.borderSubtle,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: _calculateYInterval(spots),
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: _calculateXInterval(data.length),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= data.length) return const SizedBox();
                  final date = data[index].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${date.month}/${date.day}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minY: 0,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: AppColors.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: data.length <= 14, // Show dots only for small datasets
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: AppColors.primary,
                    strokeWidth: 2,
                    strokeColor: AppColors.surface,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.2),
                    AppColors.primary.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.surfaceLight,
              tooltipRoundedRadius: 8,
              tooltipPadding: const EdgeInsets.all(8),
              getTooltipItems: (spots) => spots.map((spot) {
                final date = data[spot.x.toInt()].date;
                return LineTooltipItem(
                  '${date.year}/${date.month}/${date.day}\n${spot.y.toStringAsFixed(1)} $yAxisLabel',
                  const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                  ),
                );
              }).toList(),
            ),
            handleBuiltInTouches: true,
          ),
        ),
      ),
    );
  }

  double _calculateYInterval(List<FlSpot> spots) {
    if (spots.isEmpty) return 1;
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    if (maxY <= 0) return 1;
    if (maxY <= 5) return 1;
    if (maxY <= 10) return 2;
    if (maxY <= 50) return 10;
    if (maxY <= 100) return 20;
    if (maxY <= 500) return 100;
    return (maxY / 5).ceilToDouble();
  }

  double _calculateXInterval(int dataLength) {
    if (dataLength <= 7) return 1;
    if (dataLength <= 14) return 2;
    if (dataLength <= 30) return 5;
    if (dataLength <= 60) return 10;
    return 15;
  }
}
