import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/providers/audio_provider.dart';
import 'package:myna/providers/bookmark_provider.dart';
import 'package:myna/providers/download_provider.dart';
import 'package:myna/services/bookmark_service.dart';
import 'package:myna/services/notification_permission_service.dart';
import 'package:myna/utils/farsi_utils.dart';
import 'package:myna/utils/app_logger.dart';
import 'package:myna/utils/app_strings.dart';
import 'package:myna/screens/player/car_mode_screen.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> audiobook;
  final List<Map<String, dynamic>> chapters;
  final int initialChapterIndex;
  /// If true, playback was already started by the caller (e.g., audiobook_detail_screen).
  /// PlayerScreen should NOT call play() again.
  final bool playbackAlreadyStarted;

  const PlayerScreen({
    super.key,
    required this.audiobook,
    required this.chapters,
    this.initialChapterIndex = 0,
    this.playbackAlreadyStarted = false,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  bool _hasInitialized = false;

  // Seek bar drag state - prevents jitter during scrubbing
  bool _isDragging = false;
  double _dragProgress = 0.0;

  // Dynamic background color extracted from cover art (Audible-style gradient)
  Color? _dominantCoverColor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePlayback();
      _extractDominantColor();
    });
  }

  void _initializePlayback() async {
    if (_hasInitialized) return;
    _hasInitialized = true;

    final newAudiobookId = widget.audiobook['id'] as int;

    // Load bookmarks for this audiobook
    ref.read(bookmarkProvider.notifier).loadBookmarks(newAudiobookId);

    // CRITICAL: If caller already started playback, do NOT call play() again.
    // This is the primary fix for double play() calls.
    if (widget.playbackAlreadyStarted) {
      AppLogger.audio('PLAYER_SCREEN: playbackAlreadyStarted=true, skipping play()');
      return;
    }

    final audio = ref.read(audioProvider);
    final currentAudiobookId = audio.audiobook?['id'];

    // GUARD: If already playing/loading this audiobook, don't restart.
    if (audio.hasAudio && currentAudiobookId == newAudiobookId) {
      AppLogger.audio('PLAYER_SCREEN: Already playing audiobook $newAudiobookId, skipping play()');
      return;
    }

    if (audio.isLoading) {
      AppLogger.audio('PLAYER_SCREEN: Audio is loading, skipping play()');
      return;
    }

    if (audio.isPlaying && currentAudiobookId == newAudiobookId) {
      AppLogger.audio('PLAYER_SCREEN: Already playing audiobook $newAudiobookId, skipping play()');
      return;
    }

    // Try to load saved progress from database
    int chapterIndex = widget.initialChapterIndex;
    int? seekTo;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final progress = await Supabase.instance.client
            .from('listening_progress')
            .select('current_chapter_index, position_seconds, is_completed')
            .eq('user_id', user.id)
            .eq('audiobook_id', newAudiobookId)
            .maybeSingle();

        if (progress != null && progress['is_completed'] != true) {
          final savedChapterIndex = (progress['current_chapter_index'] as int?) ?? 0;
          final savedPosition = (progress['position_seconds'] as int?) ?? 0;

          if (savedChapterIndex >= 0 && savedChapterIndex < widget.chapters.length) {
            chapterIndex = savedChapterIndex;
            seekTo = savedPosition;
          }
        }
      }
    } catch (e) {
      // Failed to load progress - continue without it
    }

    ref.read(audioProvider.notifier).play(
      audiobook: widget.audiobook,
      chapters: widget.chapters,
      chapterIndex: chapterIndex,
      seekTo: seekTo,
    );
  }

  /// Extract dominant color from cover art for dynamic gradient background.
  /// Follows same pattern as audiobook_detail_screen.dart (PaletteGenerator).
  Future<void> _extractDominantColor() async {
    // Guard: skip if already computed or cover URL missing
    if (_dominantCoverColor != null) return;
    final coverUrl = widget.audiobook['cover_url'] as String?;
    if (coverUrl == null || coverUrl.isEmpty) return;
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(coverUrl),
        size: const Size(100, 100),
        maximumColorCount: 16,
      );
      final color = palette.darkVibrantColor?.color ??
          palette.vibrantColor?.color ??
          palette.dominantColor?.color;
      if (mounted && color != null) {
        setState(() => _dominantCoverColor = color);
      }
    } catch (_) {
      // Palette extraction is best-effort — fallback to static gradient
    }
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
          hasError: state.hasError,
          errorMessage: state.errorMessage,
          playbackSpeed: state.playbackSpeed,
          isOwned: state.isOwned,
        ),
      ),
    );
    final notifier = ref.read(audioProvider.notifier);

    final displayAudiobook = audioUi.audiobook ?? widget.audiobook;
    final displayChapters = audioUi.chapters.isNotEmpty ? audioUi.chapters : widget.chapters;

    final currentChapter = displayChapters.isNotEmpty &&
            audioUi.currentChapterIndex < displayChapters.length
        ? displayChapters[audioUi.currentChapterIndex]
        : null;

    final author = (displayAudiobook['author_fa'] as String?) ?? '';
    final isMusic = (displayAudiobook['content_type'] as String?) == 'music';
    // Get narrator/artist from the correct metadata table
    // For books: book_metadata.narrator_name (actual voice narrator)
    // For music: music_metadata.artist_name or author_fa (artist)
    String narrator;
    if (isMusic) {
      final musicMeta = displayAudiobook['music_metadata'] as Map<String, dynamic>?;
      narrator = (musicMeta?['artist_name'] as String?) ?? author;
    } else {
      final bookMeta = displayAudiobook['book_metadata'] as Map<String, dynamic>?;
      narrator = (bookMeta?['narrator_name'] as String?) ?? '';
    }

    // Dynamic gradient: cover art color at top → dark background at bottom
    final gradientTop = (_dominantCoverColor ?? AppColors.playerGradientStart)
        .withValues(alpha: 0.7);

    return Directionality(
      textDirection: AppStrings.isLtr ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [gradientTop, AppColors.background],
              stops: const [0.0, 0.55],
            ),
          ),
          child: SafeArea(
              child: Column(
                children: [
                  // Header
                  _buildHeader(
                    context,
                    displayChapters,
                    audioUi.currentChapterIndex,
                    audioUi.isOwned,
                  ),

              // Main Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  child: Column(
                    children: [
                      const SizedBox(height: AppSpacing.lg),

                      // Cover Image
                      _buildCover(displayAudiobook),
                      const SizedBox(height: AppSpacing.xl),

                      // Title & Metadata (Author, Narrator)
                      _buildTitleSection(displayAudiobook, currentChapter, author, narrator),
                      const SizedBox(height: AppSpacing.xl),

                      // Error Display
                      if (audioUi.hasError) _buildErrorCard(audioUi.errorMessage, notifier),

                      // Android Notification Permission Warning (Android 13+ only)
                      if (Platform.isAndroid) _buildNotificationPermissionWarning(),

                      // Progress Section with Moment Heatmap
                      Consumer(
                        builder: (context, ref, _) {
                          final progress = ref.watch(
                            audioProvider.select(
                              (state) => (
                                position: state.position,
                                duration: state.duration,
                                isBuffering: state.isBuffering,
                                hasError: state.hasError,
                                currentChapterIndex: state.currentChapterIndex,
                                sessionStartPosition: state.sessionStartPosition,
                              ),
                            ),
                          );

                          // Load chapter moments when chapter changes
                          return _buildProgressSection(
                            position: progress.position,
                            duration: progress.duration,
                            isBuffering: progress.isBuffering,
                            hasError: progress.hasError,
                            sessionStartPosition: progress.sessionStartPosition,
                            notifier: notifier,
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Main Controls
                      _buildMainControls(
                        notifier: notifier,
                        chapters: displayChapters,
                        currentChapterIndex: audioUi.currentChapterIndex,
                        isOwned: audioUi.isOwned,
                        hasError: audioUi.hasError,
                        isLoading: audioUi.isLoading,
                        isPlaying: audioUi.isPlaying,
                        playbackSpeed: audioUi.playbackSpeed,
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Sleep Timer Display (when active)
                      Consumer(
                        builder: (context, ref, _) {
                          final timer = ref.watch(
                            audioProvider.select(
                              (state) => (
                                hasSleepTimer: state.hasSleepTimer,
                                sleepTimerMode: state.sleepTimerMode,
                                sleepTimerRemaining: state.sleepTimerRemaining,
                              ),
                            ),
                          );
                          if (!timer.hasSleepTimer) return const SizedBox.shrink();
                          return _buildSleepTimerDisplay(
                            timer.sleepTimerMode,
                            timer.sleepTimerRemaining,
                            ref,
                          );
                        },
                      ),

                      // Secondary Controls
                      Consumer(
                        builder: (context, ref, _) {
                          final secondary = ref.watch(
                            audioProvider.select(
                              (state) => (
                                audiobookId: state.audiobook?['id'] as int?,
                                currentChapterIndex: state.currentChapterIndex,
                                positionSeconds: state.position.inSeconds,
                                playbackSpeed: state.playbackSpeed,
                                sleepTimerMode: state.sleepTimerMode,
                                sleepTimerRemaining: state.sleepTimerRemaining,
                                hasSleepTimer: state.hasSleepTimer,
                                isOwned: state.isOwned,
                              ),
                            ),
                          );
                          return _buildSecondaryControls(
                            chapters: displayChapters,
                            audiobookId: secondary.audiobookId,
                            currentChapterIndex: secondary.currentChapterIndex,
                            positionSeconds: secondary.positionSeconds,
                            playbackSpeed: secondary.playbackSpeed,
                            sleepTimerMode: secondary.sleepTimerMode,
                            sleepTimerRemaining: secondary.sleepTimerRemaining,
                            hasSleepTimer: secondary.hasSleepTimer,
                            isOwned: secondary.isOwned,
                            ref: ref,
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    List<Map<String, dynamic>> chapters,
    int currentChapterIndex,
    bool isOwned,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close button
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 24),
              color: AppColors.textPrimary,
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
            ),
          ),

          // Chapter indicator
          if (chapters.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                (widget.audiobook['content_type'] as String?) == 'music'
                    ? 'آهنگ ${FarsiUtils.toFarsiDigits(currentChapterIndex + 1)} از ${FarsiUtils.toFarsiDigits(chapters.length)}'
                    : 'فصل ${FarsiUtils.toFarsiDigits(currentChapterIndex + 1)} از ${FarsiUtils.toFarsiDigits(chapters.length)}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          // Chapters button
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.list_rounded, size: 22),
              color: AppColors.textPrimary,
              onPressed: chapters.isEmpty
                  ? null
                  : () => _showChaptersSheet(
                        context,
                        ref,
                        chapters,
                        currentChapterIndex,
                        isOwned,
                      ),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCover(Map<String, dynamic> audiobook) {
    final coverUrl = audiobook['cover_url'] as String?;
    final audiobookId = audiobook['id'];
    final screenWidth = MediaQuery.of(context).size.width;
    // 2:3 aspect ratio for book covers (portrait)
    final coverWidth = (screenWidth * 0.6).clamp(180.0, 280.0);
    final coverHeight = coverWidth * 1.5; // 2:3 ratio

    return Center(
      child: Container(
        width: coverWidth,
        height: coverHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (_dominantCoverColor ?? AppColors.primary).withValues(alpha: 0.3),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Hero(
          tag: 'player_cover_$audiobookId',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: coverUrl != null
                ? CachedNetworkImage(
                    imageUrl: coverUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: (coverWidth * 2).toInt(),
                    memCacheHeight: (coverHeight * 2).toInt(),
                    placeholder: (_, __) => _buildCoverPlaceholder(),
                    errorWidget: (_, __, ___) => _buildCoverPlaceholder(),
                  )
                : _buildCoverPlaceholder(),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverPlaceholder() {
    return const ColoredBox(
      color: AppColors.surface,
      child: Center(
        child: Icon(Icons.headphones_rounded, size: 80, color: AppColors.textTertiary),
      ),
    );
  }

  Widget _buildTitleSection(
    Map<String, dynamic> audiobook,
    Map<String, dynamic>? currentChapter,
    String author,
    String narrator,
  ) {
    final title = (audiobook['title'] as String?) ??
        (audiobook['title_fa'] as String?) ??
        '';
    final chapterTitle = (currentChapter?['title_fa'] as String?) ?? '';

    // Check if currently playing from local file (offline mode)
    final audiobookId = audiobook['id'] as int?;
    final chapterId = currentChapter?['id'] as int?;
    final isPlayingOffline = !kIsWeb &&
        audiobookId != null &&
        chapterId != null &&
        ref.watch(downloadProvider.select(
          (_) => ref.read(downloadProvider.notifier).isDownloaded(audiobookId, chapterId),
        ));

    return Column(
      children: [
        // Book Title
        Text(
          AppStrings.localize(title),
          style: AppTypography.playerTitle,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),

        // Author
        if (author.isNotEmpty) ...[
          Text(
            '${AppStrings.localize('نویسنده')}: ${AppStrings.localize(author)}',
            style: AppTypography.playerChapter,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
        ],

        // Narrator
        if (narrator.isNotEmpty) ...[
          Text(
            '${AppStrings.localize('گوینده')}: ${AppStrings.localize(narrator)}',
            style: AppTypography.playerChapter,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
        ],

        // Chapter Title with optional offline indicator
        if (chapterTitle.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Offline indicator (shown only when playing from local file)
              if (isPlayingOffline) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.download_done_rounded,
                        size: 12,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'آفلاین',
                        style: AppTypography.badge.copyWith(color: AppColors.success),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // Chapter title container
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    AppStrings.localize(chapterTitle),
                    style: AppTypography.playerTime.copyWith(color: AppColors.primary),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildErrorCard(String? errorMessage, AudioNotifier notifier) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 36),
          const SizedBox(height: 12),
          Text(
            errorMessage ?? 'خطایی در پخش رخ داد',
            style: const TextStyle(color: AppColors.error, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => notifier.retry(),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('تلاش مجدد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build a dismissible warning banner when Android notification permission is denied.
  /// Shows only on Android 13+ when permission is denied and user hasn't dismissed it.
  Widget _buildNotificationPermissionWarning() {
    return Consumer(
      builder: (context, ref, _) {
        final permissionStatus = ref.watch(notificationPermissionProvider);
        final isDismissed = ref.watch(notificationWarningDismissedProvider);

        // Only show if denied and not dismissed
        if (isDismissed ||
            permissionStatus == NotificationPermissionStatus.unknown ||
            permissionStatus == NotificationPermissionStatus.granted) {
          return const SizedBox.shrink();
        }

        final isPermanentlyDenied =
            permissionStatus == NotificationPermissionStatus.permanentlyDenied;

        return Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications_off_rounded, color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'دسترسی اعلان غیرفعال است',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Dismiss button
                  GestureDetector(
                    onTap: () {
                      ref.read(notificationWarningDismissedProvider.notifier).state = true;
                    },
                    child: const Icon(Icons.close_rounded, color: AppColors.warning, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'بدون دسترسی اعلان، کنترل‌های پخش در قفل صفحه و نوار اعلان نمایش داده نمی‌شوند.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              if (isPermanentlyDenied) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      // Open app notification settings
                      await NotificationPermissionService().openAppNotificationSettings();
                    },
                    icon: const Icon(Icons.settings_rounded, size: 16),
                    label: const Text('رفتن به تنظیمات'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warning,
                      side: BorderSide(color: AppColors.warning.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressSection({
    required Duration position,
    required Duration duration,
    required bool isBuffering,
    required bool hasError,
    Duration? sessionStartPosition,
    required AudioNotifier notifier,
  }) {

    // Use drag position while dragging, otherwise use actual position
    final displayProgress = _isDragging
        ? _dragProgress
        : (duration.inSeconds > 0 ? position.inSeconds / duration.inSeconds : 0.0);

    // Calculate display position for time labels
    final displayPosition = _isDragging
        ? Duration(seconds: (duration.inSeconds * _dragProgress).toInt())
        : position;

    // Session-start marker position (0.0 - 1.0)
    final double? sessionMarkerProgress = sessionStartPosition != null &&
            duration.inSeconds > 0
        ? (sessionStartPosition.inSeconds / duration.inSeconds).clamp(0.0, 1.0)
        : null;

    return Column(
      children: [
        // Progress bar with session-start marker overlay
        LayoutBuilder(
          builder: (context, constraints) {
            // Slider has ~24px horizontal padding on each side
            const sliderPadding = 24.0;
            final trackWidth = constraints.maxWidth - sliderPadding * 2;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // The actual Slider
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 8,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: AppColors.surfaceLight.withValues(alpha: 0.5),
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary.withValues(alpha: 0.15),
                    trackShape: const RoundedRectSliderTrackShape(),
                  ),
                  child: Directionality(
                    textDirection: TextDirection.ltr, // Progress bar should always go left to right
                    child: Slider(
                      value: displayProgress.clamp(0.0, 1.0),
                      onChangeStart: hasError
                          ? null
                          : (_) {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _isDragging = true;
                              });
                            },
                      onChanged: hasError
                          ? null
                          : (newProgress) {
                              setState(() {
                                _dragProgress = newProgress;
                              });
                            },
                      onChangeEnd: hasError
                          ? null
                          : (finalProgress) {
                              final newPosition = Duration(
                                seconds: (duration.inSeconds * finalProgress).toInt(),
                              );
                              notifier.seek(newPosition);
                              setState(() {
                                _isDragging = false;
                              });
                            },
                    ),
                  ),
                ),

                // Session-start marker dot (Apple Books pattern)
                if (sessionMarkerProgress != null && trackWidth > 0)
                  Positioned(
                    left: sliderPadding + (sessionMarkerProgress * trackWidth) - 3,
                    // Center vertically on the slider track (Slider is ~48px tall, track at center)
                    top: 21,
                    child: IgnorePointer(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.background.withValues(alpha: 0.8),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Drag-time popup (shows current time while scrubbing)
                if (_isDragging && trackWidth > 0)
                  Positioned(
                    left: sliderPadding + (displayProgress.clamp(0.0, 1.0) * trackWidth) - 28,
                    top: -8,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          FarsiUtils.formatDurationFromDurationLongFarsi(displayPosition),
                          style: AppTypography.badge.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 4),

        // Time labels - Swap positions for RTL (elapsed on right, remaining on left)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Remaining time (on right in RTL, which is visually on left)
              Text(
                '-${FarsiUtils.formatDurationFromDurationLongFarsi(duration - displayPosition)}',
                style: AppTypography.playerTime,
              ),
              // Buffering indicator
              if (isBuffering && !_isDragging)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'در حال بارگذاری...',
                      style: AppTypography.badge.copyWith(color: AppColors.textTertiary),
                    ),
                  ],
                ),
              // Elapsed time (on left in RTL, which is visually on right)
              Text(
                FarsiUtils.formatDurationFromDurationLongFarsi(displayPosition),
                style: AppTypography.playerTime,
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _canPlayChapter(List<Map<String, dynamic>> chapters, int chapterIndex, bool isOwned) {
    if (isOwned) return true;
    if (chapterIndex < 0 || chapterIndex >= chapters.length) return false;
    // Free audiobooks can always be played
    if (widget.audiobook['is_free'] == true) return true;
    return chapters[chapterIndex]['is_preview'] == true;
  }

  bool _hasNextPlayableChapter(
    List<Map<String, dynamic>> chapters,
    int currentChapterIndex,
    bool isOwned,
  ) {
    if (currentChapterIndex >= chapters.length - 1) return false;
    return _canPlayChapter(chapters, currentChapterIndex + 1, isOwned);
  }

  bool _hasPreviousPlayableChapter(
    List<Map<String, dynamic>> chapters,
    int currentChapterIndex,
    bool isOwned,
  ) {
    if (currentChapterIndex <= 0) return false;
    return _canPlayChapter(chapters, currentChapterIndex - 1, isOwned);
  }

  Widget _buildMainControls({
    required AudioNotifier notifier,
    required List<Map<String, dynamic>> chapters,
    required int currentChapterIndex,
    required bool isOwned,
    required bool hasError,
    required bool isLoading,
    required bool isPlaying,
    required double playbackSpeed,
  }) {
    // Use access-aware checks: only enable if user can play the chapter
    final canPrevious = _hasPreviousPlayableChapter(chapters, currentChapterIndex, isOwned);
    final canNext = _hasNextPlayableChapter(chapters, currentChapterIndex, isOwned);

    // Use LayoutBuilder for responsive sizing
    return LayoutBuilder(
      builder: (context, constraints) {
        // Scale button sizes based on available width
        final maxWidth = constraints.maxWidth;
        final playButtonSize = (maxWidth * 0.2).clamp(64.0, 80.0);
        final controlSize = (maxWidth * 0.1).clamp(32.0, 40.0);
        final skipSize = (maxWidth * 0.09).clamp(30.0, 36.0);
        final spacing = (maxWidth * 0.04).clamp(8.0, 20.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Previous Chapter
            _buildControlButton(
              icon: Icons.skip_previous_rounded,
              size: controlSize,
              enabled: canPrevious && !hasError,
              onPressed: () => notifier.previousChapter(),
            ),
            SizedBox(width: spacing * 0.8),

            // Skip Backward 10s
            _buildSkipButton(
              seconds: -10,
              size: skipSize,
              enabled: !hasError,
              onPressed: () => notifier.skipBackward(seconds: 10),
            ),
            SizedBox(width: spacing),

            // Play/Pause with speed badge
            _buildPlayPauseButton(
              isPlaying: isPlaying,
              isLoading: isLoading,
              hasError: hasError,
              notifier: notifier,
              size: playButtonSize,
              playbackSpeed: playbackSpeed,
            ),
            SizedBox(width: spacing),

            // Skip Forward 10s
            _buildSkipButton(
              seconds: 10,
              size: skipSize,
              enabled: !hasError,
              onPressed: () => notifier.skipForward(seconds: 10),
            ),
            SizedBox(width: spacing * 0.8),

            // Next Chapter
            _buildControlButton(
              icon: Icons.skip_next_rounded,
              size: controlSize,
              enabled: canNext && !hasError,
              onPressed: () => notifier.nextChapter(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required double size,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                onPressed();
              }
            : null,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            icon,
            size: size,
            color: enabled ? AppColors.textPrimary : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }

  /// Skip button using standard forward_10/replay_10 icons
  /// Note: Flutter Material Icons don't have 15-second variants, only 5/10/30
  Widget _buildSkipButton({
    required int seconds,
    required double size,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    final isForward = seconds > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                onPressed();
              }
            : null,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            isForward ? Icons.forward_10_rounded : Icons.replay_10_rounded,
            size: size,
            color: enabled ? AppColors.textPrimary : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }

  Widget _buildPlayPauseButton({
    required bool isPlaying,
    required bool isLoading,
    required bool hasError,
    required AudioNotifier notifier,
    double size = 80,
    double playbackSpeed = 1.0,
  }) {
    final iconSize = size * 0.5;
    final loaderSize = size * 0.4;

    Widget child;
    Color bgColor = AppColors.primary;

    if (hasError) {
      bgColor = AppColors.error;
      child = IconButton(
        icon: Icon(Icons.refresh_rounded, size: iconSize * 0.9),
        color: Colors.white,
        onPressed: () => notifier.retry(),
      );
    } else if (isLoading) {
      child = Center(
        child: SizedBox(
          width: loaderSize,
          height: loaderSize,
          child: const CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 3,
          ),
        ),
      );
    } else {
      child = IconButton(
        icon: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: iconSize,
        ),
        color: Colors.white,
        onPressed: () {
          HapticFeedback.mediumImpact();
          AppLogger.audio('[PP20][UI] player_screen tap isPlaying=$isPlaying');
          notifier.togglePlayPause();
        },
      );
    }

    // Show speed badge when not 1.0x
    final showSpeedBadge = playbackSpeed != 1.0 && !hasError && !isLoading;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: bgColor.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
        // Speed badge positioned at top-right
        if (showSpeedBadge)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary, width: 1.5),
              ),
              child: Text(
                '${playbackSpeed}x',
                style: AppTypography.speedBadge,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSecondaryControls({
    required List<Map<String, dynamic>> chapters,
    required int? audiobookId,
    required int currentChapterIndex,
    required int positionSeconds,
    required double playbackSpeed,
    required SleepTimerMode sleepTimerMode,
    required Duration sleepTimerRemaining,
    required bool hasSleepTimer,
    required bool isOwned,
    required WidgetRef ref,
  }) {
    final bookmarkState = ref.watch(bookmarkProvider);
    final currentChapter = chapters.isNotEmpty && currentChapterIndex < chapters.length
        ? chapters[currentChapterIndex]
        : null;
    final chapterId = currentChapter?['id'] as int?;

    // Check if there's a bookmark near current position
    final hasBookmark = audiobookId != null &&
        chapterId != null &&
        bookmarkState.hasBookmarkNear(audiobookId, chapterId, positionSeconds);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Playback Speed
          _buildSecondaryButton(
            icon: Icons.speed_rounded,
            label: '${playbackSpeed}x',
            onPressed: () => _showSpeedDialog(context, ref, playbackSpeed),
          ),

          // Divider
          _buildVerticalDivider(),

          // Bookmark
          _buildBookmarkButton(
            hasBookmark: hasBookmark,
            audiobookId: audiobookId,
            chapterId: chapterId,
            positionSeconds: positionSeconds,
            bookmarkState: bookmarkState,
            ref: ref,
          ),

          // Divider
          _buildVerticalDivider(),

          // Sleep Timer
          _buildSleepTimerButton(
            sleepTimerMode: sleepTimerMode,
            sleepTimerRemaining: sleepTimerRemaining,
            hasSleepTimer: hasSleepTimer,
            ref: ref,
          ),

          // Divider
          _buildVerticalDivider(),

          // Chapters/Tracks
          _buildSecondaryButton(
            icon: Icons.menu_book_rounded,
            label: (widget.audiobook['content_type'] as String?) == 'music'
                ? '${FarsiUtils.toFarsiDigits(chapters.length)} آهنگ'
                : '${FarsiUtils.toFarsiDigits(chapters.length)} فصل',
            onPressed: chapters.isEmpty
                ? null
                : () => _showChaptersSheet(
                      context,
                      ref,
                      chapters,
                      currentChapterIndex,
                      isOwned,
                    ),
          ),

          // Divider
          _buildVerticalDivider(),

          // Car Mode
          _buildSecondaryButton(
            icon: Icons.directions_car_rounded,
            label: AppStrings.carMode,
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                PageRouteBuilder<void>(
                  pageBuilder: (_, __, ___) => const CarModeScreen(),
                  transitionsBuilder: (_, animation, __, child) =>
                      FadeTransition(opacity: animation, child: child),
                  transitionDuration: AppDurations.normal,
                  reverseTransitionDuration: AppDurations.normal,
                  fullscreenDialog: true,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 40,
      color: AppColors.surfaceLight,
    );
  }

  Widget _buildBookmarkButton({
    required bool hasBookmark,
    required int? audiobookId,
    required int? chapterId,
    required int positionSeconds,
    required BookmarkState bookmarkState,
    required WidgetRef ref,
  }) {
    final bookmarkCount = audiobookId != null
        ? bookmarkState.forAudiobook(audiobookId).length
        : 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: audiobookId == null || chapterId == null
            ? null
            : () => _toggleBookmark(ref, audiobookId, chapterId, positionSeconds),
        onLongPress: audiobookId == null || bookmarkCount == 0
            ? null
            : () => _showBookmarksSheet(context, ref, audiobookId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasBookmark ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                size: 24,
                color: hasBookmark ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(height: 6),
              Text(
                bookmarkCount > 0 ? '${FarsiUtils.toFarsiDigits(bookmarkCount)} نشان' : 'نشان',
                style: TextStyle(
                  fontSize: 12,
                  color: hasBookmark ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleBookmark(
    WidgetRef ref,
    int audiobookId,
    int chapterId,
    int positionSeconds,
  ) async {
    HapticFeedback.selectionClick();
    final notifier = ref.read(bookmarkProvider.notifier);
    final wasCreated = await notifier.toggleBookmark(
      audiobookId: audiobookId,
      chapterId: chapterId,
      positionSeconds: positionSeconds,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(wasCreated ? 'نشان اضافه شد' : 'نشان حذف شد'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        action: wasCreated
            ? SnackBarAction(
                label: 'افزودن یادداشت',
                onPressed: () {
                  final lastBookmark = ref.read(bookmarkProvider).lastCreated;
                  if (lastBookmark != null) {
                    _showAddNoteDialog(context, ref, lastBookmark);
                  }
                },
              )
            : null,
      ),
    );
  }

  void _showAddNoteDialog(BuildContext context, WidgetRef ref, Bookmark bookmark) {
    final controller = TextEditingController(text: bookmark.note);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'یادداشت برای نشان',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'یادداشت خود را بنویسید...',
            hintStyle: const TextStyle(color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.surfaceLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(bookmarkProvider.notifier).updateNote(
                bookmark.id,
                controller.text.trim().isEmpty ? null : controller.text.trim(),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }

  void _showBookmarksSheet(BuildContext context, WidgetRef ref, int audiobookId) {
    final audio = ref.read(audioProvider);
    final bookmarks = ref.read(bookmarkProvider).forAudiobook(audiobookId);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'نشان‌های شما',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${bookmarks.length} نشان',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            // Bookmarks List
            Expanded(
              child: bookmarks.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bookmark_outline_rounded,
                            size: 48,
                            color: AppColors.textTertiary,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'هنوز نشانی اضافه نکرده‌اید',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: bookmarks.length,
                      itemBuilder: (context, index) {
                        final bookmark = bookmarks[index];
                        return _buildBookmarkTile(context, ref, bookmark, audio);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookmarkTile(
    BuildContext context,
    WidgetRef ref,
    Bookmark bookmark,
    AudioState audio,
  ) {
    return Dismissible(
      key: Key(bookmark.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsetsDirectional.only(start: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
      ),
      onDismissed: (_) {
        ref.read(bookmarkProvider.notifier).deleteBookmark(bookmark.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.bookmark_rounded, color: AppColors.primary, size: 22),
            ),
          ),
          title: Text(
            bookmark.chapterTitle ?? 'فصل نامشخص',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                bookmark.formattedPosition,
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 13,
                ),
              ),
              if (bookmark.note != null && bookmark.note!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  bookmark.note!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.play_circle_outline_rounded, size: 28),
            color: AppColors.primary,
            onPressed: () {
              // Find chapter index and navigate
              final chapters = audio.chapters;
              final chapterIndex = chapters.indexWhere(
                (c) => c['id'] == bookmark.chapterId,
              );
              if (chapterIndex != -1) {
                ref.read(audioProvider.notifier).goToChapter(chapterIndex);
                ref.read(audioProvider.notifier).seek(
                  Duration(seconds: bookmark.positionSeconds),
                );
                Navigator.pop(context);
              }
            },
          ),
          onTap: () {
            _showAddNoteDialog(context, ref, bookmark);
          },
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 24,
                color: onPressed != null ? AppColors.textSecondary : AppColors.textTertiary,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: onPressed != null ? AppColors.textSecondary : AppColors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSleepTimerButton({
    required SleepTimerMode sleepTimerMode,
    required Duration sleepTimerRemaining,
    required bool hasSleepTimer,
    required WidgetRef ref,
  }) {
    final isActive = hasSleepTimer;
    String label;

    if (sleepTimerMode == SleepTimerMode.endOfChapter) {
      label = (widget.audiobook['content_type'] as String?) == 'music' ? 'پایان آلبوم' : 'پایان فصل';
    } else if (sleepTimerMode == SleepTimerMode.timed) {
      final remaining = sleepTimerRemaining;
      // Show M:SS format for precise countdown
      final minutes = remaining.inMinutes;
      final seconds = remaining.inSeconds % 60;
      label = '${FarsiUtils.toFarsiDigits(minutes)}:${FarsiUtils.toFarsiDigits(seconds.toString().padLeft(2, '0'))}';
    } else {
      label = 'تایمر';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showSleepTimerSheet(
          context,
          ref,
          sleepTimerMode,
          sleepTimerRemaining,
          hasSleepTimer,
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? Icons.bedtime_rounded : Icons.bedtime_outlined,
                size: 24,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sleep timer display - shows remaining time prominently when active
  Widget _buildSleepTimerDisplay(
    SleepTimerMode mode,
    Duration remaining,
    WidgetRef ref,
  ) {
    String timerText;
    if (mode == SleepTimerMode.endOfChapter) {
      timerText = (widget.audiobook['content_type'] as String?) == 'music' ? 'پایان آلبوم' : 'پایان فصل';
    } else {
      final mins = remaining.inMinutes;
      final secs = remaining.inSeconds % 60;
      if (mins > 0) {
        timerText = '${FarsiUtils.toFarsiDigits(mins)}:${FarsiUtils.toFarsiDigits(secs.toString().padLeft(2, '0'))}';
      } else {
        timerText = '${FarsiUtils.toFarsiDigits(secs)} ثانیه';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.bedtime_rounded,
            color: AppColors.primary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            'تایمر خواب: $timerText',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => ref.read(audioProvider.notifier).cancelSleepTimer(),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: AppColors.primary,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSleepTimerSheet(
    BuildContext context,
    WidgetRef ref,
    SleepTimerMode sleepTimerMode,
    Duration sleepTimerRemaining,
    bool hasSleepTimer,
  ) {
    final timerOptions = [
      {'minutes': 5, 'label': '۵ دقیقه'},
      {'minutes': 10, 'label': '۱۰ دقیقه'},
      {'minutes': 15, 'label': '۱۵ دقیقه'},
      {'minutes': 30, 'label': '۳۰ دقیقه'},
      {'minutes': 45, 'label': '۴۵ دقیقه'},
      {'minutes': 60, 'label': '۱ ساعت'},
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'تایمر خواب',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'پخش پس از زمان تعیین‌شده متوقف می‌شود',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 24),

            // End of Chapter option (prominent)
            GestureDetector(
              onTap: () {
                ref.read(audioProvider.notifier).setSleepTimerEndOfChapter();
                Navigator.pop(context);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: sleepTimerMode == SleepTimerMode.endOfChapter
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: sleepTimerMode == SleepTimerMode.endOfChapter
                      ? Border.all(color: AppColors.primary.withValues(alpha: 0.5))
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.bookmark_outline_rounded,
                      size: 24,
                      color: sleepTimerMode == SleepTimerMode.endOfChapter
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (widget.audiobook['content_type'] as String?) == 'music' ? 'پایان این آلبوم' : 'پایان این فصل',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: sleepTimerMode == SleepTimerMode.endOfChapter
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (widget.audiobook['content_type'] as String?) == 'music'
                                ? 'وقتی آلبوم تمام شد متوقف می‌شود'
                                : 'وقتی فصل تمام شد متوقف می‌شود',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                        ),
                    ),
                    if (sleepTimerMode == SleepTimerMode.endOfChapter)
                      const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Time options grid
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: timerOptions.map((option) {
                final minutes = option['minutes'] as int;
                final label = option['label'] as String;
                final isSelected = sleepTimerMode == SleepTimerMode.timed &&
                    sleepTimerRemaining.inMinutes == minutes;

                return GestureDetector(
                  onTap: () {
                    ref.read(audioProvider.notifier).setSleepTimer(minutes);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 90,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            // Cancel timer button (if active)
            if (hasSleepTimer) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(audioProvider.notifier).cancelSleepTimer();
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.timer_off_rounded, size: 20),
                  label: const Text(
                    'لغو تایمر',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showSpeedDialog(BuildContext context, WidgetRef ref, double currentSpeed) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'سرعت پخش',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((speed) {
                final isSelected = speed == currentSpeed;
                return GestureDetector(
                  onTap: () {
                    ref.read(audioProvider.notifier).setSpeed(speed);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 72,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '${FarsiUtils.toFarsiDigits(speed)}x',
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showChaptersSheet(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> displayChapters,
    int currentChapterIndex,
    bool isOwned,
  ) {
    AppLogger.audio('PLAYER_SCREEN: Opening chapter list (${displayChapters.length} chapters, current=$currentChapterIndex)');
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'فهرست فصل‌ها',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${displayChapters.length} فصل',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            // Chapters List
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: displayChapters.length,
                itemBuilder: (context, index) {
                  final chapter = displayChapters[index];
                  final isCurrent = index == currentChapterIndex;
                  final duration = (chapter['duration_seconds'] as int?) ?? 0;
                  final canPlay = _canPlayChapter(displayChapters, index, isOwned);
                  final isPreview = chapter['is_preview'] == true;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isCurrent ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: isCurrent
                          ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
                          : null,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isCurrent ? AppColors.primary : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: isCurrent
                              ? const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 22)
                              : !canPlay
                                  ? const Icon(Icons.lock_outline_rounded, color: AppColors.textTertiary, size: 20)
                                  : Text(
                                      FarsiUtils.toFarsiDigits(index + 1),
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              AppStrings.localize((chapter['title_fa'] as String?) ?? 'فصل ${FarsiUtils.toFarsiDigits(index + 1)}'),
                              style: TextStyle(
                                color: isCurrent
                                    ? AppColors.primary
                                    : (canPlay ? AppColors.textPrimary : AppColors.textTertiary),
                                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (isPreview && !isOwned)
                            Container(
                              margin: const EdgeInsetsDirectional.only(end: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'رایگان',
                                style: AppTypography.micro.copyWith(color: AppColors.success),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        FarsiUtils.formatDurationLongFarsi(duration),
                        style: AppTypography.playerTime,
                      ),
                      trailing: isCurrent
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'در حال پخش',
                                style: AppTypography.badge.copyWith(color: Colors.white),
                              ),
                            )
                          : canPlay
                              ? const Icon(
                                  Icons.play_circle_outline_rounded,
                                  color: AppColors.textTertiary,
                                  size: 28,
                                )
                              : const Icon(
                                  Icons.lock_outline_rounded,
                                  color: AppColors.textTertiary,
                                  size: 24,
                                ),
                      onTap: canPlay
                          ? () {
                              final chapter = displayChapters[index];
                              AppLogger.audio(
                                'PLAYER_SCREEN: Chapter tapped - index=$index, '
                                'chapterId=${chapter['id']}, title="${chapter['title_fa']}"',
                              );
                              ref.read(audioProvider.notifier).goToChapter(index);
                              Navigator.pop(context);
                            }
                          : () {
                              // Show locked chapter message
                              AppLogger.audio('PLAYER_SCREEN: Locked chapter tapped - index=$index');
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('این فصل قفل است. برای گوش دادن، کتاب را خریداری کنید'),
                                  backgroundColor: AppColors.warning,
                                ),
                              );
                            },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
