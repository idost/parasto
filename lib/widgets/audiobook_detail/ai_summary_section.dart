import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';

/// AI-generated summary section widget for audiobook details.
/// Extracted from audiobook_detail_screen.dart for better maintainability.
///
/// This widget displays a 2-line AI summary with states for:
/// - Loading
/// - Summary display
/// - Rate limited
/// - Error
/// - Initial (generate button)
class AiSummarySection extends StatelessWidget {
  /// The AI-generated summary text, null if not yet fetched
  final String? summary;

  /// Whether the summary is currently being loaded
  final bool isLoading;

  /// Whether an error occurred while fetching the summary
  final bool hasError;

  /// Whether the user has hit the rate limit
  final bool isRateLimited;

  /// Optional error details (only shown in debug mode)
  final String? errorDetails;

  /// Callback to fetch/refresh the summary
  final VoidCallback onFetch;

  /// Callback to force refresh the summary
  final VoidCallback onRefresh;

  const AiSummarySection({
    super.key,
    this.summary,
    required this.isLoading,
    required this.hasError,
    required this.isRateLimited,
    this.errorDetails,
    required this.onFetch,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            _buildHeader(),
            const SizedBox(height: 16),
            // Content area
            _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: AppColors.primary,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'خلاصهٔ دوخطی',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'با هوش مصنوعی',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        // Refresh button (only show if summary exists)
        if (summary != null && !isLoading)
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            color: AppColors.textTertiary,
            tooltip: 'به‌روزرسانی خلاصه',
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return _buildLoadingState();
    }

    if (summary != null) {
      return _buildSummaryDisplay();
    }

    if (isRateLimited) {
      return _buildRateLimitedState();
    }

    if (hasError) {
      return _buildErrorState();
    }

    return _buildInitialState();
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'در حال ساخت خلاصه...',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryDisplay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        summary!,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          height: 1.7,
        ),
        textAlign: TextAlign.right,
      ),
    );
  }

  Widget _buildRateLimitedState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'شما به سقف درخواست روزانه رسیده‌اید.\nلطفاً فردا دوباره امتحان کنید.',
        style: TextStyle(
          color: AppColors.textTertiary,
          fontSize: 13,
          height: 1.6,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildErrorState() {
    return Column(
      children: [
        const Text(
          'مشکلی در ساخت خلاصه پیش آمد.',
          style: TextStyle(
            color: AppColors.textTertiary,
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
        if (!kReleaseMode && errorDetails != null) ...[
          const SizedBox(height: 6),
          Text(
            errorDetails!,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onFetch,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('تلاش مجدد'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: OutlinedButton.icon(
        onPressed: onFetch,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: const Icon(Icons.auto_awesome_rounded, size: 18),
        label: const Text('نمایش خلاصه'),
      ),
    );
  }
}
