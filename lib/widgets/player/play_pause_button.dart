import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:myna/theme/app_theme.dart';

/// Large play/pause button with loading and error states.
/// Extracted from player_screen.dart for reusability.
class PlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final bool isLoading;
  final bool hasError;
  final double size;
  final double? playbackSpeed;
  final VoidCallback onTogglePlayPause;
  final VoidCallback? onRetry;

  const PlayPauseButton({
    super.key,
    required this.isPlaying,
    required this.isLoading,
    required this.hasError,
    this.size = 80,
    this.playbackSpeed,
    required this.onTogglePlayPause,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = size * 0.5;
    final loaderSize = size * 0.4;

    Widget child;
    Color bgColor = AppColors.primary;

    if (hasError) {
      bgColor = AppColors.error;
      child = IconButton(
        icon: Icon(Icons.refresh_rounded, size: iconSize * 0.9),
        color: AppColors.textOnPrimary,
        onPressed: onRetry,
      );
    } else if (isLoading) {
      child = Center(
        child: SizedBox(
          width: loaderSize,
          height: loaderSize,
          child: const CircularProgressIndicator(
            color: AppColors.textOnPrimary,
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
        color: AppColors.textOnPrimary,
        onPressed: () {
          HapticFeedback.mediumImpact();
          onTogglePlayPause();
        },
      );
    }

    // Show speed badge when not 1.0x
    final showSpeedBadge = playbackSpeed != null &&
        playbackSpeed != 1.0 &&
        !hasError &&
        !isLoading;

    // Determine semantic label based on state
    final semanticLabel = hasError
        ? 'تلاش مجدد'
        : isLoading
            ? 'در حال بارگذاری'
            : isPlaying
                ? 'توقف پخش'
                : 'پخش';

    return Semantics(
      label: semanticLabel,
      button: !isLoading,
      child: Stack(
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
    ),
    );
  }
}
