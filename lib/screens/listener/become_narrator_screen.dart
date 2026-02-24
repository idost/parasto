import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/widgets/common/voice_recorder_widget.dart';
import 'package:myna/providers/narrator_request_providers.dart';

/// Screen for users to request narrator status
///
/// Features:
/// - Experience text input (min 20 chars)
/// - Voice sample recording (3 minutes max)
/// - Form validation
/// - Submission to Supabase
class BecomeNarratorScreen extends ConsumerStatefulWidget {
  const BecomeNarratorScreen({super.key});

  @override
  ConsumerState<BecomeNarratorScreen> createState() => _BecomeNarratorScreenState();
}

class _BecomeNarratorScreenState extends ConsumerState<BecomeNarratorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _experienceController = TextEditingController();
  File? _voiceSampleFile;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _experienceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_voiceSampleFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لطفاً نمونه صوتی خود را ضبط کنید'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(narratorRequestServiceProvider);
      await service.submitRequest(
        experienceText: _experienceController.text.trim(),
        voiceSampleFile: _voiceSampleFile!,
      );

      if (!mounted) return;

      // Show success and go back
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('درخواست شما با موفقیت ثبت شد. پس از بررسی توسط مدیران نتیجه به شما اطلاع داده خواهد شد.'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 4),
        ),
      );

      // Invalidate providers to refresh data
      ref.invalidate(userPendingRequestProvider);
      ref.invalidate(userRequestsProvider);

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در ثبت درخواست: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('درخواست گویندگی'),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.checklist_outlined,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'شرایط گویندگی',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInfoItem('صدای واضح و رسا'),
                      _buildInfoItem('تجربه یا علاقه به خواندن کتاب یا آواز'),
                      _buildInfoItem('ارسال نمونه صوتی ۳ دقیقه‌ای'),
                      _buildInfoItem('صبر برای تأیید توسط مدیران'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Experience Text Field
                const Text(
                  'تجربیات و علایق شما',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _experienceController,
                  maxLines: 6,
                  maxLength: 500,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'درباره تجربیات گویندگی، علاقه به ادبیات، سبک صوتی و... بنویسید',
                    hintStyle: const TextStyle(color: AppColors.textTertiary),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: AppColors.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: AppColors.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                    counterStyle: const TextStyle(color: AppColors.textTertiary),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'لطفاً تجربیات خود را بنویسید';
                    }
                    if (value.trim().length < 20) {
                      return 'لطفاً حداقل ۲۰ کاراکتر بنویسید';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Voice Recorder
                const Text(
                  'نمونه صوتی',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                VoiceRecorderWidget(
                  onRecordingComplete: (file) {
                    setState(() => _voiceSampleFile = file);
                  },
                ),
                const SizedBox(height: 32),

                // Submit Button
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textOnPrimary,
                          ),
                        )
                      : const Text(
                          'ارسال درخواست',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textOnPrimary,
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

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
