import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/providers/audio_provider.dart';
import 'package:myna/screens/player/player_screen.dart';
import 'package:myna/utils/farsi_utils.dart';
import 'package:myna/utils/app_logger.dart';

class MiniPlayer extends ConsumerStatefulWidget {
  const MiniPlayer({super.key});

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _playPauseController;

  @override
  void initState() {
    super.initState();
    _playPauseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // Sync initial state — if already playing when mini-player mounts
    final isPlaying = ref.read(audioProvider).isPlaying;
    if (isPlaying) {
      _playPauseController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _playPauseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioUi = ref.watch(
      audioProvider.select(
        (state) => (
          audiobook: state.audiobook,
          chapters: state.chapters,
          currentChapterIndex: state.currentChapterIndex,
          isPlaying: state.isPlaying,
          isLoading: state.isLoading,
          isBuffering: state.isBuffering,
          hasError: state.hasError,
        ),
      ),
    );

    if (audioUi.audiobook == null) return const SizedBox.shrink();

    // Drive AnimatedIcon: forward = show pause (playing), reverse = show play (paused)
    if (audioUi.isPlaying) {
      _playPauseController.forward();
    } else {
      _playPauseController.reverse();
    }

    final book = audioUi.audiobook!;
    final chapter = audioUi.chapters.isNotEmpty &&
            audioUi.currentChapterIndex < audioUi.chapters.length
        ? audioUi.chapters[audioUi.currentChapterIndex]
        : null;

    // Edge-to-edge container with subtle top border
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main content row
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 8, 6),
            child: Row(
              children: [
                // Tappable area: Cover + Info (opens player)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openPlayer(book, audioUi.chapters,
                        audioUi.currentChapterIndex),
                    child: Row(
                      children: [
                        _buildCover(book),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInfo(
                            book,
                            chapter,
                            audioUi.currentChapterIndex,
                            audioUi.chapters.length,
                            audioUi.hasError,
                            audioUi.isBuffering,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Control buttons (LTR order for universal media controls)
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Skip Backward
                      _buildSkipButton(
                        enabled: !audioUi.hasError && !audioUi.isLoading,
                      ),

                      // Play/Pause with AnimatedIcon
                      _buildPlayPauseButton(
                        isPlaying: audioUi.isPlaying,
                        isLoading: audioUi.isLoading,
                        hasError: audioUi.hasError,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Progress bar — flush at bottom, tapping opens player
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openPlayer(
                book, audioUi.chapters, audioUi.currentChapterIndex),
            child: Consumer(
              builder: (context, ref, _) {
                final progressState = ref.watch(
                  audioProvider.select(
                    (state) => (
                      position: state.position,
                      duration: state.duration,
                      hasError: state.hasError,
                    ),
                  ),
                );
                final progress = progressState.duration.inMilliseconds > 0
                    ? (progressState.position.inMilliseconds /
                            progressState.duration.inMilliseconds)
                        .clamp(0.0, 1.0)
                    : 0.0;
                return _buildProgressBar(progress, progressState.hasError);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Navigate to full player screen with Hero-compatible fade transition
  void _openPlayer(Map<String, dynamic> book, List<Map<String, dynamic>> chapters,
      int currentChapterIndex) {
    AppLogger.audio('MINI: Tapped — opening player');
    Navigator.push(
      context,
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => PlayerScreen(
          audiobook: book,
          chapters: chapters,
          initialChapterIndex: currentChapterIndex,
        ),
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Widget _buildCover(Map<String, dynamic> book) {
    final coverUrl = book['cover_url'] as String?;
    final audiobookId = book['id'];
    return Hero(
      tag: 'player_cover_$audiobookId',
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          color: AppColors.surfaceLight,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: coverUrl != null
              ? CachedNetworkImage(
                  imageUrl: coverUrl,
                  fit: BoxFit.cover,
                  width: 48,
                  height: 48,
                  memCacheWidth: 96, // 48 * 2x DPR
                  memCacheHeight: 96,
                  placeholder: (_, __) => const Icon(
                    Icons.auto_stories_rounded,
                    color: AppColors.textTertiary,
                    size: 22,
                  ),
                  errorWidget: (_, __, ___) => const Icon(
                    Icons.auto_stories_rounded,
                    color: AppColors.textTertiary,
                    size: 22,
                  ),
                )
              : const Icon(
                  Icons.auto_stories_rounded,
                  color: AppColors.textTertiary,
                  size: 22,
                ),
        ),
      ),
    );
  }

  Widget _buildInfo(
    Map<String, dynamic> book,
    Map<String, dynamic>? chapter,
    int currentChapterIndex,
    int totalChapters,
    bool hasError,
    bool isBuffering,
  ) {
    final title =
        (book['title'] as String?) ?? (book['title_fa'] as String?) ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title — 14pt medium weight
        Text(
          title,
          style: AppTypography.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        // Status / Chapter info
        _buildStatusRow(
            book, chapter, currentChapterIndex, totalChapters, hasError, isBuffering),
      ],
    );
  }

  Widget _buildStatusRow(
    Map<String, dynamic> book,
    Map<String, dynamic>? chapter,
    int currentChapterIndex,
    int totalChapters,
    bool hasError,
    bool isBuffering,
  ) {
    if (hasError) {
      return Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'خطا در پخش',
              style: AppTypography.labelMedium
                  .copyWith(color: AppColors.error),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    if (isBuffering) {
      return Row(
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              color: AppColors.primary.withValues(alpha: 0.7),
              strokeWidth: 1.5,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'در حال بارگذاری...',
            style: AppTypography.cardSubtitle,
          ),
        ],
      );
    }

    // Show chapter name with counter
    final isMusic = (book['content_type'] as String?) == 'music';
    final chapterLabel = isMusic ? 'آهنگ' : 'فصل';
    final chapterCounter = totalChapters > 1
        ? '$chapterLabel ${FarsiUtils.toFarsiDigits(currentChapterIndex + 1)} از ${FarsiUtils.toFarsiDigits(totalChapters)}'
        : '$chapterLabel ${FarsiUtils.toFarsiDigits(currentChapterIndex + 1)}';

    final chapterTitle = chapter?['title_fa'] as String?;

    // If chapter has a title, show title with counter badge
    if (chapterTitle != null && chapterTitle.isNotEmpty) {
      return Row(
        children: [
          Expanded(
            child: Text(
              chapterTitle,
              style: AppTypography.cardSubtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (totalChapters > 1) ...[
            const SizedBox(width: 8),
            Text(
              '(${FarsiUtils.toFarsiDigits(currentChapterIndex + 1)}/${FarsiUtils.toFarsiDigits(totalChapters)})',
              style: AppTypography.labelSmall
                  .copyWith(color: AppColors.textTertiary),
            ),
          ],
        ],
      );
    }

    // Fallback: show counter only
    return Text(
      chapterCounter,
      style: AppTypography.cardSubtitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildPlayPauseButton({
    required bool isPlaying,
    required bool isLoading,
    required bool hasError,
  }) {
    final notifier = ref.read(audioProvider.notifier);

    if (hasError) {
      // Retry button
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          AppLogger.audio('MINI: Retry tapped (hasError=true)');
          notifier.retry();
        },
        child: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsetsDirectional.only(start: 4),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.refresh_rounded,
            color: AppColors.error,
            size: 22,
          ),
        ),
      );
    }

    if (isLoading) {
      // Loading spinner
      return Container(
        width: 40,
        height: 40,
        margin: const EdgeInsetsDirectional.only(start: 4),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    // Play/Pause button with AnimatedIcon
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.mediumImpact();
        AppLogger.audio(
            '[PP20][UI] mini_player tap isPlaying=$isPlaying');
        notifier.togglePlayPause();
      },
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsetsDirectional.only(start: 4),
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: AnimatedIcon(
            icon: AnimatedIcons.play_pause,
            progress: _playPauseController,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  /// Skip-back button (10 seconds)
  Widget _buildSkipButton({required bool enabled}) {
    final notifier = ref.read(audioProvider.notifier);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled
          ? () {
              HapticFeedback.lightImpact();
              AppLogger.audio('MINI: Skip backward 10s tapped');
              notifier.skipBackward(seconds: 10);
            }
          : null,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(
          Icons.replay_10_rounded,
          color: enabled ? AppColors.textPrimary : AppColors.textTertiary,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildProgressBar(double progress, bool hasError) {
    return SizedBox(
      height: 3,
      child: Directionality(
        textDirection: TextDirection.ltr, // Progress always left-to-right
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: progress.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: hasError ? AppColors.error : AppColors.primary,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        ),
      ),
    );
  }
}
