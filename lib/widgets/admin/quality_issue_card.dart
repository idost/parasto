import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/models/quality_issue.dart';
import 'package:myna/models/quality_issue_presentation.dart';
import 'package:myna/providers/quality_providers.dart';
import 'package:myna/utils/farsi_utils.dart';

/// Card widget for displaying a quality issue
class QualityIssueCard extends ConsumerWidget {
  final QualityIssue issue;
  final VoidCallback? onTap;
  final bool showAudiobookInfo;

  const QualityIssueCard({
    super.key,
    required this.issue,
    this.onTap,
    this.showAudiobookInfo = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: issue.status == QualityIssueStatus.open
              ? issue.color.withValues(alpha: 0.3)
              : AppColors.borderSubtle,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Severity icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: issue.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      issue.icon,
                      color: issue.color,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Type and severity badges
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: issue.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                issue.typeLabel,
                                style: TextStyle(
                                  color: issue.color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: issue.statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                issue.statusLabel,
                                style: TextStyle(
                                  color: issue.statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          issue.message,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action menu
                  if (issue.status == QualityIssueStatus.open)
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      onSelected: (action) => _handleAction(context, ref, action),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'resolve',
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  size: 18, color: AppColors.success),
                              SizedBox(width: 8),
                              Text('حل شده'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'ignore',
                          child: Row(
                            children: [
                              Icon(Icons.visibility_off_rounded,
                                  size: 18, color: AppColors.textTertiary),
                              SizedBox(width: 8),
                              Text('نادیده گرفتن'),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    IconButton(
                      icon: const Icon(
                        Icons.replay_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: () => _handleAction(context, ref, 'reopen'),
                      tooltip: 'بازگشایی مجدد',
                    ),
                ],
              ),

              // Details if available
              if (issue.details.isNotEmpty &&
                  issue.status == QualityIssueStatus.open) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _buildDetails(),
                ),
              ],

              // Resolution note if resolved/ignored
              if (issue.resolutionNote != null &&
                  issue.status != QualityIssueStatus.open) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.notes_rounded,
                      size: 14,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        issue.resolutionNote!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetails() {
    final widgets = <Widget>[];

    // Missing fields
    if (issue.details['missing_fields'] != null) {
      final fields = (issue.details['missing_fields'] as List<dynamic>)
          .map((e) => e.toString())
          .toList();
      widgets.add(
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: fields
              .map((field) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      field,
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ))
              .toList(),
        ),
      );
    }

    // Duplicate IDs
    if (issue.details['duplicate_ids'] != null) {
      final ids = issue.details['duplicate_ids'] as List<dynamic>;
      widgets.add(
        Text(
          'شناسه‌های تکراری: ${ids.join('، ')}',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      );
    }

    // Duration
    if (issue.details['duration_seconds'] != null) {
      final seconds = issue.details['duration_seconds'] as int;
      final minutes = (seconds / 60).floor();
      final hours = (minutes / 60).floor();
      final displayMinutes = minutes % 60;

      String duration;
      if (hours > 0) {
        duration = '${FarsiUtils.toFarsiDigits(hours)} ساعت و ${FarsiUtils.toFarsiDigits(displayMinutes)} دقیقه';
      } else {
        duration = '${FarsiUtils.toFarsiDigits(minutes)} دقیقه';
      }

      widgets.add(
        Text(
          'مدت زمان: $duration',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      );
    }

    if (widgets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'resolve':
        _showResolveDialog(context, ref);
        break;
      case 'ignore':
        _showIgnoreDialog(context, ref);
        break;
      case 'reopen':
        ref.read(qualityActionsProvider.notifier).reopenIssue(issue.id);
        break;
    }
  }

  void _showResolveDialog(BuildContext context, WidgetRef ref) {
    final noteController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.success),
              SizedBox(width: 12),
              Text(
                'علامت‌گذاری به عنوان حل شده',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  hintText: 'یادداشت (اختیاری)',
                  hintStyle: const TextStyle(color: AppColors.textTertiary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.borderSubtle),
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(qualityActionsProvider.notifier).resolveIssue(
                      issue.id,
                      note: noteController.text.isNotEmpty
                          ? noteController.text
                          : null,
                    );
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
              child: const Text('تأیید'),
            ),
          ],
        ),
      ),
    );
  }

  void _showIgnoreDialog(BuildContext context, WidgetRef ref) {
    final noteController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.visibility_off_rounded, color: AppColors.textTertiary),
              SizedBox(width: 12),
              Text(
                'نادیده گرفتن مشکل',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'این مشکل نادیده گرفته می‌شود و در لیست مشکلات باز نمایش داده نخواهد شد.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  hintText: 'دلیل نادیده گرفتن',
                  hintStyle: const TextStyle(color: AppColors.textTertiary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.borderSubtle),
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(qualityActionsProvider.notifier).ignoreIssue(
                      issue.id,
                      note: noteController.text.isNotEmpty
                          ? noteController.text
                          : null,
                    );
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textSecondary,
                foregroundColor: Colors.white,
              ),
              child: const Text('نادیده بگیر'),
            ),
          ],
        ),
      ),
    );
  }
}
