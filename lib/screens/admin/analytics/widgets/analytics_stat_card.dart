import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';

/// Large stat card for displaying key metrics in analytics
class AnalyticsStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final Color? color;

  const AnalyticsStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon with glow
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: effectiveColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: effectiveColor.withValues(alpha: 0.15),
                  blurRadius: 6,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: effectiveColor,
              size: 20,
            ),
          ),

          const SizedBox(height: 12),

          // Value (large)
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),

          const SizedBox(height: 4),

          // Label
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),

          // Optional subtitle
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                color: effectiveColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact inline stat for rows
class AnalyticsInlineStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const AnalyticsInlineStat({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: effectiveColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: effectiveColor,
            size: 16,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
