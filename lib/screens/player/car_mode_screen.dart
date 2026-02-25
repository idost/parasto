import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation, HapticFeedback, SystemChrome, SystemUiMode, SystemUiOverlay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:myna/providers/audio_provider.dart';
import 'package:myna/screens/listener/settings_screen.dart' show settingsProvider;
import 'package:myna/theme/app_theme.dart';
import 'package:myna/utils/app_strings.dart';
import 'package:myna/utils/farsi_utils.dart';

/// Car Mode — distraction-free, oversized-touch-zone playback interface.
///
/// Pure black (#000000) background for AMOLED efficiency and nighttime glare
/// reduction. Three giant touch zones occupy the bottom ~55% of screen:
///   • Skip Backward (start side)
///   • Play / Pause (center)
///   • Skip Forward (end side)
///
/// Top section shows minimal info: cover art, title, chapter, progress bar.
/// The progress bar is NOT interactive (no dragging).
///
/// Usage:
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => const CarModeScreen(),
///   fullscreenDialog: true,
/// ));
/// ```
class CarModeScreen extends ConsumerStatefulWidget {
  const CarModeScreen({super.key});

  @override
  ConsumerState<CarModeScreen> createState() => _CarModeScreenState();
}

class _CarModeScreenState extends ConsumerState<CarModeScreen>
    with SingleTickerProviderStateMixin {
  /// Controls the play ↔ pause icon morph animation.
  late final AnimationController _playPauseController;

  @override
  void initState() {
    super.initState();
    // Immersive sticky mode: hides system bars, swipe to reveal temporarily
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Allow landscape while in Car Mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Keep screen on while driving
    WakelockPlus.enable();

    _playPauseController = AnimationController(
      duration: AppDurations.fast,
      vsync: this,
    );

    // Set initial state based on current audio
    final isPlaying = ref.read(audioProvider).isPlaying;
    if (isPlaying) {
      _playPauseController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _playPauseController.dispose();
    // Release wake lock
    WakelockPlus.disable();
    // Restore portrait-only orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    // Restore normal system UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audio = ref.watch(audioProvider);
    final notifier = ref.read(audioProvider.notifier);
    final settings = ref.watch(settingsProvider);

    // Skip intervals from user settings (default 15s)
    final skipFwd = settings.skipForwardSeconds;
    final skipBwd = settings.skipBackwardSeconds;

    // Sync play/pause morph animation with audio state
    if (audio.isPlaying && _playPauseController.status != AnimationStatus.forward &&
        _playPauseController.value != 1.0) {
      _playPauseController.forward();
    } else if (!audio.isPlaying && _playPauseController.status != AnimationStatus.reverse &&
        _playPauseController.value != 0.0) {
      _playPauseController.reverse();
    }

    // If there's no audio at all, show a minimal "no audio" state
    if (!audio.hasAudio) {
      return _buildNoAudioState(context);
    }

    final audiobook = audio.audiobook!;
    final chapters = audio.chapters;
    final chapterIndex = audio.currentChapterIndex;
    final currentChapter =
        chapters.isNotEmpty && chapterIndex < chapters.length
            ? chapters[chapterIndex]
            : null;

    // Progress calculation
    final position = audio.position;
    final duration = audio.duration;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    // Book info
    final title = audiobook['title_fa'] as String? ??
        audiobook['title_en'] as String? ??
        '';
    final chapterTitle = currentChapter?['title'] as String? ?? '';
    final coverUrl = audiobook['cover_url'] as String?;
    final isMusic = (audiobook['content_type'] as String?) == 'music';

    // Chapter indicator: "فصل ۳ از ۱۲" or "قطعه ۳ از ۱۲"
    final chapterIndicator = chapters.isNotEmpty
        ? (isMusic
            ? AppStrings.trackOf(chapterIndex + 1, chapters.length)
            : AppStrings.chapterOf(chapterIndex + 1, chapters.length))
        : '';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            // ─── TOP: Info Section ───────────────────────────────
            _buildInfoSection(
              context: context,
              coverUrl: coverUrl,
              title: title,
              chapterTitle: chapterTitle,
              chapterIndicator: chapterIndicator,
              position: position,
              duration: duration,
              progress: progress,
            ),

            // ─── BOTTOM: 3 Giant Touch Zones (~55% of screen) ───
            Expanded(
              flex: 55,
              child: _buildTouchZones(
                notifier: notifier,
                isPlaying: audio.isPlaying,
                isBuffering: audio.isBuffering,
                playbackSpeed: audio.playbackSpeed,
                skipForwardSeconds: skipFwd,
                skipBackwardSeconds: skipBwd,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INFO SECTION (top ~45%)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildInfoSection({
    required BuildContext context,
    required String? coverUrl,
    required String title,
    required String chapterTitle,
    required String chapterIndicator,
    required Duration position,
    required Duration duration,
    required double progress,
  }) {
    return Expanded(
      flex: 45,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Exit button row
            _buildExitButton(context),

            const Spacer(),

            // Cover art
            _buildCoverArt(coverUrl),

            const SizedBox(height: AppSpacing.xl),

            // Title
            Text(
              AppStrings.localize(title),
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: AppSpacing.sm),

            // Chapter info
            if (chapterTitle.isNotEmpty)
              Text(
                AppStrings.localize(chapterTitle),
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: Colors.white70,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

            if (chapterIndicator.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  AppStrings.localize(chapterIndicator),
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white38,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: AppSpacing.lg),

            // Progress bar (non-interactive)
            _buildProgressBar(progress),

            // Time labels
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(position),
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white38,
                    ),
                  ),
                  Text(
                    _formatDuration(duration),
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildExitButton(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.topEnd,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xxxl),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            WakelockPlus.disable();
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
            ]);
            Navigator.of(context).pop();
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.close_rounded,
              color: Colors.white70,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverArt(String? coverUrl) {
    return Center(
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.05),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: coverUrl != null && coverUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: coverUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => const ColoredBox(
                  color: Colors.white10,
                  child: Icon(
                    Icons.headphones_rounded,
                    color: Colors.white24,
                    size: 48,
                  ),
                ),
                errorWidget: (_, __, ___) => const ColoredBox(
                  color: Colors.white10,
                  child: Icon(
                    Icons.headphones_rounded,
                    color: Colors.white24,
                    size: 48,
                  ),
                ),
              )
            : const ColoredBox(
                color: Colors.white10,
                child: Icon(
                  Icons.headphones_rounded,
                  color: Colors.white24,
                  size: 48,
                ),
              ),
      ),
    );
  }

  Widget _buildProgressBar(double progress) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 3,
        backgroundColor: Colors.white12,
        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white54),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TOUCH ZONES (bottom ~55%)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Returns the correct replay/forward icon for the given seconds value.
  /// Material Icons only have named 5/10/30 variants; others use generic icon.
  static IconData _skipIcon(int seconds, {required bool isForward}) {
    if (isForward) {
      switch (seconds) {
        case 5:  return Icons.forward_5_rounded;
        case 10: return Icons.forward_10_rounded;
        case 30: return Icons.forward_30_rounded;
        default: return Icons.fast_forward_rounded;
      }
    } else {
      switch (seconds) {
        case 5:  return Icons.replay_5_rounded;
        case 10: return Icons.replay_10_rounded;
        case 30: return Icons.replay_30_rounded;
        default: return Icons.fast_rewind_rounded;
      }
    }
  }

  Widget _buildTouchZones({
    required AudioNotifier notifier,
    required bool isPlaying,
    required bool isBuffering,
    required double playbackSpeed,
    required int skipForwardSeconds,
    required int skipBackwardSeconds,
  }) {
    // Respect text direction for skip zone ordering:
    //   LTR: [<< Back] [Play/Pause] [Forward >>]
    //   RTL: [Forward >>] [Play/Pause] [<< Back]
    //
    // We use Row with Expanded — Directionality handles start/end automatically.
    // "start" = skip backward, "end" = skip forward.

    return Row(
      children: [
        // Start zone: Skip Backward
        Expanded(
          child: _TouchZone(
            icon: _skipIcon(skipBackwardSeconds, isForward: false),
            iconSize: 68,
            label: AppStrings.nSeconds(skipBackwardSeconds),
            onTap: () {
              HapticFeedback.mediumImpact();
              notifier.skipBackward(seconds: skipBackwardSeconds);
            },
          ),
        ),

        // Thin vertical divider
        Container(
          width: 1,
          color: Colors.white.withValues(alpha: 0.06),
        ),

        // Center zone: Play/Pause (wider) with AnimatedIcon morph + speed badge
        Expanded(
          flex: 2,
          child: _TouchZone(
            customIcon: isBuffering
                ? null
                : AnimatedIcon(
                    icon: AnimatedIcons.play_pause,
                    progress: _playPauseController,
                    size: 84,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
            isLoading: isBuffering,
            iconSize: 84,
            badge: playbackSpeed != 1.0
                ? '×${FarsiUtils.toFarsiDigits(playbackSpeed.toStringAsFixed(playbackSpeed == playbackSpeed.roundToDouble() ? 0 : 1))}'
                : null,
            onTap: () {
              HapticFeedback.mediumImpact();
              notifier.togglePlayPause();
            },
          ),
        ),

        // Thin vertical divider
        Container(
          width: 1,
          color: Colors.white.withValues(alpha: 0.06),
        ),

        // End zone: Skip Forward
        Expanded(
          child: _TouchZone(
            icon: _skipIcon(skipForwardSeconds, isForward: true),
            iconSize: 68,
            label: AppStrings.nSeconds(skipForwardSeconds),
            onTap: () {
              HapticFeedback.mediumImpact();
              notifier.skipForward(seconds: skipForwardSeconds);
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NO AUDIO STATE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildNoAudioState(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.headphones_rounded,
              color: Colors.white24,
              size: 64,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              AppStrings.carModeNoAudio,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 16,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  AppStrings.carModeExit,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TOUCH ZONE WIDGET
// ═════════════════════════════════════════════════════════════════════════════

/// A single giant touch zone with icon + optional label.
///
/// Fills its parent entirely, making the entire area tappable.
/// Visual feedback: subtle background flash on press (Phase 5.4 will enhance).
class _TouchZone extends StatefulWidget {
  final IconData? icon;
  final Widget? customIcon;
  final String? label;
  final String? badge;
  final double iconSize;
  final bool isLoading;
  final VoidCallback onTap;

  const _TouchZone({
    this.icon,
    this.customIcon,
    this.label,
    this.badge,
    this.iconSize = 68,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  State<_TouchZone> createState() => _TouchZoneState();
}

class _TouchZoneState extends State<_TouchZone>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  /// Controls the floating label fade+slide animation.
  late final AnimationController _floatController;
  late final Animation<double> _floatOpacity;
  late final Animation<Offset> _floatSlide;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _floatOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _floatController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );
    _floatSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1.5),
    ).animate(CurvedAnimation(
      parent: _floatController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  void _triggerFloat() {
    if (widget.label == null) return;
    _floatController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _triggerFloat();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _isPressed ? Colors.white.withValues(alpha: 0.06) : Colors.transparent,
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.isLoading)
                    SizedBox(
                      width: widget.iconSize * 0.5,
                      height: widget.iconSize * 0.5,
                      child: const CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white54,
                      ),
                    )
                  else if (widget.customIcon != null)
                    widget.customIcon!
                  else if (widget.icon != null)
                    Icon(
                      widget.icon,
                      size: widget.iconSize,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  // Speed badge (shown when playback speed ≠ 1.0×)
                  if (widget.badge != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        widget.badge!,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                  if (widget.label != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      widget.label!,
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ],
              ),
              // Floating skip label — slides up and fades on each tap
              if (widget.label != null)
                SlideTransition(
                  position: _floatSlide,
                  child: FadeTransition(
                    opacity: _floatOpacity,
                    child: Text(
                      widget.label!,
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
