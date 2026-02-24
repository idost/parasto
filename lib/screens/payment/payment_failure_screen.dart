import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';

/// Payment failure screen
/// Shows error message with retry option
class PaymentFailureScreen extends StatelessWidget {
  final String audiobookTitle;
  final String? errorMessage;
  final bool wasCancelled;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const PaymentFailureScreen({
    super.key,
    required this.audiobookTitle,
    this.errorMessage,
    this.wasCancelled = false,
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Back button
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: onBack,
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),

                const Spacer(),

                // Error/Cancel icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: wasCancelled
                        ? AppColors.warning.withValues(alpha: 0.15)
                        : AppColors.error.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      wasCancelled ? Icons.cancel_outlined : Icons.error_outline,
                      size: 60,
                      color: wasCancelled ? AppColors.warning : AppColors.error,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  wasCancelled ? 'پرداخت لغو شد' : 'خطا در پرداخت',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: wasCancelled ? AppColors.warning : AppColors.error,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Message
                Text(
                  wasCancelled
                      ? 'پرداخت توسط شما لغو شد.'
                      : errorMessage ?? 'پرداخت انجام نشد. لطفاً دوباره تلاش کنید.',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Book title
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.headphones,
                        size: 20,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          audiobookTitle,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Info text
                if (!wasCancelled)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Text(
                      'اگر مبلغی از حساب شما کسر شده است، طی ۷۲ ساعت بازگردانده می‌شود.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Action buttons
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.refresh),
                    label: const Text(
                      'تلاش مجدد',
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
                  child: OutlinedButton(
                    onPressed: onBack,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.surfaceLight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'بازگشت',
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
    );
  }
}
