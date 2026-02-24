import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/providers/feedback_providers.dart';
import 'package:myna/services/feedback_service.dart';
import 'package:myna/services/feedback_service_presentation.dart';
import 'package:myna/screens/narrator/narrator_edit_screen.dart';
import 'package:myna/screens/narrator/chapter_management_screen.dart';

class NarratorFeedbackScreen extends ConsumerStatefulWidget {
  final int? audiobookId;
  final String? audiobookTitle;

  const NarratorFeedbackScreen({
    super.key,
    this.audiobookId,
    this.audiobookTitle,
  });

  @override
  ConsumerState<NarratorFeedbackScreen> createState() => _NarratorFeedbackScreenState();
}

class _NarratorFeedbackScreenState extends ConsumerState<NarratorFeedbackScreen> {
  @override
  void initState() {
    super.initState();
    // Mark feedback as read when opening the screen
    _markAllAsRead();
  }

  Future<void> _markAllAsRead() async {
    final service = ref.read(feedbackServiceProvider);
    await service.markAllAsRead(null); // Will use current user ID internally
  }

  @override
  Widget build(BuildContext context) {
    // Use specific audiobook provider if audiobookId is provided, otherwise use general narrator provider
    final feedbackAsync = widget.audiobookId != null
        ? ref.watch(narratorAudiobookFeedbackProvider(widget.audiobookId!))
        : ref.watch(narratorFeedbackProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text(widget.audiobookTitle != null
              ? 'بازخوردهای ${widget.audiobookTitle}'
              : 'بازخوردهای مدیریت'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                if (widget.audiobookId != null) {
                  ref.invalidate(narratorAudiobookFeedbackProvider(widget.audiobookId!));
                } else {
                  ref.invalidate(narratorFeedbackProvider);
                }
                ref.invalidate(unreadFeedbackCountProvider);
              },
            ),
          ],
        ),
        body: feedbackAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text('خطا: $e', style: const TextStyle(color: AppColors.error)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (widget.audiobookId != null) {
                      ref.invalidate(narratorAudiobookFeedbackProvider(widget.audiobookId!));
                    } else {
                      ref.invalidate(narratorFeedbackProvider);
                    }
                  },
                  child: const Text('تلاش مجدد'),
                ),
              ],
            ),
          ),
          data: (feedbackList) {
            if (feedbackList.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.feedback_outlined, size: 64, color: AppColors.textTertiary),
                    SizedBox(height: 16),
                    Text(
                      'هنوز بازخوردی دریافت نکرده‌اید',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'بازخوردهای مدیریت در اینجا نمایش داده می‌شوند',
                      style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                if (widget.audiobookId != null) {
                  ref.invalidate(narratorAudiobookFeedbackProvider(widget.audiobookId!));
                } else {
                  ref.invalidate(narratorFeedbackProvider);
                }
              },
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: feedbackList.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final feedback = feedbackList[index];
                  return _buildFeedbackCard(feedback);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFeedbackCard(Map<String, dynamic> feedback) {
    final feedbackType = FeedbackTypeExtension.fromString(feedback['feedback_type'] as String?);
    final message = feedback['message'] as String? ?? '';
    final createdAt = DateTime.tryParse(feedback['created_at'] as String? ?? '');
    final chapterTitle = (feedback['chapters'] as Map<String, dynamic>?)?['title_fa'] as String?;
    final adminName = (feedback['profiles'] as Map<String, dynamic>?)?['display_name'] as String? ?? 'مدیر';
    final isRead = feedback['is_read'] == true;

    // If showing all feedback (not filtered by audiobook), also show audiobook title
    String? audiobookTitle;
    if (widget.audiobookId == null) {
      audiobookTitle = (feedback['audiobooks'] as Map<String, dynamic>?)?['title_fa'] as String?;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.medium,
        border: isRead ? null : Border.all(color: feedbackType.color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with type badge and metadata
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: feedbackType.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(feedbackType.icon, size: 16, color: feedbackType.color),
                    const SizedBox(width: 6),
                    Text(
                      feedbackType.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: feedbackType.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (!isRead)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: const Text(
                    'جدید',
                    style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),

          // Audiobook and chapter info
          if (audiobookTitle != null || chapterTitle != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (audiobookTitle != null) ...[
                  const Icon(Icons.book, size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      audiobookTitle,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                if (audiobookTitle != null && chapterTitle != null)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('•', style: TextStyle(color: AppColors.textTertiary)),
                  ),
                if (chapterTitle != null) ...[
                  const Icon(Icons.audiotrack, size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      chapterTitle,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],

          // Message content
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: AppRadius.small,
            ),
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ),

          // Footer with admin name and date
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Text(
                adminName,
                style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
              const Spacer(),
              if (createdAt != null) ...[
                const Icon(Icons.access_time, size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  _formatDate(createdAt),
                  style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                ),
              ],
            ],
          ),

          // Action hint for change_required or rejection_reason
          if (feedbackType == FeedbackType.changeRequired || feedbackType == FeedbackType.rejectionReason) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: feedbackType.color.withValues(alpha: 0.05),
                borderRadius: AppRadius.small,
                border: Border.all(color: feedbackType.color.withValues(alpha: 0.2)),
              ),
              child: Text(
                feedbackType == FeedbackType.changeRequired
                    ? 'لطفاً تغییرات درخواستی را اعمال و مجدداً ارسال کنید'
                    : 'این بازخورد دلیل رد شدن کتاب است',
                style: TextStyle(fontSize: 11, color: feedbackType.color),
              ),
            ),
          ],

          // Action buttons for editing audiobook/chapter
          _buildActionButtons(feedback, chapterTitle),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> feedback, String? chapterTitle) {
    final audiobookId = (feedback['audiobooks'] as Map<String, dynamic>?)?['id'] as int?;
    final audiobookTitle = (feedback['audiobooks'] as Map<String, dynamic>?)?['title_fa'] as String?;
    final audiobookStatus = (feedback['audiobooks'] as Map<String, dynamic>?)?['status'] as String?;

    if (audiobookId == null) return const SizedBox.shrink();

    // Check if audiobook can be edited (draft, submitted, under_review, or rejected)
    final canEdit = audiobookStatus == 'draft' ||
                    audiobookStatus == 'submitted' ||
                    audiobookStatus == 'under_review' ||
                    audiobookStatus == 'rejected';

    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            // Edit Audiobook button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canEdit ? () => _navigateToEditAudiobook(audiobookId) : null,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('ویرایش کتاب'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: canEdit ? AppColors.primary : AppColors.textTertiary),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Manage Chapters button (especially if feedback is for a specific chapter)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canEdit ? () => _navigateToChapterManagement(audiobookId, audiobookTitle ?? '') : null,
                icon: Icon(chapterTitle != null ? Icons.audiotrack : Icons.library_music, size: 16),
                label: Text(chapterTitle != null ? 'ویرایش فصل' : 'مدیریت فصل‌ها'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: chapterTitle != null ? AppColors.warning : AppColors.primary,
                  side: BorderSide(color: canEdit ? (chapterTitle != null ? AppColors.warning : AppColors.primary) : AppColors.textTertiary),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
        if (!canEdit) ...[
          const SizedBox(height: 8),
          const Text(
            'این کتاب تایید شده و قابل ویرایش نیست',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ],
      ],
    );
  }

  void _navigateToEditAudiobook(int audiobookId) {
    Navigator.push(
      context,
      MaterialPageRoute<bool>(
        builder: (context) => NarratorEditScreen(audiobookId: audiobookId),
      ),
    ).then((result) {
      if (result == true) {
        // Refresh feedback list after changes
        if (widget.audiobookId != null) {
          ref.invalidate(narratorAudiobookFeedbackProvider(widget.audiobookId!));
        } else {
          ref.invalidate(narratorFeedbackProvider);
        }
      }
    });
  }

  void _navigateToChapterManagement(int audiobookId, String audiobookTitle) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ChapterManagementScreen(
          audiobookId: audiobookId,
          audiobookTitle: audiobookTitle,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'همین الان';
    if (diff.inHours < 1) return '${diff.inMinutes} دقیقه پیش';
    if (diff.inDays < 1) return '${diff.inHours} ساعت پیش';
    if (diff.inDays < 7) return '${diff.inDays} روز پیش';

    return '${date.year}/${date.month}/${date.day}';
  }
}
