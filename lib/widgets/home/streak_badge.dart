import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/utils/farsi_utils.dart';

/// Badge displaying user's listening streak count.
/// Shows fire icon with streak number.
class StreakBadge extends StatelessWidget {
  final int streak;

  const StreakBadge({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.whatshot_rounded,
              size: 18,
              color: AppColors.warning,
            ),
            const SizedBox(width: 4),
            Text(
              FarsiUtils.toFarsiDigits(streak),
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.warning,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
