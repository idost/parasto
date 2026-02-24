import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';

/// A single filter option with a display label and typed value.
class FilterOption<T> {
  final String label;
  final T value;

  const FilterOption({required this.label, required this.value});
}

/// Horizontally scrollable row of filter chips (single-select).
///
/// Active chip: filled accent color, white text.
/// Inactive chip: outlined border, secondary text.
/// Pill shape with borderRadius: 20.
/// RTL-safe: uses [EdgeInsetsDirectional] for padding.
class FilterChipRow<T> extends StatelessWidget {
  final List<FilterOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  const FilterChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = options[index];
          final isActive = option.value == selected;
          return _ChipButton(
            label: option.label,
            isActive: isActive,
            onTap: () => onChanged(option.value),
          );
        },
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ChipButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: isActive
                ? null
                : Border.all(color: AppColors.border, width: 1),
          ),
          child: Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: isActive ? AppColors.textOnPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
