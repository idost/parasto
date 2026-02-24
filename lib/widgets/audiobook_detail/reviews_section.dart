import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/utils/farsi_utils.dart';
import 'package:myna/widgets/review/rating_stars.dart';
import 'package:myna/widgets/review/review_card.dart';

/// Reviews section widget for audiobook detail screen.
/// Shows rating summary and review list with ability to write a review.
/// Extracted from audiobook_detail_screen.dart for better maintainability.
class ReviewsSection extends StatelessWidget {
  final double avgRating;
  final int reviewCount;
  final List<Map<String, dynamic>> reviews;
  final bool isOwned;
  final VoidCallback onViewAll;
  final VoidCallback onWriteReview;

  const ReviewsSection({
    super.key,
    required this.avgRating,
    required this.reviewCount,
    required this.reviews,
    required this.isOwned,
    required this.onViewAll,
    required this.onWriteReview,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'نظرات شنوندگان',
                style: AppTypography.sectionTitle,
              ),
              TextButton(
                onPressed: onViewAll,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('مشاهده همه'),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_left_rounded, size: 18),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Content
          Column(
            children: [
              // Rating Summary
              _buildRatingSummary(context),
              const SizedBox(height: 16),

              // Reviews List
              if (reviews.isEmpty)
                _buildEmptyState()
              else
                ...List.generate(reviews.length, (i) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: i < reviews.length - 1 ? 12 : 0),
                    child: ReviewCard(review: reviews[i]),
                  );
                }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSummary(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                avgRating > 0 ? FarsiUtils.toFarsiDigits(avgRating.toStringAsFixed(1)) : '-',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              RatingStars(rating: avgRating, size: 18),
              const SizedBox(height: 4),
              Text(
                '${FarsiUtils.toFarsiDigits(reviewCount)} نظر',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: isOwned
                ? OutlinedButton.icon(
                    onPressed: onWriteReview,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.rate_review_rounded, size: 20),
                    label: const Text('نوشتن نظر'),
                  )
                : const Text(
                    'برای ثبت نظر، ابتدا کتاب را تهیه کنید',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 40, color: AppColors.textTertiary),
            SizedBox(height: 12),
            Text(
              'هنوز نظری ثبت نشده',
              style: TextStyle(color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
