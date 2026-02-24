import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/utils/farsi_utils.dart';

/// Voice recorder widget with 3-minute maximum recording time
///
/// Features:
/// - Start/pause/resume/stop recording
/// - 3-minute max duration with progress bar
/// - Auto-stop at limit
/// - Preview playback before submission
/// - Microphone permission handling
class VoiceRecorderWidget extends StatefulWidget {
  final void Function(File recordingFile)? onRecordingComplete;

  const VoiceRecorderWidget({
    this.onRecordingComplete,
    super.key,
  });

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final AudioPlayer _player = AudioPlayer();

  RecordingState _state = RecordingState.idle;
  Duration _recordedDuration = Duration.zero;
  Timer? _timer;
  String? _recordingPath;
  bool _isRecorderInitialized = false;

  static const Duration maxDuration = Duration(minutes: 3);

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.closeRecorder();
    _player.dispose();
    super.dispose();
  }

  Future<void> _initRecorder() async {
    // First check current status
    var status = await Permission.microphone.status;

    // If not determined yet, request permission
    if (status.isDenied || status.isRestricted) {
      status = await Permission.microphone.request();
    }

    if (status.isPermanentlyDenied) {
      // User previously denied and selected "Don't ask again"
      setState(() => _state = RecordingState.permissionDenied);
      return;
    }

    if (!status.isGranted) {
      setState(() => _state = RecordingState.permissionDenied);
      return;
    }

    try {
      await _recorder.openRecorder();
      setState(() => _isRecorderInitialized = true);
    } catch (e) {
      // If recorder fails to open, show permission denied state
      setState(() => _state = RecordingState.permissionDenied);
    }
  }

  Future<void> _retryPermission() async {
    setState(() => _state = RecordingState.idle);
    await _initRecorder();
  }

  Future<void> _startRecording() async {
    if (!_isRecorderInitialized) return;

    try {
      final tempDir = await getTemporaryDirectory();
      _recordingPath = '${tempDir.path}/voice_sample_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.startRecorder(
        toFile: _recordingPath,
        codec: Codec.aacMP4,
      );

      setState(() {
        _state = RecordingState.recording;
        _recordedDuration = Duration.zero;
      });

      _startTimer();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در شروع ضبط: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _pauseRecording() async {
    await _recorder.pauseRecorder();
    _timer?.cancel();
    setState(() => _state = RecordingState.paused);
  }

  Future<void> _resumeRecording() async {
    await _recorder.resumeRecorder();
    _startTimer();
    setState(() => _state = RecordingState.recording);
  }

  Future<void> _stopRecording() async {
    await _recorder.stopRecorder();
    _timer?.cancel();
    setState(() => _state = RecordingState.completed);

    if (_recordingPath != null && widget.onRecordingComplete != null) {
      widget.onRecordingComplete!(File(_recordingPath!));
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordedDuration += const Duration(seconds: 1);

        // Auto-stop at max duration
        if (_recordedDuration >= maxDuration) {
          _stopRecording();
        }
      });
    });
  }

  Future<void> _playRecording() async {
    if (_recordingPath == null) return;

    try {
      await _player.setFilePath(_recordingPath!);
      await _player.play();
      setState(() => _state = RecordingState.playing);

      _player.playerStateStream.listen((playerState) {
        if (playerState.processingState == ProcessingState.completed) {
          setState(() => _state = RecordingState.completed);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در پخش: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _stopPlayback() async {
    await _player.stop();
    setState(() => _state = RecordingState.completed);
  }

  void _resetRecording() {
    if (_recordingPath != null) {
      File(_recordingPath!).deleteSync();
    }
    setState(() {
      _state = RecordingState.idle;
      _recordedDuration = Duration.zero;
      _recordingPath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_state == RecordingState.permissionDenied) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            const Icon(Icons.mic_off, color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            const Text(
              'دسترسی به میکروفون رد شد',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'لطفاً در تنظیمات برنامه، دسترسی میکروفون را فعال کنید.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _retryPermission,
                    icon: const Icon(Icons.refresh),
                    label: const Text('تلاش مجدد'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => openAppSettings(),
                    icon: const Icon(Icons.settings, color: Colors.white),
                    label: const Text('تنظیمات'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.mic, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'نمونه صوتی (حداکثر 3 دقیقه)',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Timer and Progress
          Text(
            _formatDuration(_recordedDuration),
            style: TextStyle(
              color: _recordedDuration >= maxDuration
                  ? AppColors.error
                  : AppColors.primary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              fontFamily: 'Vazirmatn',
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _recordedDuration.inSeconds / maxDuration.inSeconds,
            backgroundColor: AppColors.borderSubtle,
            valueColor: AlwaysStoppedAnimation<Color>(
              _recordedDuration >= maxDuration * 0.9
                  ? AppColors.error
                  : AppColors.primary,
            ),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 24),

          // Control Buttons
          if (_state == RecordingState.idle) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isRecorderInitialized ? _startRecording : null,
                icon: const Icon(Icons.fiber_manual_record, color: Colors.white),
                label: const Text('شروع ضبط'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ] else if (_state == RecordingState.recording) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pauseRecording,
                    icon: const Icon(Icons.pause),
                    label: const Text('توقف موقت'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _stopRecording,
                    icon: const Icon(Icons.stop, color: Colors.white),
                    label: const Text('پایان ضبط'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (_state == RecordingState.paused) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resumeRecording,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('ادامه ضبط'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _stopRecording,
                    icon: const Icon(Icons.stop, color: Colors.white),
                    label: const Text('پایان ضبط'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (_state == RecordingState.completed || _state == RecordingState.playing) ...[
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _state == RecordingState.playing ? _stopPlayback : _playRecording,
                        icon: Icon(_state == RecordingState.playing ? Icons.stop : Icons.play_arrow),
                        label: Text(_state == RecordingState.playing ? 'توقف پخش' : 'پخش نمونه'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _resetRecording,
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        label: const Text('ضبط مجدد'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return FarsiUtils.toFarsiDigits('$minutes:$seconds');
  }
}

enum RecordingState {
  idle,
  recording,
  paused,
  completed,
  playing,
  permissionDenied,
}
