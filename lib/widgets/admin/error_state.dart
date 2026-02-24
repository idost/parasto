import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';

/// Consistent error state UI component
///
/// Features:
/// - Error icon with red glow effect
/// - Error message and optional details
/// - Retry button with modern styling
/// - Centered layout
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String? errorDetails;

  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.errorDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.error.withValues(alpha: 0.2),
                    blurRadius: 12,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
            if (errorDetails != null) ...[
              const SizedBox(height: 8),
              Text(
                errorDetails!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('تلاش مجدد'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
