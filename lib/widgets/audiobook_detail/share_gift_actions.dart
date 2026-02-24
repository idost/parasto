import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';

/// Share and Gift action buttons row.
/// Extracted from audiobook_detail_screen.dart for better maintainability.
class ShareGiftActions extends StatelessWidget {
  final VoidCallback onShare;
  final VoidCallback onGift;

  const ShareGiftActions({
    super.key,
    required this.onShare,
    required this.onGift,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Share Button
        Flexible(
          child: _ActionButton(
            icon: Icons.share_rounded,
            label: 'اشتراک‌گذاری',
            onTap: onShare,
          ),
        ),
        const SizedBox(width: 24),
        // Gift Button
        Flexible(
          child: _ActionButton(
            icon: Icons.card_giftcard_rounded,
            label: 'هدیه دادن',
            onTap: onGift,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
