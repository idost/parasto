import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';

/// Modern search bar component for admin screens
///
/// Features:
/// - Consistent Parasto styling
/// - Search icon prefix
/// - Clear button when text is present
/// - Subtle shadow and border
/// - RTL support
class AdminSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  const AdminSearchBar({
    super.key,
    this.controller,
    required this.hintText,
    this.onChanged,
    this.onClear,
  });

  @override
  State<AdminSearchBar> createState() => _AdminSearchBarState();
}

class _AdminSearchBarState extends State<AdminSearchBar> {
  late TextEditingController _controller;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_onTextChanged);
    _hasText = _controller.text.isNotEmpty;
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_onTextChanged);
    }
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  void _handleClear() {
    _controller.clear();
    widget.onClear?.call();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.borderSubtle,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: const TextStyle(color: AppColors.textTertiary),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textSecondary,
          ),
          suffixIcon: _hasText
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, color: AppColors.textSecondary),
                  onPressed: _handleClear,
                )
              : null,
          filled: false,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
