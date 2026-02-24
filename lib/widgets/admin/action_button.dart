import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';

/// Navigation and quick action button component
///
/// Features:
/// - Icon with colored background and glow effect
/// - Label text with proper typography
/// - Chevron indicator for navigation
/// - Ripple effect on tap
/// - Consistent styling across all admin screens
class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: color.withValues(alpha: 0.1),
        highlightColor: color.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Icon with colored background and glow
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.15),
                      blurRadius: 6,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              // Chevron with color hint
              Icon(
                Icons.chevron_left_rounded,
                color: color.withValues(alpha: 0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
