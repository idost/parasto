import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/utils/app_strings.dart';

/// Bottom sheet for gift functionality with email and message input.
/// Extracted from audiobook_detail_screen.dart for better maintainability.
class GiftBottomSheet extends StatefulWidget {
  final String bookTitle;
  final void Function(String email, String? message) onContinue;

  const GiftBottomSheet({
    super.key,
    required this.bookTitle,
    required this.onContinue,
  });

  @override
  State<GiftBottomSheet> createState() => _GiftBottomSheetState();
}

class _GiftBottomSheetState extends State<GiftBottomSheet> {
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isEmailValid = false;
  bool _showEmailError = false;
  bool _isVerifying = false;
  String? _verifyError;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _validateEmail() {
    final email = _emailController.text.trim();
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$');
    final isValid = emailRegex.hasMatch(email);
    setState(() {
      _isEmailValid = isValid;
      _verifyError = null;
      if (email.isNotEmpty && !isValid) {
        _showEmailError = true;
      } else if (isValid) {
        _showEmailError = false;
      }
    });
  }

  Future<void> _verifyAndContinue() async {
    if (!_isEmailValid || _isVerifying) return;

    setState(() {
      _isVerifying = true;
      _verifyError = null;
    });

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        setState(() {
          _isVerifying = false;
          _verifyError = 'لطفاً وارد حساب کاربری شوید';
        });
        return;
      }

      final response = await Supabase.instance.client.functions.invoke(
        'verify-gift-recipient',
        body: {'recipient_email': _emailController.text.trim()},
      );

      if (!mounted) return;

      final data = response.data as Map<String, dynamic>?;
      if (data == null) {
        setState(() {
          _isVerifying = false;
          _verifyError = 'خطا در بررسی ایمیل';
        });
        return;
      }

      final ok = data['ok'] as bool? ?? false;
      final reason = data['reason'] as String?;

      if (ok) {
        widget.onContinue(
          _emailController.text.trim(),
          _messageController.text.trim().isEmpty
              ? null
              : _messageController.text.trim(),
        );
      } else if (reason == 'not_found') {
        setState(() {
          _isVerifying = false;
          _verifyError = 'این ایمیل در پرستو ثبت نیست';
        });
      } else {
        setState(() {
          _isVerifying = false;
          _verifyError = 'خطا در بررسی ایمیل';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _verifyError = 'خطا در بررسی ایمیل';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppStrings.isLtr ? TextDirection.ltr : TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            // Icon
            const Icon(
              Icons.card_giftcard_rounded,
              size: 48,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            // Title
            Text(
              'هدیه دادن',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // Book title
            Text(
              widget.bookTitle,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Email field
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.left,
              decoration: InputDecoration(
                labelText: 'ایمیل گیرنده',
                hintText: 'example@email.com',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                prefixIcon: const Icon(Icons.email_rounded, color: AppColors.textSecondary),
                errorText: _showEmailError ? 'لطفاً ایمیل معتبر وارد کنید' : null,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.error),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.error, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Message field (optional)
            TextField(
              controller: _messageController,
              maxLines: 3,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: 'پیام (اختیاری)',
                hintText: 'پیامی برای گیرنده بنویسید...',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 48),
                  child: Icon(Icons.message_rounded, color: AppColors.textSecondary),
                ),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            // Verify error message
            if (_verifyError != null) ...[
              const SizedBox(height: 8),
              Text(
                _verifyError!,
                style: const TextStyle(color: AppColors.error, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isVerifying ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('انصراف'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_isEmailValid && !_isVerifying) ? _verifyAndContinue : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primary.withAlpha(77),
                      disabledForegroundColor: Colors.white.withAlpha(128),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('ادامه'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
