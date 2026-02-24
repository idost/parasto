import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/providers/download_provider.dart';
import 'package:myna/services/download_service.dart';
import 'package:myna/utils/formatters.dart';
import 'package:myna/utils/farsi_utils.dart';

/// Provider to fetch audiobook metadata for downloaded items
final _audiobookMetadataProvider = FutureProvider.family<Map<String, dynamic>?, int>((ref, audiobookId) async {
  try {
    final response = await Supabase.instance.client
        .from('audiobooks')
        .select('id, title_fa, cover_url')
        .eq('id', audiobookId)
        .maybeSingle();
    return response;
  } catch (e) {
    return null;
  }
});

/// Provider to fetch chapter titles for downloaded items
final _chapterMetadataProvider = FutureProvider.family<Map<String, dynamic>?, int>((ref, chapterId) async {
  try {
    final response = await Supabase.instance.client
        .from('chapters')
        .select('id, title_fa, chapter_index')
        .eq('id', chapterId)
        .maybeSingle();
    return response;
  } catch (e) {
    return null;
  }
});

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  final Set<int> _expandedAudiobooks = {};

  @override
  void initState() {
    super.initState();
    // Verify downloads on screen load to clean up stale entries
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(downloadProvider.notifier).verifyDownloads();
    });
  }

  @override
  Widget build(BuildContext context) {
    final downloadState = ref.watch(downloadProvider);
    final downloadNotifier = ref.read(downloadProvider.notifier);
    final groupedDownloads = downloadNotifier.getAllDownloadsGrouped();
    final totalSize = downloadNotifier.getFormattedTotalSizeFarsi();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('دانلودها'),
          centerTitle: true,
          actions: [
            if (downloadState.totalDownloads > 0)
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded),
                tooltip: 'حذف همه دانلودها',
                onPressed: () => _confirmDeleteAll(downloadNotifier),
              ),
          ],
        ),
        body: downloadState.totalDownloads == 0
            ? _buildEmptyState()
            : _buildDownloadsList(groupedDownloads, totalSize, downloadNotifier),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.download_rounded,
            size: 64,
            color: AppColors.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'هیچ دانلودی وجود ندارد',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'فصل‌های دانلود شده اینجا نمایش داده می‌شوند',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadsList(
    Map<int, List<DownloadedChapter>> groupedDownloads,
    String totalSize,
    DownloadNotifier notifier,
  ) {
    final audiobookIds = groupedDownloads.keys.toList();

    return Column(
      children: [
        // Storage header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                AppColors.primary.withValues(alpha: 0.15),
                AppColors.surface,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.storage_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'فضای استفاده شده',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalSize,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${ref.watch(downloadProvider).totalDownloads} فصل',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        // Audiobooks list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: audiobookIds.length,
            itemBuilder: (context, index) {
              final audiobookId = audiobookIds[index];
              final chapters = groupedDownloads[audiobookId];
              if (chapters == null || chapters.isEmpty) {
                return const SizedBox.shrink();
              }
              return _AudiobookDownloadCard(
                audiobookId: audiobookId,
                chapters: chapters,
                isExpanded: _expandedAudiobooks.contains(audiobookId),
                onToggleExpand: () {
                  setState(() {
                    if (_expandedAudiobooks.contains(audiobookId)) {
                      _expandedAudiobooks.remove(audiobookId);
                    } else {
                      _expandedAudiobooks.add(audiobookId);
                    }
                  });
                },
                onDeleteAudiobook: () => _confirmDeleteAudiobook(audiobookId, notifier),
                onDeleteChapter: (chapterId) => _confirmDeleteChapter(audiobookId, chapterId, notifier),
              );
            },
          ),
        ),
      ],
    );
  }

  void _confirmDeleteAll(DownloadNotifier notifier) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'حذف تمام دانلودها',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'آیا مطمئن هستید که می‌خواهید تمام فایل‌های دانلود شده را حذف کنید؟\nاین عمل قابل بازگشت نیست.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await notifier.deleteAllDownloads();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تمام دانلودها حذف شدند'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: const Text(
              'حذف همه',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAudiobook(int audiobookId, DownloadNotifier notifier) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'حذف دانلودهای این کتاب',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'آیا می‌خواهید تمام فصل‌های دانلود شده این کتاب را حذف کنید؟',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await notifier.deleteAudiobookDownloads(audiobookId);
              _expandedAudiobooks.remove(audiobookId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('دانلودهای کتاب حذف شدند'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: const Text(
              'حذف',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteChapter(int audiobookId, int chapterId, DownloadNotifier notifier) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'حذف فصل',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'آیا می‌خواهید این فصل را از دانلودها حذف کنید؟',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await notifier.deleteDownload(audiobookId, chapterId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('فصل از دانلودها حذف شد'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: const Text(
              'حذف',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _AudiobookDownloadCard extends ConsumerWidget {
  final int audiobookId;
  final List<DownloadedChapter> chapters;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onDeleteAudiobook;
  final void Function(int chapterId) onDeleteChapter;

  const _AudiobookDownloadCard({
    required this.audiobookId,
    required this.chapters,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onDeleteAudiobook,
    required this.onDeleteChapter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audiobookAsync = ref.watch(_audiobookMetadataProvider(audiobookId));
    final totalSize = chapters.fold<int>(0, (sum, c) => sum + c.fileSizeBytes);

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Audiobook header
          InkWell(
            onTap: onToggleExpand,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Cover
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 50,
                      height: 65,
                      color: AppColors.surfaceLight,
                      child: audiobookAsync.when(
                        loading: () => const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        error: (_, __) => const Icon(
                          Icons.auto_stories_rounded,
                          color: AppColors.textTertiary,
                        ),
                        data: (audiobook) {
                          if (audiobook == null || audiobook['cover_url'] == null) {
                            return const Icon(
                              Icons.auto_stories_rounded,
                              color: AppColors.textTertiary,
                            );
                          }
                          return CachedNetworkImage(
                            imageUrl: audiobook['cover_url'] as String,
                            fit: BoxFit.cover,
                            memCacheWidth: 120, // 60 * 2x DPR
                            memCacheHeight: 180, // 90 * 2x DPR
                            errorWidget: (_, __, ___) => const Icon(
                              Icons.auto_stories_rounded,
                              color: AppColors.textTertiary,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        audiobookAsync.when(
                          loading: () => Container(
                            width: 120,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          error: (_, __) => const Text(
                            'کتاب نامشخص',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          data: (audiobook) => Text(
                            (audiobook?['title_fa'] as String?) ?? 'کتاب نامشخص',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.download_done_rounded,
                              size: 14,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${chapters.length} فصل',
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.storage_rounded,
                              size: 14,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              Formatters.formatFileSize(totalSize),
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Actions
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20),
                        color: AppColors.textTertiary,
                        onPressed: onDeleteAudiobook,
                        tooltip: 'حذف همه فصل‌ها',
                      ),
                      Icon(
                        isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        color: AppColors.textTertiary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded chapter list
          if (isExpanded) ...[
            const Divider(
              height: 1,
              color: AppColors.surfaceLight,
              indent: 12,
              endIndent: 12,
            ),
            ...chapters.map((chapter) => _ChapterDownloadTile(
              chapter: chapter,
              onDelete: () => onDeleteChapter(chapter.chapterId),
            )),
          ],
        ],
      ),
    );
  }
}

class _ChapterDownloadTile extends ConsumerWidget {
  final DownloadedChapter chapter;
  final VoidCallback onDelete;

  const _ChapterDownloadTile({
    required this.chapter,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapterAsync = ref.watch(_chapterMetadataProvider(chapter.chapterId));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Chapter number
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: chapterAsync.when(
                loading: () => const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
                error: (_, __) => const Text(
                  '?',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                data: (data) => Text(
                  FarsiUtils.toFarsiDigits(((data?['chapter_index'] as int?) ?? 0) + 1),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Chapter info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                chapterAsync.when(
                  loading: () => Container(
                    width: 100,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  error: (_, __) => Text(
                    'فصل ${FarsiUtils.toFarsiDigits(chapter.chapterId)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  data: (data) => Text(
                    (data?['title_fa'] as String?) ?? 'فصل ${FarsiUtils.toFarsiDigits(chapter.chapterId)}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  Formatters.formatFileSize(chapter.fileSizeBytes),
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Delete button
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            color: AppColors.textTertiary,
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
          ),
        ],
      ),
    );
  }
}
