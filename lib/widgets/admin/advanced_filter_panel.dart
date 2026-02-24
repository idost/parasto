import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/services/catalog_service.dart';

/// Filter state for content management
class ContentFilters {
  final int? categoryId;
  final String? priceFilter; // null = all, 'free', 'paid'
  final String sortBy; // 'newest', 'oldest', 'title', 'popular'
  final bool sortAscending;

  const ContentFilters({
    this.categoryId,
    this.priceFilter,
    this.sortBy = 'newest',
    this.sortAscending = false,
  });

  ContentFilters copyWith({
    int? categoryId,
    String? priceFilter,
    String? sortBy,
    bool? sortAscending,
    bool clearCategory = false,
    bool clearPrice = false,
  }) {
    return ContentFilters(
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      priceFilter: clearPrice ? null : (priceFilter ?? this.priceFilter),
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }

  bool get hasActiveFilters => categoryId != null || priceFilter != null;

  int get activeFilterCount {
    int count = 0;
    if (categoryId != null) count++;
    if (priceFilter != null) count++;
    return count;
  }
}

/// Advanced filter panel for content management
class AdvancedFilterPanel extends ConsumerStatefulWidget {
  final ContentFilters filters;
  final ValueChanged<ContentFilters> onFiltersChanged;
  final VoidCallback? onClose;

  const AdvancedFilterPanel({
    super.key,
    required this.filters,
    required this.onFiltersChanged,
    this.onClose,
  });

  @override
  ConsumerState<AdvancedFilterPanel> createState() => _AdvancedFilterPanelState();
}

class _AdvancedFilterPanelState extends ConsumerState<AdvancedFilterPanel> {
  late ContentFilters _localFilters;

  @override
  void initState() {
    super.initState();
    _localFilters = widget.filters;
  }

  @override
  void didUpdateWidget(AdvancedFilterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filters != widget.filters) {
      _localFilters = widget.filters;
    }
  }

  void _updateFilters(ContentFilters newFilters) {
    setState(() => _localFilters = newFilters);
    widget.onFiltersChanged(newFilters);
  }

  void _clearAllFilters() {
    final clearedFilters = const ContentFilters();
    setState(() => _localFilters = clearedFilters);
    widget.onFiltersChanged(clearedFilters);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.filter_list_rounded, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'فیلترهای پیشرفته',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                if (_localFilters.hasActiveFilters)
                  TextButton.icon(
                    onPressed: _clearAllFilters,
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('پاک کردن'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                if (widget.onClose != null)
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, size: 20),
                    color: AppColors.textSecondary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.borderSubtle),

          // Filter sections
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category filter
                _buildSectionLabel('دسته‌بندی'),
                const SizedBox(height: 8),
                categoriesAsync.when(
                  loading: () => const SizedBox(
                    height: 36,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (_, __) => const Text('خطا در بارگذاری', style: TextStyle(color: AppColors.error)),
                  data: (categories) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FilterChip(
                        label: 'همه',
                        isSelected: _localFilters.categoryId == null,
                        onTap: () => _updateFilters(_localFilters.copyWith(clearCategory: true)),
                      ),
                      ...categories.map((cat) => _FilterChip(
                            label: cat.nameFa,
                            isSelected: _localFilters.categoryId == cat.id,
                            onTap: () => _updateFilters(_localFilters.copyWith(categoryId: cat.id)),
                          )),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Price filter
                _buildSectionLabel('قیمت'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterChip(
                      label: 'همه',
                      isSelected: _localFilters.priceFilter == null,
                      onTap: () => _updateFilters(_localFilters.copyWith(clearPrice: true)),
                    ),
                    _FilterChip(
                      label: 'رایگان',
                      icon: Icons.money_off_rounded,
                      isSelected: _localFilters.priceFilter == 'free',
                      onTap: () => _updateFilters(_localFilters.copyWith(priceFilter: 'free')),
                    ),
                    _FilterChip(
                      label: 'پولی',
                      icon: Icons.attach_money_rounded,
                      isSelected: _localFilters.priceFilter == 'paid',
                      onTap: () => _updateFilters(_localFilters.copyWith(priceFilter: 'paid')),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Sort options
                _buildSectionLabel('مرتب‌سازی'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterChip(
                      label: 'جدیدترین',
                      icon: Icons.schedule_rounded,
                      isSelected: _localFilters.sortBy == 'newest',
                      onTap: () => _updateFilters(_localFilters.copyWith(sortBy: 'newest', sortAscending: false)),
                    ),
                    _FilterChip(
                      label: 'قدیمی‌ترین',
                      icon: Icons.history_rounded,
                      isSelected: _localFilters.sortBy == 'oldest',
                      onTap: () => _updateFilters(_localFilters.copyWith(sortBy: 'oldest', sortAscending: true)),
                    ),
                    _FilterChip(
                      label: 'عنوان (الف-ی)',
                      icon: Icons.sort_by_alpha_rounded,
                      isSelected: _localFilters.sortBy == 'title',
                      onTap: () => _updateFilters(_localFilters.copyWith(sortBy: 'title', sortAscending: true)),
                    ),
                    _FilterChip(
                      label: 'محبوب‌ترین',
                      icon: Icons.trending_up_rounded,
                      isSelected: _localFilters.sortBy == 'popular',
                      onTap: () => _updateFilters(_localFilters.copyWith(sortBy: 'popular', sortAscending: false)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.primary : AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact filter button that shows active filter count
class FilterButton extends StatelessWidget {
  final ContentFilters filters;
  final VoidCallback onTap;

  const FilterButton({
    super.key,
    required this.filters,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasFilters = filters.hasActiveFilters;
    final filterCount = filters.activeFilterCount;

    return Material(
      color: hasFilters ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasFilters ? AppColors.primary : AppColors.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_list_rounded,
                size: 18,
                color: hasFilters ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'فیلتر',
                style: TextStyle(
                  color: hasFilters ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: hasFilters ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
              if (filterCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    filterCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
