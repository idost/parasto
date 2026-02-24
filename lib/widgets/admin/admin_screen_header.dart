import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';

/// Reusable header for admin screens
/// Provides consistent design across all admin pages
class AdminScreenHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  const AdminScreenHeader({
    super.key,
    required this.title,
    required this.icon,
    this.actions,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border(
          bottom: BorderSide(
            color: AppColors.borderSubtle,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button if onBack is provided
          if (onBack != null) ...[
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              onPressed: onBack,
              tooltip: 'بازگشت',
            ),
            const SizedBox(width: 8),
          ],

          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 8,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),

          // Title
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Actions
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}
