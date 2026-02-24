import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';

/// Reusable error view widget for consistent error display across the app.
///
/// Use this for:
/// - Network errors
/// - Data loading failures
/// - Empty states with error context
class ErrorView extends StatelessWidget {
  final String message;
  final String? details;
  final VoidCallback? onRetry;
  final IconData icon;
  final bool compact;

  const ErrorView({
    super.key,
    required this.message,
    this.details,
    this.onRetry,
    this.icon = Icons.error_outline_rounded,
    this.compact = false,
  });

  /// Factory for network-related errors
  factory ErrorView.network({
    VoidCallback? onRetry,
    bool compact = false,
  }) {
    return ErrorView(
      message: 'خطا در اتصال به اینترنت',
      details: 'لطفاً اتصال خود را بررسی کنید',
      icon: Icons.wifi_off_rounded,
      onRetry: onRetry,
      compact: compact,
    );
  }

  /// Factory for data loading errors
  factory ErrorView.load({
    String? itemName,
    VoidCallback? onRetry,
    bool compact = false,
  }) {
    return ErrorView(
      message: itemName != null
          ? 'خطا در بارگذاری $itemName'
          : 'خطا در بارگذاری اطلاعات',
      icon: Icons.cloud_off_rounded,
      onRetry: onRetry,
      compact: compact,
    );
  }

  /// Factory for generic server errors
  factory ErrorView.server({
    VoidCallback? onRetry,
    bool compact = false,
  }) {
    return ErrorView(
      message: 'خطای سرور',
      details: 'لطفاً دوباره تلاش کنید',
      icon: Icons.cloud_off_rounded,
      onRetry: onRetry,
      compact: compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompact();
    }
    return _buildFull();
  }

  Widget _buildFull() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (details != null) ...[
              const SizedBox(height: 8),
              Text(
                details!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('تلاش مجدد'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompact() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.error, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (details != null)
                  Text(
                    details!,
                    style: TextStyle(
                      color: AppColors.error.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (onRetry != null)
            IconButton(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, color: AppColors.error),
              tooltip: 'تلاش مجدد',
            ),
        ],
      ),
    );
  }
}
