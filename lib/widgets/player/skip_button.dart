import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:myna/theme/app_theme.dart';

/// Skip forward/backward button for the audio player.
/// Extracted from player_screen.dart for reusability.
class SkipButton extends StatelessWidget {
  /// Seconds to skip (positive for forward, negative for backward).
  final int seconds;
  final double size;
  final bool enabled;
  final VoidCallback onPressed;

  const SkipButton({
    super.key,
    required this.seconds,
    this.size = 32,
    this.enabled = true,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isForward = seconds > 0;
    final absSeconds = seconds.abs();

    return Semantics(
      label: isForward ? '$absSeconds ثانیه جلو' : '$absSeconds ثانیه عقب',
      button: true,
      enabled: enabled,
      child: Material(
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
            padding: const EdgeInsets.all(8),
            child: Icon(
              isForward ? Icons.forward_10_rounded : Icons.replay_10_rounded,
              size: size,
              color: enabled ? AppColors.textPrimary : AppColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}
