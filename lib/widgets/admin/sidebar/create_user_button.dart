import 'package:flutter/material.dart';
import 'package:myna/services/user_management_service.dart';
import 'package:myna/theme/app_theme.dart';

/// Stateful button for user creation with loading state.
class CreateUserButton extends StatefulWidget {
  final TextEditingController email;
  final TextEditingController displayName;
  final String role;
  final String roleLabel;
  final GlobalKey<FormState> formKey;

  const CreateUserButton({
    super.key,
    required this.email,
    required this.displayName,
    required this.role,
    required this.roleLabel,
    required this.formKey,
  });

  @override
  State<CreateUserButton> createState() => _CreateUserButtonState();
}

class _CreateUserButtonState extends State<CreateUserButton> {
  bool _isLoading = false;

  Future<void> _handleCreate() async {
    if (widget.formKey.currentState?.validate() != true) return;

    setState(() => _isLoading = true);

    final result = await UserManagementService.createUser(
      email: widget.email.text.trim(),
      displayName: widget.displayName.text.trim(),
      role: widget.role,
    );

    if (!mounted) return;

    Navigator.pop(context);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.roleLabel} جدید با موفقیت ایجاد شد.\n'
            'ایمیل دعوت به ${widget.email.text} ارسال شد.',
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 5),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'خطا در ایجاد کاربر'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleCreate,
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('ایجاد کاربر'),
    );
  }
}
