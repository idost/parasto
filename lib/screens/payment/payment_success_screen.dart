import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';

/// Payment success confirmation screen
/// Shows audiobook details and navigation options
class PaymentSuccessScreen extends StatelessWidget {
  final String audiobookTitle;
  final String? coverUrl;
  final int priceToman;
  final VoidCallback onGoToLibrary;
  final VoidCallback onStartListening;
  final bool isEbook;

  const PaymentSuccessScreen({
    super.key,
    required this.audiobookTitle,
    this.coverUrl,
    required this.priceToman,
    required this.onGoToLibrary,
    required this.onStartListening,
    this.isEbook = false,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Force user to use buttons
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(),

                  // Success icon with animation feel
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.check_circle,
                        size: 60,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Success title
                  const Text(
                    'خرید موفق!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Subtitle
                  const Text(
                    'کتاب به کتابخانه شما اضافه شد',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Book card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Cover
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: coverUrl != null
                              ? Image.network(
                                  coverUrl!,
                                  width: 60,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _buildCoverPlaceholder(),
                                )
                              : _buildCoverPlaceholder(),
                        ),
                        const SizedBox(width: 16),

                        // Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                audiobookTitle,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline,
                                    size: 16,
                                    color: AppColors.success,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    priceToman > 0
                                        ? _formatPrice(priceToman)
                                        : 'رایگان',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Action buttons
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: onStartListening,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text(
                        'شروع گوش دادن',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: onGoToLibrary,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.library_books_outlined),
                      label: const Text(
                        'رفتن به کتابخانه',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverPlaceholder() {
    return Container(
      width: 60,
      height: 80,
      color: AppColors.surfaceLight,
      child: const Center(
        child: Icon(
          Icons.headphones,
          color: AppColors.textTertiary,
          size: 24,
        ),
      ),
    );
  }

  String _formatPrice(int price) {
    // Price is stored as USD
    if (price < 1) {
      return '\$${price.toStringAsFixed(2)}';
    }
    return '\$${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)}';
  }
}
