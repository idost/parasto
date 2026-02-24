import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/models/search_result.dart';
import 'package:myna/providers/search_providers.dart';
import 'package:myna/widgets/admin/search_result_item.dart';

/// Global search dialog with keyboard shortcut support (Ctrl/Cmd + K)
class GlobalSearchDialog extends ConsumerStatefulWidget {
  const GlobalSearchDialog({super.key});

  @override
  ConsumerState<GlobalSearchDialog> createState() => _GlobalSearchDialogState();
}

class _GlobalSearchDialogState extends ConsumerState<GlobalSearchDialog> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(debouncedSearchProvider);
    final results = ref.watch(searchResultsProvider);
    final typeFilters = ref.watch(searchTypesFilterProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 560),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search input
              _buildSearchInput(),

              // Type filters
              _buildTypeFilters(typeFilters),

              const Divider(height: 1, color: AppColors.borderSubtle),

              // Results or empty state
              Flexible(
                child: query.isEmpty
                    ? _buildEmptyState(
                        icon: Icons.search_rounded,
                        message: 'جستجو کنید',
                        subtitle: 'حداقل ۲ حرف وارد کنید',
                      )
                    : _buildSearchResults(results),
              ),

              // Footer
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        decoration: InputDecoration(
          hintText: 'جستجو در همه بخش‌ها...',
          hintStyle: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 15,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textSecondary,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  color: AppColors.textTertiary,
                  iconSize: 20,
                  onPressed: () {
                    _searchController.clear();
                    ref.read(debouncedSearchProvider.notifier).clear();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppColors.surfaceLight,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
        ),
        onChanged: (value) {
          setState(() {}); // Update suffix icon
          ref.read(debouncedSearchProvider.notifier).updateQuery(value);
        },
      ),
    );
  }

  Widget _buildTypeFilters(Set<SearchResultType> selectedTypes) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // All filter
            FilterChip(
              label: const Text('همه'),
              selected: selectedTypes.length == SearchResultType.values.length,
              onSelected: (_) {
                ref.read(searchTypesFilterProvider.notifier).state =
                    SearchResultType.values.toSet();
              },
              selectedColor: AppColors.primary.withValues(alpha: 0.15),
              checkmarkColor: AppColors.primary,
              labelStyle: TextStyle(
                color: selectedTypes.length == SearchResultType.values.length
                    ? AppColors.primary
                    : AppColors.textSecondary,
                fontSize: 12,
              ),
              backgroundColor: AppColors.surfaceLight,
              side: BorderSide(
                color: selectedTypes.length == SearchResultType.values.length
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : AppColors.borderSubtle,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),
            // Type filters
            ...SearchResultType.values.map((type) {
              final isSelected = selectedTypes.contains(type);
              final color = _getTypeColor(type);
              return Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: FilterChip(
                  avatar: Icon(
                    _getTypeIcon(type),
                    size: 14,
                    color: isSelected ? color : AppColors.textSecondary,
                  ),
                  label: Text(_getTypeLabel(type)),
                  selected: isSelected &&
                      selectedTypes.length != SearchResultType.values.length,
                  onSelected: (selected) {
                    final newSet = Set<SearchResultType>.from(selectedTypes);
                    if (selected) {
                      newSet.add(type);
                    } else if (newSet.length > 1) {
                      newSet.remove(type);
                    }
                    ref.read(searchTypesFilterProvider.notifier).state = newSet;
                  },
                  selectedColor: color.withValues(alpha: 0.15),
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: isSelected &&
                            selectedTypes.length != SearchResultType.values.length
                        ? color
                        : AppColors.textSecondary,
                    fontSize: 11,
                  ),
                  backgroundColor: AppColors.surfaceLight,
                  side: BorderSide(
                    color: isSelected &&
                            selectedTypes.length != SearchResultType.values.length
                        ? color.withValues(alpha: 0.3)
                        : AppColors.borderSubtle,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(AsyncValue<List<SearchResult>> results) {
    return results.when(
      data: (items) {
        if (items.isEmpty) {
          return _buildEmptyState(
            icon: Icons.search_off_rounded,
            message: 'نتیجه‌ای یافت نشد',
            subtitle: 'عبارت دیگری را جستجو کنید',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final result = items[index];
            return SearchResultItem(
              result: result,
              showDivider: index < items.length - 1,
              onTap: () => _handleResultTap(result),
            );
          },
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (_, __) => _buildEmptyState(
        icon: Icons.error_outline_rounded,
        message: 'خطا در جستجو',
        subtitle: 'لطفاً دوباره تلاش کنید',
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    String? subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      child: Row(
        children: [
          // Keyboard shortcuts
          _buildShortcutHint('↑↓', 'انتخاب'),
          const SizedBox(width: 16),
          _buildShortcutHint('↵', 'باز کردن'),
          const SizedBox(width: 16),
          _buildShortcutHint('esc', 'بستن'),
          const Spacer(),
          // Close button
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutHint(String key, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Text(
            key,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  void _handleResultTap(SearchResult result) {
    // Close dialog and navigate
    Navigator.of(context).pop();
    Navigator.of(context).pushNamed(result.route);
  }

  IconData _getTypeIcon(SearchResultType type) {
    switch (type) {
      case SearchResultType.audiobook:
        return Icons.menu_book_rounded;
      case SearchResultType.user:
        return Icons.person_rounded;
      case SearchResultType.creator:
        return Icons.record_voice_over_rounded;
      case SearchResultType.ticket:
        return Icons.support_agent_rounded;
    }
  }

  Color _getTypeColor(SearchResultType type) {
    switch (type) {
      case SearchResultType.audiobook:
        return AppColors.primary;
      case SearchResultType.user:
        return AppColors.info;
      case SearchResultType.creator:
        return const Color(0xFFA855F7);
      case SearchResultType.ticket:
        return AppColors.warning;
    }
  }

  String _getTypeLabel(SearchResultType type) {
    switch (type) {
      case SearchResultType.audiobook:
        return 'محتوا';
      case SearchResultType.user:
        return 'کاربر';
      case SearchResultType.creator:
        return 'سازنده';
      case SearchResultType.ticket:
        return 'تیکت';
    }
  }
}

/// Intent for opening global search
class OpenSearchIntent extends Intent {
  const OpenSearchIntent();
}

/// Show global search dialog
void showGlobalSearch(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => const GlobalSearchDialog(),
  );
}
