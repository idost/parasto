import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';

/// Premium card component for list items (users, audiobooks, tickets)
///
/// Features:
/// - Consistent styling with modern Parasto design
/// - Optional leading widget (avatar, icon, cover image)
/// - Title and subtitle support
/// - Badges for status/type indicators
/// - Action buttons/icons
/// - Tap interaction with ripple effect
/// - Accent color customization
class ContentCard extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final List<Widget>? badges;
  final List<Widget>? actions;
  final VoidCallback? onTap;
  final Color? accentColor;
  final EdgeInsets? padding;

  const ContentCard({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.badges,
    this.actions,
    this.onTap,
    this.accentColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccentColor = accentColor ?? AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.borderSubtle,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          splashColor: effectiveAccentColor.withValues(alpha: 0.1),
          highlightColor: effectiveAccentColor.withValues(alpha: 0.05),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: title),
                          if (badges != null && badges!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            ...badges!.map((badge) => Padding(
                                  padding: const EdgeInsetsDirectional.only(start: 4),
                                  child: badge,
                                )),
                          ],
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        subtitle!,
                      ],
                    ],
                  ),
                ),
                if (actions != null && actions!.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: actions!
                        .map((action) => Padding(
                              padding: const EdgeInsetsDirectional.only(start: 4),
                              child: action,
                            ))
                        .toList(),
                  ),
                ],
                if (onTap != null && (actions == null || actions!.isEmpty))
                  const Icon(
                    Icons.chevron_left,
                    color: AppColors.textTertiary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
