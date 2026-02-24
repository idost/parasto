import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/models/narrator_request.dart';
import 'package:myna/utils/farsi_utils.dart';
import 'package:myna/providers/app_mode_provider.dart';

/// Card displaying the status of a user's narrator request
///
/// Shows:
/// - Current status (pending/approved/rejected)
/// - Submission date
/// - Admin feedback (if rejected)
/// - Appropriate icon and colors
class NarratorRequestStatusCard extends ConsumerWidget {
  final NarratorRequest request;

  const NarratorRequestStatusCard({
    required this.request,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusInfo = _getStatusInfo();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: statusInfo.color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusInfo.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: statusInfo.color.withValues(alpha: 0.2),
                      blurRadius: 8,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Icon(
                  statusInfo.icon,
                  color: statusInfo.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'درخواست گویندگی',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusInfo.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        request.status.label,
                        style: TextStyle(
                          color: statusInfo.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Status message
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusInfo.message,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),

          // Submission date
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 6),
              Text(
                'تاریخ ثبت: ${_formatDate(request.createdAt)}',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          // Switch to Narrator Mode button (if approved)
          if (request.status == NarratorRequestStatus.approved) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Switch to narrator mode
                  ref.read(appModeProvider.notifier).state = AppMode.narrator;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('به حالت گوینده تغییر کردید!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                },
                icon: const Icon(Icons.mic_rounded, color: Colors.white),
                label: const Text('ورود به پنل گوینده'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
          ],

          // Admin feedback (if rejected)
          if (request.status == NarratorRequestStatus.rejected && request.adminFeedback != null) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.borderSubtle),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.message_outlined, size: 16, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Text(
                  'بازخورد مدیر:',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
              ),
              child: Text(
                request.adminFeedback!,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  _StatusInfo _getStatusInfo() {
    switch (request.status) {
      case NarratorRequestStatus.pending:
        return _StatusInfo(
          icon: Icons.hourglass_empty_rounded,
          color: AppColors.warning,
          message: 'درخواست شما در صف بررسی قرار دارد. پس از بررسی توسط مدیران، نتیجه به شما اطلاع داده خواهد شد.',
        );
      case NarratorRequestStatus.approved:
        return _StatusInfo(
          icon: Icons.check_circle_rounded,
          color: AppColors.success,
          message: 'تبریک! درخواست شما تأیید شد و اکنون می‌توانید به عنوان گوینده فعالیت کنید.',
        );
      case NarratorRequestStatus.rejected:
        return _StatusInfo(
          icon: Icons.cancel_rounded,
          color: AppColors.error,
          message: 'متأسفانه درخواست شما تأیید نشد. می‌توانید مجدداً درخواست دهید.',
        );
    }
  }

  String _formatDate(DateTime date) {
    final year = FarsiUtils.toFarsiDigits(date.year.toString());
    final month = FarsiUtils.toFarsiDigits(date.month.toString().padLeft(2, '0'));
    final day = FarsiUtils.toFarsiDigits(date.day.toString().padLeft(2, '0'));
    return '$year/$month/$day';
  }
}

class _StatusInfo {
  final IconData icon;
  final Color color;
  final String message;

  const _StatusInfo({
    required this.icon,
    required this.color,
    required this.message,
  });
}
