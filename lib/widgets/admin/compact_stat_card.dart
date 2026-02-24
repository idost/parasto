import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';

/// Compact metric card for admin dashboard stats bar
/// Matches Parasto's warm, poetic design language
class CompactStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final String? trend; // Optional trend indicator (e.g., "+5%", "-2%")
  final VoidCallback? onTap;

  const CompactStatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.trend,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isTappable = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        splashColor: color.withValues(alpha: 0.1),
        highlightColor: color.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            // Parasto surface with subtle elevation
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            // Subtle border matching Parasto style
            border: Border.all(
              color: AppColors.borderSubtle,
              width: 1,
            ),
            // Soft shadow for depth (like audiobook cards)
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with warm glow effect
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  // Warm muted background
                  color: color.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  // Subtle inner glow
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.15),
                      blurRadius: 12,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(height: 10),

              // Value - large and bold with proper Parasto typography
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: color,
                          height: 1.0,
                          // Subtle text shadow for depth
                          shadows: [
                            Shadow(
                              color: color.withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (trend != null) ...[
                    const SizedBox(width: 4),
                    _buildTrendIndicator(trend!),
                  ],
                ],
              ),
              const SizedBox(height: 6),

              // Label - Parasto text secondary style
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              // Subtle tap indicator with warm color
              if (isTappable) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: AppRadius.small,
                  ),
                  child: Icon(
                    Icons.arrow_back,
                    size: 12,
                    color: color,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendIndicator(String trendText) {
    final isPositive = trendText.startsWith('+');
    final isNegative = trendText.startsWith('-');

    Color trendColor;
    IconData trendIcon;

    if (isPositive) {
      trendColor = AppColors.success;
      trendIcon = Icons.arrow_upward;
    } else if (isNegative) {
      trendColor = AppColors.error;
      trendIcon = Icons.arrow_downward;
    } else {
      trendColor = AppColors.textSecondary;
      trendIcon = Icons.remove;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: trendColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(
          color: trendColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            trendIcon,
            size: 10,
            color: trendColor,
          ),
          const SizedBox(width: 2),
          Text(
            trendText.replaceAll('+', '').replaceAll('-', ''),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: trendColor,
            ),
          ),
        ],
      ),
    );
  }
}
