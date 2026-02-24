import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/models/scheduled_feature.dart';
import 'package:myna/models/scheduled_feature_presentation.dart';
import 'package:myna/providers/scheduling_providers.dart';

/// Card widget for displaying a scheduled feature
class ScheduleCard extends ConsumerWidget {
  final ScheduledFeature schedule;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  const ScheduleCard({
    super.key,
    required this.schedule,
    this.onTap,
    this.onEdit,
  });

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: schedule.isActive
              ? schedule.color.withValues(alpha: 0.3)
              : AppColors.borderSubtle,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Cover image or icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: schedule.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  image: schedule.audiobookCoverUrl != null
                      ? DecorationImage(
                          image: NetworkImage(schedule.audiobookCoverUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: schedule.audiobookCoverUrl == null
                    ? Icon(
                        schedule.isMusic == true
                            ? Icons.music_note_rounded
                            : Icons.menu_book_rounded,
                        color: schedule.color,
                        size: 28,
                      )
                    : null,
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and badges
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            schedule.audiobookTitle ?? 'محتوای #${schedule.audiobookId}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Feature type badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: schedule.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                schedule.icon,
                                color: schedule.color,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                schedule.featureTypeLabel,
                                style: TextStyle(
                                  color: schedule.color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Date range
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatDate(schedule.startDate),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        if (schedule.endDate != null) ...[
                          const Text(
                            ' - ',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _formatDate(schedule.endDate!),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ] else ...[
                          const Text(
                            ' (بدون پایان)',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Status and remaining days
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: schedule.statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            schedule.statusLabel,
                            style: TextStyle(
                              color: schedule.statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (schedule.isPending) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${schedule.daysUntilStart} روز تا شروع',
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ] else if (schedule.isActive && schedule.daysRemaining != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${schedule.daysRemaining} روز باقی‌مانده',
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              if (schedule.status == ScheduleStatus.scheduled ||
                  schedule.status == ScheduleStatus.active)
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  onSelected: (action) => _handleAction(context, ref, action),
                  itemBuilder: (context) => [
                    if (onEdit != null)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('ویرایش'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'cancel',
                      child: Row(
                        children: [
                          Icon(Icons.cancel_rounded,
                              size: 18, color: AppColors.error),
                          SizedBox(width: 8),
                          Text('لغو'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'edit':
        onEdit?.call();
        break;
      case 'cancel':
        _showCancelDialog(context, ref);
        break;
    }
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.cancel_rounded, color: AppColors.error),
              SizedBox(width: 12),
              Text(
                'لغو زمان‌بندی',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Text(
            'آیا مطمئن هستید که می‌خواهید این زمان‌بندی را لغو کنید؟',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(schedulingActionsProvider.notifier).cancelSchedule(schedule.id);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('لغو زمان‌بندی'),
            ),
          ],
        ),
      ),
    );
  }
}
