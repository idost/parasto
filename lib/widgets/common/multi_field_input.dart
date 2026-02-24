import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';

/// A widget that allows users to add multiple values for a single field type.
///
/// Displays a list of text fields with add/remove buttons.
/// Values are returned as a list and can be stored as comma-separated strings.
///
/// Example usage:
/// ```dart
/// MultiFieldInput(
///   label: 'گوینده',
///   hintText: 'نام گوینده',
///   initialValues: ['محمد رضایی'],
///   onChanged: (values) => _narratorNames = values,
/// )
/// ```
class MultiFieldInput extends StatefulWidget {
  /// Label displayed above the fields (e.g., "گوینده", "نویسنده")
  final String label;

  /// Hint text shown in empty fields
  final String? hintText;

  /// Initial values to populate the fields with
  final List<String> initialValues;

  /// Callback when values change
  final ValueChanged<List<String>> onChanged;

  /// Maximum number of fields allowed (default: 5)
  final int maxFields;

  /// Whether this field is required (at least one non-empty value)
  final bool isRequired;

  /// Custom validator for each field value
  final String? Function(String?)? validator;

  const MultiFieldInput({
    required this.label,
    required this.onChanged,
    this.hintText,
    this.initialValues = const [],
    this.maxFields = 5,
    this.isRequired = false,
    this.validator,
    super.key,
  });

  @override
  State<MultiFieldInput> createState() => _MultiFieldInputState();
}

class _MultiFieldInputState extends State<MultiFieldInput> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    // Start with initial values or at least one empty field
    final initialCount = widget.initialValues.isEmpty ? 1 : widget.initialValues.length;

    _controllers = List.generate(
      initialCount,
      (index) => TextEditingController(
        text: index < widget.initialValues.length ? widget.initialValues[index] : '',
      ),
    );

    _focusNodes = List.generate(initialCount, (_) => FocusNode());

    // Add listeners to each controller
    for (final controller in _controllers) {
      controller.addListener(_onValueChanged);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.removeListener(_onValueChanged);
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _onValueChanged() {
    // Collect all non-empty values
    final values = _controllers
        .map((c) => c.text.trim())
        .where((v) => v.isNotEmpty)
        .toList();
    widget.onChanged(values);
  }

  void _addField() {
    if (_controllers.length >= widget.maxFields) return;

    setState(() {
      final newController = TextEditingController();
      newController.addListener(_onValueChanged);
      _controllers.add(newController);
      _focusNodes.add(FocusNode());
    });

    // Focus the new field after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes.last.requestFocus();
    });
  }

  void _removeField(int index) {
    if (_controllers.length <= 1) return;

    setState(() {
      _controllers[index].removeListener(_onValueChanged);
      _controllers[index].dispose();
      _controllers.removeAt(index);

      _focusNodes[index].dispose();
      _focusNodes.removeAt(index);
    });

    _onValueChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          widget.label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),

        // Fields list
        ...List.generate(_controllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                // Text field
                Expanded(
                  child: TextFormField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: const BorderSide(color: AppColors.borderSubtle),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: const BorderSide(color: AppColors.borderSubtle),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: const BorderSide(color: AppColors.error),
                      ),
                    ),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    validator: (value) {
                      // Only validate first field if required
                      if (widget.isRequired && index == 0 && (value == null || value.trim().isEmpty)) {
                        return 'این فیلد الزامی است';
                      }
                      // Custom validator
                      if (widget.validator != null && value != null && value.isNotEmpty) {
                        return widget.validator!(value);
                      }
                      return null;
                    },
                  ),
                ),

                // Remove button (only show if more than 1 field)
                if (_controllers.length > 1) ...[
                  const SizedBox(width: 8),
                  _buildRemoveButton(index),
                ],
              ],
            ),
          );
        }),

        // Add button
        if (_controllers.length < widget.maxFields)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _buildAddButton(),
          ),
      ],
    );
  }

  Widget _buildRemoveButton(int index) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _removeField(index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.close_rounded,
            color: AppColors.error,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _addField,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.add_rounded,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                '+ افزودن ${widget.label}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Extension to convert MultiFieldInput values to/from comma-separated strings
extension MultiFieldUtils on String {
  /// Split a comma-separated string into a list of trimmed values
  List<String> toMultiFieldValues() {
    return split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
}

extension MultiFieldListUtils on List<String> {
  /// Join a list of values into a comma-separated string
  String toCommaSeparated() {
    return where((e) => e.isNotEmpty).join(', ');
  }
}
