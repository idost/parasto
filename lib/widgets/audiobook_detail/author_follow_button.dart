import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/providers/author_follow_provider.dart';

/// Small follow/unfollow button for authors.
/// Extracted from audiobook_detail_screen.dart for better maintainability.
class AuthorFollowButton extends ConsumerWidget {
  final String authorName;

  const AuthorFollowButton({
    super.key,
    required this.authorName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followState = ref.watch(authorFollowProvider);
    final isFollowing = followState.isFollowing(authorName);

    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: GestureDetector(
        onTap: () {
          ref.read(authorFollowProvider.notifier).toggle(authorName);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isFollowing
                    ? 'دنبال نمی‌کنید: $authorName'
                    : 'دنبال می‌کنید: $authorName',
                textAlign: TextAlign.center,
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.surface,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isFollowing
                ? AppColors.primary.withAlpha(38)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFollowing
                  ? AppColors.primary.withAlpha(128)
                  : AppColors.surfaceLight,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isFollowing ? Icons.check_rounded : Icons.add_rounded,
                size: 14,
                color: isFollowing ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                isFollowing ? 'دنبال شده' : 'دنبال کردن',
                style: AppTypography.labelSmall.copyWith(
                  color: isFollowing ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: isFollowing ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
