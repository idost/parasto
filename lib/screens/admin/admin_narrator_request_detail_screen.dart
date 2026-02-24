import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/models/narrator_request.dart';
import 'package:myna/providers/narrator_request_providers.dart';
import 'package:myna/utils/farsi_utils.dart';

/// Admin detail screen for reviewing narrator requests
///
/// Features:
/// - User info display
/// - Experience text
/// - Voice sample player with seek controls
/// - Approve/Reject actions
/// - Admin feedback on rejection
class AdminNarratorRequestDetailScreen extends ConsumerStatefulWidget {
  final NarratorRequest request;

  const AdminNarratorRequestDetailScreen({
    required this.request,
    super.key,
  });

  @override
  ConsumerState<AdminNarratorRequestDetailScreen> createState() =>
      _AdminNarratorRequestDetailScreenState();
}

class _AdminNarratorRequestDetailScreenState
    extends ConsumerState<AdminNarratorRequestDetailScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool _isLoadingAudio = true;
  bool _isProcessing = false;
  String? _audioError;
  Map<String, dynamic>? _userProfile;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadVoiceSample();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('display_name, email')
          .eq('id', widget.request.userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _userProfile = response;
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUser = false);
      }
    }
  }

  Future<void> _loadVoiceSample() async {
    try {
      final service = ref.read(narratorRequestServiceProvider);
      final url = await service.getVoiceSampleUrl(widget.request.voiceSamplePath);
      await _player.setUrl(url);
      setState(() => _isLoadingAudio = false);
    } catch (e) {
      setState(() {
        _isLoadingAudio = false;
        _audioError = e.toString();
      });
    }
  }

  Future<void> _approveRequest() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('تأیید درخواست', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'آیا مطمئن هستید که می‌خواهید این درخواست را تأیید کنید؟\n\nنقش کاربر به "گوینده" تغییر خواهد کرد.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('تأیید'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);

    try {
      final service = ref.read(narratorRequestServiceProvider);
      await service.approveRequest(widget.request.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('درخواست با موفقیت تأیید شد'),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در تأیید درخواست: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _rejectRequest() async {
    final feedbackController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('رد درخواست', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'آیا مطمئن هستید که می‌خواهید این درخواست را رد کنید؟',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            const Text(
              'بازخورد (اختیاری):',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: feedbackController,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'دلیل رد درخواست را برای کاربر توضیح دهید...',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.borderSubtle),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('رد درخواست'),
          ),
        ],
      ),
    );

    if (result != true) return;

    setState(() => _isProcessing = true);

    try {
      final service = ref.read(narratorRequestServiceProvider);
      final feedback = feedbackController.text.trim().isEmpty
          ? null
          : feedbackController.text.trim();

      await service.rejectRequest(widget.request.id, feedback: feedback);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('درخواست رد شد'),
          backgroundColor: AppColors.error,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در رد درخواست: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPending = widget.request.status == NarratorRequestStatus.pending;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('جزئیات درخواست گویندگی'),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Info Card
              _buildInfoCard(
                icon: Icons.person_outline,
                title: 'اطلاعات کاربر',
                children: [
                  if (_isLoadingUser)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else ...[
                    if (_userProfile?['display_name'] != null)
                      _buildInfoRow('نام', _userProfile!['display_name'] as String),
                    if (_userProfile?['email'] != null)
                      _buildInfoRow('ایمیل', _userProfile!['email'] as String),
                    _buildInfoRow('شناسه کاربر', widget.request.userId),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Experience Card
              _buildInfoCard(
                icon: Icons.article_outlined,
                title: 'تجربیات و علایق',
                children: [
                  Text(
                    widget.request.experienceText,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Voice Sample Player
              _buildInfoCard(
                icon: Icons.mic_outlined,
                title: 'نمونه صوتی',
                children: [
                  if (_isLoadingAudio)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_audioError != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'خطا در بارگذاری صوت: $_audioError',
                        style: const TextStyle(color: AppColors.error),
                      ),
                    )
                  else
                    _buildAudioPlayer(),
                ],
              ),
              const SizedBox(height: 16),

              // Status & Dates Card
              _buildInfoCard(
                icon: Icons.pending_actions_outlined,
                title: 'وضعیت درخواست',
                children: [
                  _buildInfoRow('وضعیت', widget.request.status.label),
                  const SizedBox(height: 12),
                  _buildInfoRow('تاریخ ثبت', _formatDate(widget.request.createdAt)),
                  if (widget.request.reviewedAt != null) ...[
                    const SizedBox(height: 12),
                    _buildInfoRow('تاریخ بررسی', _formatDate(widget.request.reviewedAt!)),
                  ],
                ],
              ),

              // Admin Feedback (if rejected)
              if (widget.request.adminFeedback != null) ...[
                const SizedBox(height: 16),
                _buildInfoCard(
                  icon: Icons.message_outlined,
                  title: 'بازخورد مدیر',
                  children: [
                    Text(
                      widget.request.adminFeedback!,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ],

              // Action Buttons (only for pending requests)
              if (isPending) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing ? null : _rejectRequest,
                        icon: const Icon(Icons.close),
                        label: const Text('رد درخواست'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _approveRequest,
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: _isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('تأیید درخواست'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(vertical: 16),
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

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioPlayer() {
    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final isPlaying = playerState?.playing ?? false;
        final processingState = playerState?.processingState;

        return Column(
          children: [
            // Seek Bar
            StreamBuilder<Duration>(
              stream: _player.positionStream,
              builder: (context, positionSnapshot) {
                final position = positionSnapshot.data ?? Duration.zero;
                final duration = _player.duration ?? Duration.zero;

                return Column(
                  children: [
                    Slider(
                      value: duration.inMilliseconds > 0
                          ? position.inMilliseconds.toDouble()
                          : 0,
                      min: 0,
                      max: duration.inMilliseconds.toDouble(),
                      activeColor: AppColors.primary,
                      onChanged: (value) {
                        _player.seek(Duration(milliseconds: value.toInt()));
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(position),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _formatDuration(duration),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Play/Pause Button
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    if (_player.position > Duration.zero) {
                      _player.seek(Duration.zero);
                    }
                  },
                  icon: const Icon(Icons.replay),
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () {
                    if (isPlaying) {
                      _player.pause();
                    } else {
                      _player.play();
                    }
                  },
                  icon: Icon(
                    processingState == ProcessingState.loading
                        ? Icons.hourglass_empty
                        : isPlaying
                            ? Icons.pause_circle
                            : Icons.play_circle,
                  ),
                  color: AppColors.primary,
                  iconSize: 64,
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () {
                    _player.stop();
                  },
                  icon: const Icon(Icons.stop),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return FarsiUtils.toFarsiDigits('$minutes:$seconds');
  }

  String _formatDate(DateTime date) {
    final year = FarsiUtils.toFarsiDigits(date.year.toString());
    final month = FarsiUtils.toFarsiDigits(date.month.toString().padLeft(2, '0'));
    final day = FarsiUtils.toFarsiDigits(date.day.toString().padLeft(2, '0'));
    return '$year/$month/$day';
  }
}
