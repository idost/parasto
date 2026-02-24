import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/utils/farsi_utils.dart';
import 'package:myna/utils/app_strings.dart';
import 'package:myna/providers/home_providers.dart' show ListeningStats;

/// Section showing user's listening statistics.
/// Extracted from home_screen.dart for better maintainability.
class ListeningStatsSection extends StatelessWidget {
  final ListeningStats stats;

  const ListeningStatsSection({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final hasStats = stats.totalListenTimeSeconds > 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.secondary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                hasStats ? Icons.bar_chart_rounded : Icons.headphones_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                hasStats ? AppStrings.yourListeningStats : AppStrings.startListening,
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats Row or Encouragement Message
          if (hasStats)
            Row(
              children: [
                // Total Listen Time
                Expanded(
                  child: _StatItem(
                    icon: Icons.headphones_rounded,
                    value: stats.formattedTotalTime,
                    label: AppStrings.listeningTime,
                    color: AppColors.primary,
                  ),
                ),
                // Books Completed
                Expanded(
                  child: _StatItem(
                    icon: Icons.task_alt_rounded,
                    value: FarsiUtils.toFarsiDigits(stats.booksCompleted),
                    label: AppStrings.booksFinished,
                    color: AppColors.success,
                  ),
                ),
                // Current Streak
                if (stats.currentStreak > 0)
                  Expanded(
                    child: _StatItem(
                      icon: Icons.whatshot_rounded,
                      value: AppStrings.streakDays(stats.currentStreak),
                      label: AppStrings.streakRecord,
                      color: AppColors.warning,
                    ),
                  ),
              ],
            )
          else
            Text(
              AppStrings.startListeningMessage,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textTertiary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
