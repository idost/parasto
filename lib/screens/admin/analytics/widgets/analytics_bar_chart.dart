import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';

/// Horizontal bar chart widget for displaying rankings
/// Shows items with progress bars relative to the maximum value
class AnalyticsBarChart extends StatelessWidget {
  final List<BarChartItem> items;
  final int maxItems;
  final String valueLabel;

  const AnalyticsBarChart({
    super.key,
    required this.items,
    this.maxItems = 5,
    this.valueLabel = '',
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'داده‌ای موجود نیست',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final displayItems = items.take(maxItems).toList();
    final maxValue = displayItems.isEmpty ? 1.0 : displayItems.first.value;

    return Column(
      children: displayItems.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final percentage = maxValue > 0 ? item.value / maxValue : 0.0;
        final isFirst = index == 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              // Rank number
              SizedBox(
                width: 28,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: isFirst ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: isFirst ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and subtitle
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: isFirst ? FontWeight.w600 : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.subtitle != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            item.subtitle!,
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Progress bar
                    Stack(
                      children: [
                        // Background
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        // Fill
                        FractionallySizedBox(
                          widthFactor: percentage.clamp(0.0, 1.0),
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isFirst
                                    ? [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)]
                                    : [AppColors.secondary, AppColors.secondary.withValues(alpha: 0.7)],
                              ),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: isFirst
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(alpha: 0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Value
              Text(
                '${item.formattedValue}${valueLabel.isNotEmpty ? ' $valueLabel' : ''}',
                style: TextStyle(
                  color: isFirst ? AppColors.primary : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: isFirst ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Data class for bar chart items
class BarChartItem {
  final String title;
  final String? subtitle;
  final double value;
  final String formattedValue;

  const BarChartItem({
    required this.title,
    this.subtitle,
    required this.value,
    required this.formattedValue,
  });
}
