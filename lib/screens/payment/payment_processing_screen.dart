import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';

/// Full-screen payment processing indicator
/// Shown while Stripe payment is being processed
class PaymentProcessingScreen extends StatelessWidget {
  final String audiobookTitle;
  final VoidCallback? onCancel;

  const PaymentProcessingScreen({
    super.key,
    required this.audiobookTitle,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent back button during payment
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated payment icon
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.payment,
                          size: 48,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Loading indicator
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Processing text
                    const Text(
                      'در حال پردازش پرداخت...',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),

                    // Book title
                    Text(
                      audiobookTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Info text
                    const Text(
                      'لطفاً صبر کنید و از بستن برنامه خودداری کنید',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // Cancel button (optional)
                    if (onCancel != null)
                      TextButton(
                        onPressed: onCancel,
                        child: const Text(
                          'انصراف',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
