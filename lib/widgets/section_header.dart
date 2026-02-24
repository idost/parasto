import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/utils/app_strings.dart';

/// Unified section header for Parasto home/search screens
/// Displays section title with optional icon and "See All" button
///
/// Usage:
/// ```dart
/// SectionHeader(
///   title: 'پیشنهاد',
///   icon: Icons.auto_awesome_rounded,
///   onSeeAll: () => Navigator.push(...),
/// )
/// ```
class SectionHeader extends StatelessWidget {
  /// Section title text (e.g., "پیشنهاد", "تازه")
  final String title;

  /// Optional icon displayed before the title
  final IconData? icon;

  /// Callback when "See All" button is pressed
  /// If null, the "See All" button is hidden
  final VoidCallback? onSeeAll;

  /// Custom "See All" text (defaults to AppStrings.seeAll = "بیشتر")
  final String? seeAllText;

  /// Horizontal padding (defaults to AppDimensions.sectionPaddingH = 16)
  /// Use 20 for home_screen style (matches existing _SectionHeader)
  final double horizontalPadding;

  /// Top padding before the header (defaults to AppDimensions.sectionSpacingTop = 32)
  final double topPadding;

  /// Bottom padding after the header (defaults to AppDimensions.sectionSpacingBottom = 16)
  final double bottomPadding;

  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.onSeeAll,
    this.seeAllText,
    this.horizontalPadding = 20, // Match home_screen _SectionHeader
    this.topPadding = AppDimensions.sectionSpacingTop,
    this.bottomPadding = AppDimensions.sectionSpacingBottom,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        topPadding,
        horizontalPadding,
        bottomPadding,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Title with optional icon
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppDimensions.iconWithHeadline, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(
                title,
                style: AppTypography.sectionTitle,
              ),
            ],
          ),
          // "See All" button
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    seeAllText ?? AppStrings.seeAll,
                    style: AppTypography.labelMedium.copyWith(color: AppColors.primary),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(Icons.chevron_left_rounded, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
