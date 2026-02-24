import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/utils/app_strings.dart';

// Note: BannerSkeleton is defined in promo_banner_carousel.dart

/// Skeleton loader for content sections.
class SectionSkeleton extends StatelessWidget {
  const SectionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Container(
            width: 120,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        SizedBox(
          height: 290,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(end: 20),
            itemCount: 4,
            itemBuilder: (context, index) {
              return Container(
                width: 140,
                margin: const EdgeInsetsDirectional.only(start: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 190,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 16,
                      width: 100,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 70,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Skeleton loader for categories section.
class CategoriesSkeleton extends StatelessWidget {
  const CategoriesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Container(
            width: 100,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(end: 20),
            itemCount: 5,
            itemBuilder: (context, index) {
              return Container(
                width: 80,
                height: 44,
                margin: const EdgeInsetsDirectional.only(start: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(22),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Error state widget for sections with retry button.
class SectionError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const SectionError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodyMedium,
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: Text(AppStrings.retry),
            ),
          ],
        ),
      ),
    );
  }
}
