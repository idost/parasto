import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';

/// Filter option model
class FilterOption {
  final String value;
  final String label;

  const FilterOption({required this.value, required this.label});
}

/// Horizontal scrollable filter chips component
///
/// Features:
/// - Consistent chip styling with Parasto design
/// - Selected state with primary color and glow
/// - Horizontal scrolling for many options
/// - Label prefix for context
/// - RTL support
class FilterChipGroup extends StatelessWidget {
  final List<FilterOption> options;
  final String? selectedValue;
  final ValueChanged<String?> onChanged;
  final String label;

  const FilterChipGroup({
    super.key,
    required this.options,
    this.selectedValue,
    required this.onChanged,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label:',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: options.map((option) {
                final isSelected = selectedValue == option.value;
                return Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: GestureDetector(
                    onTap: () => onChanged(option.value),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border,
                          width: 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  spreadRadius: -2,
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        option.label,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.background
                              : AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
