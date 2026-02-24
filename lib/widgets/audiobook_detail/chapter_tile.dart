import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/utils/formatters.dart';
import 'package:myna/utils/farsi_utils.dart';
import 'package:myna/utils/app_strings.dart';
import 'package:myna/services/download_service.dart' show DownloadStatus;

/// Data class for chapter progress information.
class ChapterProgressData {
  final int? currentChapterIndex;
  final bool albumIsCompleted;
  final int albumCompletionPercentage;
  final int? chapterSavedPosition;
  final bool chapterIsCompletedFromDB;

  const ChapterProgressData({
    this.currentChapterIndex,
    this.albumIsCompleted = false,
    this.albumCompletionPercentage = 0,
    this.chapterSavedPosition,
    this.chapterIsCompletedFromDB = false,
  });
}

/// Single chapter tile widget for the chapters list.
/// Extracted from audiobook_detail_screen.dart for better maintainability.
class ChapterTile extends StatelessWidget {
  final int index;
  final Map<String, dynamic> chapter;
  final ChapterProgressData progressData;
  final bool isOwned;
  final bool isMusic;
  final bool isFreeAudiobook;
  final DownloadStatus downloadStatus;
  final double downloadProgress;
  final VoidCallback? onTap;
  final VoidCallback? onDownload;
  final VoidCallback? onCancelDownload;
  final VoidCallback? onDelete;

  const ChapterTile({
    super.key,
    required this.index,
    required this.chapter,
    required this.progressData,
    required this.isOwned,
    required this.isMusic,
    required this.isFreeAudiobook,
    required this.downloadStatus,
    required this.downloadProgress,
    this.onTap,
    this.onDownload,
    this.onCancelDownload,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isPreview = chapter['is_preview'] == true;
    final canPlay = isOwned || isPreview || isFreeAudiobook;
    final title = (chapter['title_fa'] as String?) ??
        (isMusic
            ? 'آهنگ ${FarsiUtils.toFarsiDigits(index + 1)}'
            : 'فصل ${FarsiUtils.toFarsiDigits(index + 1)}');
    final duration = (chapter['duration_seconds'] as int?) ?? 0;

    // Determine chapter state
    final isCurrent = progressData.currentChapterIndex == index &&
        !progressData.albumIsCompleted;

    final isCompleted = progressData.chapterIsCompletedFromDB ||
        progressData.albumIsCompleted ||
        progressData.albumCompletionPercentage >= 100 ||
        (progressData.currentChapterIndex != null &&
            index < progressData.currentChapterIndex!);

    final chapterSavedPosition = progressData.chapterSavedPosition ?? 0;
    final hasPartialProgress = !isCompleted && chapterSavedPosition > 0;

    // Calculate chapter progress
    double chapterProgress = 0.0;
    if (isCompleted) {
      chapterProgress = 1.0;
    } else if (hasPartialProgress && duration > 0) {
      chapterProgress = (chapterSavedPosition / duration).clamp(0.0, 1.0);
    }

    return InkWell(
      onTap: canPlay ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            // Chapter Number / Status Icon
            _buildStatusIcon(isCurrent, isCompleted, hasPartialProgress, canPlay),
            const SizedBox(width: 12),

            // Title & Progress
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          FarsiUtils.localizeFarsi(AppStrings.localize(title)),
                          style: TextStyle(
                            color: canPlay
                                ? (isCurrent ? AppColors.primary : AppColors.textPrimary)
                                : AppColors.textTertiary,
                            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isPreview && !isOwned)
                        Container(
                          margin: const EdgeInsetsDirectional.only(end: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'رایگان',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (!canPlay)
                        const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.textTertiary),
                    ],
                  ),
                  // Chapter listening progress bar
                  if ((isCurrent || hasPartialProgress) &&
                      chapterProgress > 0 &&
                      downloadStatus != DownloadStatus.downloading) ...[
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: chapterProgress,
                      backgroundColor: AppColors.surfaceLight,
                      color: AppColors.primary,
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ],
                  // Download progress bar
                  if (downloadStatus == DownloadStatus.downloading) ...[
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: downloadProgress,
                      backgroundColor: AppColors.surfaceLight,
                      color: AppColors.secondary,
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ],
                ],
              ),
            ),

            // Duration & Download Status
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (downloadStatus == DownloadStatus.downloaded)
                  const Padding(
                    padding: EdgeInsetsDirectional.only(start: 8),
                    child: Icon(Icons.download_done_rounded, size: 16, color: AppColors.success),
                  ),
                Text(
                  Formatters.formatDuration(duration),
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                  ),
                ),
                // Download button on mobile
                if (!kIsWeb && canPlay) ...[
                  const SizedBox(width: 4),
                  _buildDownloadButton(),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(bool isCurrent, bool isCompleted, bool hasPartialProgress, bool canPlay) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isCurrent
            ? AppColors.primary
            : isCompleted
                ? AppColors.success.withValues(alpha: 0.15)
                : hasPartialProgress
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: isCurrent
            ? const Icon(Icons.play_arrow_rounded, color: AppColors.textOnPrimary, size: 18)
            : isCompleted
                ? const Icon(Icons.check_rounded, color: AppColors.success, size: 18)
                : hasPartialProgress
                    ? const Icon(Icons.pause_rounded, color: AppColors.primary, size: 18)
                    : Text(
                        FarsiUtils.toFarsiDigits(index + 1),
                        style: TextStyle(
                          color: canPlay ? AppColors.textPrimary : AppColors.textTertiary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
      ),
    );
  }

  Widget _buildDownloadButton() {
    IconData icon;
    Color color;
    VoidCallback? onPressed;

    switch (downloadStatus) {
      case DownloadStatus.downloaded:
        icon = Icons.delete_outline_rounded;
        color = AppColors.textTertiary;
        onPressed = onDelete;
      case DownloadStatus.downloading:
        icon = Icons.close_rounded;
        color = AppColors.warning;
        onPressed = onCancelDownload;
      case DownloadStatus.failed:
        icon = Icons.refresh;
        color = AppColors.error;
        onPressed = onDownload;
      case DownloadStatus.notDownloaded:
        icon = Icons.download_outlined;
        color = AppColors.textTertiary;
        onPressed = onDownload;
    }

    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        icon: Icon(icon, size: 18),
        color: color,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
