import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/services/feedback_service.dart';
import 'package:myna/providers/feedback_providers.dart';

/// Dialog for admin to add feedback on an audiobook or chapter
class AdminFeedbackDialog extends ConsumerStatefulWidget {
  final int audiobookId;
  final String narratorId;
  final int? chapterId;
  final String? chapterTitle;
  final FeedbackType? initialType;

  const AdminFeedbackDialog({
    super.key,
    required this.audiobookId,
    required this.narratorId,
    this.chapterId,
    this.chapterTitle,
    this.initialType,
  });

  @override
  ConsumerState<AdminFeedbackDialog> createState() => _AdminFeedbackDialogState();
}

class _AdminFeedbackDialogState extends ConsumerState<AdminFeedbackDialog> {
  final _messageController = TextEditingController();
  late FeedbackType _selectedType;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? FeedbackType.info;
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لطفاً پیام خود را وارد کنید'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(feedbackServiceProvider);

      if (widget.chapterId != null) {
        await service.addChapterFeedback(
          audiobookId: widget.audiobookId,
          chapterId: widget.chapterId!,
          narratorId: widget.narratorId,
          message: message,
          feedbackType: _selectedType,
        );
      } else {
        await service.addAudiobookFeedback(
          audiobookId: widget.audiobookId,
          narratorId: widget.narratorId,
          message: message,
          feedbackType: _selectedType,
        );
      }

      // Invalidate the feedback provider to refresh the list
      ref.invalidate(audiobookFeedbackProvider(widget.audiobookId));

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('بازخورد ارسال شد'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در ارسال بازخورد: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isChapterFeedback = widget.chapterId != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    isChapterFeedback ? Icons.audiotrack : Icons.book,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isChapterFeedback
                          ? 'بازخورد برای فصل: ${widget.chapterTitle ?? ''}'
                          : 'بازخورد برای کتاب',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textTertiary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: AppColors.border),
              const SizedBox(height: 12),

              // Feedback type selector
              const Text(
                'نوع بازخورد',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: FeedbackType.values.map((type) {
                  final isSelected = _selectedType == type;
                  return ChoiceChip(
                    label: Text(type.label),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedType = type);
                    },
                    selectedColor: _getTypeColor(type).withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? _getTypeColor(type) : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: AppColors.background,
                    side: BorderSide(
                      color: isSelected ? _getTypeColor(type) : AppColors.border,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Message input
              const Text(
                'پیام',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _messageController,
                maxLines: 4,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: _getHintText(),
                  hintStyle: const TextStyle(color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Submit button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getTypeColor(_selectedType),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'ارسال بازخورد',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(FeedbackType type) {
    switch (type) {
      case FeedbackType.info:
        return AppColors.primary;
      case FeedbackType.changeRequired:
        return AppColors.warning;
      case FeedbackType.rejectionReason:
        return AppColors.error;
    }
  }

  String _getHintText() {
    switch (_selectedType) {
      case FeedbackType.info:
        return 'نکته یا توضیحی برای گوینده...';
      case FeedbackType.changeRequired:
        return 'چه تغییراتی باید انجام شود...';
      case FeedbackType.rejectionReason:
        return 'دلیل رد شدن کتاب/فصل...';
    }
  }
}

/// Helper function to show the dialog
Future<bool?> showAdminFeedbackDialog(
  BuildContext context, {
  required int audiobookId,
  required String narratorId,
  int? chapterId,
  String? chapterTitle,
  FeedbackType? initialType,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AdminFeedbackDialog(
      audiobookId: audiobookId,
      narratorId: narratorId,
      chapterId: chapterId,
      chapterTitle: chapterTitle,
      initialType: initialType,
    ),
  );
}
