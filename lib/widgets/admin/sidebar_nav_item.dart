import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';

/// Individual navigation item for admin sidebar
class SidebarNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final bool isActive;
  final bool isCollapsed;
  final int? badge;
  final VoidCallback onTap;

  const SidebarNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.route,
    required this.isActive,
    required this.isCollapsed,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            height: 48,
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 0 : 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: isActive
                  ? Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1,
                    )
                  : null,
            ),
            child: isCollapsed
                ? _buildCollapsedContent()
                : _buildExpandedContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedContent() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          icon,
          size: 24,
          color: isActive ? AppColors.primary : AppColors.textSecondary,
        ),
        if (badge != null && badge! > 0)
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Center(
                child: Text(
                  badge! > 99 ? '99+' : badge.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildExpandedContent() {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isActive ? AppColors.primary : AppColors.textSecondary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive ? AppColors.primary : AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (badge != null && badge! > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: const BoxConstraints(
              minWidth: 20,
              minHeight: 20,
            ),
            child: Center(
              child: Text(
                badge! > 99 ? '99+' : badge.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
