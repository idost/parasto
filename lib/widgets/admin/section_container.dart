import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';

/// Container with gradient header for grouped content
///
/// Features:
/// - Modern Parasto design with gradient header
/// - Icon with glow effect
/// - Optional action buttons in header
/// - Consistent shadows and borders
/// - Fully customizable accent color
class SectionContainer extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? accentColor;
  final Widget child;
  final List<Widget>? actions;

  const SectionContainer({
    super.key,
    required this.title,
    required this.icon,
    this.accentColor,
    required this.child,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.primary;

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with gradient
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.06),
                  color.withValues(alpha: 0.02),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.md),
                topRight: Radius.circular(AppRadius.md),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                if (actions != null) ...actions!,
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}
