import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';

/// Consistent empty state UI component
///
/// Features:
/// - Large icon with circular background
/// - Primary message and optional subtitle
/// - Optional action button (CTA)
/// - Customizable icon color
/// - Centered layout
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subtitle;
  final Widget? action;
  final Color? iconColor;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.subtitle,
    this.action,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? AppColors.textTertiary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: effectiveIconColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: effectiveIconColor.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
