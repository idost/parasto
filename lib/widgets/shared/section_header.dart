import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/utils/app_strings.dart';

/// Reusable section header for home screen carousels and library sections.
///
/// Shows a title with optional leading icon and trailing "مشاهده همه" (See All) link.
/// RTL-safe: uses [EdgeInsetsDirectional] for padding.
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  final IconData? icon;

  const SectionHeader({
    super.key,
    required this.title,
    this.onSeeAll,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 24, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Title with optional icon
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 22, color: AppColors.primary),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    title,
                    style: AppTypography.sectionTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // "See All" link (trailing)
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppStrings.seeAll,
                    style: AppTypography.labelMedium
                        .copyWith(color: AppColors.primary, fontSize: 13),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_left_rounded, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
