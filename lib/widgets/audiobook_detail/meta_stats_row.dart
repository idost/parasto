import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/utils/farsi_utils.dart';

/// Stats row widget showing rating, duration, and chapter count.
/// Extracted from audiobook_detail_screen.dart for better maintainability.
class MetaStatsRow extends StatelessWidget {
  final double avgRating;
  final int reviewCount;
  final int totalDurationSeconds;
  final int chapterCount;
  final bool isMusic;

  const MetaStatsRow({
    super.key,
    required this.avgRating,
    required this.reviewCount,
    required this.totalDurationSeconds,
    required this.chapterCount,
    required this.isMusic,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Rating
          Expanded(
            child: _MetaItem(
              icon: Icons.star_rounded,
              iconColor: AppColors.warning,
              value: avgRating > 0 ? FarsiUtils.toFarsiDigits(avgRating.toStringAsFixed(1)) : '-',
              label: '${FarsiUtils.toFarsiDigits(reviewCount)} نظر',
            ),
          ),
          const SizedBox(width: 24),
          _MetaDivider(),
          const SizedBox(width: 24),
          // Duration
          Expanded(
            child: _MetaItem(
              icon: Icons.schedule_rounded,
              iconColor: AppColors.primary,
              value: totalDurationSeconds > 0
                  ? FarsiUtils.formatDurationLongFarsi(totalDurationSeconds)
                  : '-',
              label: 'مدت زمان',
            ),
          ),
          const SizedBox(width: 24),
          _MetaDivider(),
          const SizedBox(width: 24),
          // Chapters
          Expanded(
            child: _MetaItem(
              icon: Icons.list_rounded,
              iconColor: AppColors.secondary,
              value: chapterCount > 0 ? FarsiUtils.toFarsiDigits(chapterCount) : '-',
              label: isMusic ? 'آهنگ' : 'فصل',
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _MetaItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.labelSmall,
        ),
      ],
    );
  }
}

class _MetaDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: AppColors.surfaceLight,
    );
  }
}
