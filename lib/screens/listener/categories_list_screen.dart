import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/screens/listener/category_screen.dart';
import 'package:myna/providers/home_providers.dart';
import 'package:myna/utils/app_logger.dart';
import 'package:myna/utils/farsi_utils.dart';

/// =============================================================================
/// CATEGORY SYSTEM DESIGN (Book Categories)
/// =============================================================================
///
/// This screen displays BOOK categories (دسته‌بندی‌ها) for audiobooks (is_music=false).
/// Music categories (سبک‌های موسیقی) are handled separately via music_categories table.
///
/// COUNT CALCULATION:
/// - Counts ONLY approved books (status='approved', is_music=false) in each category
/// - Uses a separate aggregation query for accurate counts
/// - Does NOT depend on ownership/entitlements - shows total available books
///
/// BEHAVIOR:
/// - Categories with 0 books are still shown (admin may have created them for future)
/// - Tapping a category shows only approved books in that category
/// =============================================================================

class CategoriesListScreen extends ConsumerStatefulWidget {
  const CategoriesListScreen({super.key});

  @override
  ConsumerState<CategoriesListScreen> createState() => _CategoriesListScreenState();
}

class _CategoriesListScreenState extends ConsumerState<CategoriesListScreen> {
  Map<int, int>? _bookCounts;

  @override
  void initState() {
    super.initState();
    _loadBookCounts();
  }

  Future<void> _loadBookCounts() async {
    // Load book counts separately - this is optional enhancement
    try {
      final countsResponse = await Supabase.instance.client
          .from('audiobooks')
          .select('category_id')
          .eq('status', 'approved')
          .eq('is_music', false);

      final countMap = <int, int>{};
      for (final row in countsResponse as List) {
        final categoryId = row['category_id'] as int?;
        if (categoryId != null) {
          countMap[categoryId] = (countMap[categoryId] ?? 0) + 1;
        }
      }

      if (mounted) {
        setState(() => _bookCounts = countMap);
      }
    } catch (e) {
      AppLogger.w('Failed to load book counts', error: e);
      // Don't fail - counts are optional
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use the same provider as home screen for consistency and caching
    final categoriesAsync = ref.watch(homeCategoriesProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('دسته‌بندی‌ها'),
        ),
        body: categoriesAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (error, stack) {
            AppLogger.e('Categories error', error: error);
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  const Text(
                    'خطا در بارگذاری دسته‌بندی‌ها',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => ref.invalidate(homeCategoriesProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('تلاش مجدد'),
                  ),
                ],
              ),
            );
          },
          data: (categories) {
            if (categories.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.category_outlined, size: 64, color: AppColors.textTertiary),
                    const SizedBox(height: 16),
                    const Text(
                      'دسته‌بندی‌ای یافت نشد',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () => ref.invalidate(homeCategoriesProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('بارگذاری مجدد'),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(homeCategoriesProvider);
                await _loadBookCounts();
              },
              color: AppColors.primary,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: categories.length,
                itemBuilder: (context, index) => _buildCategoryTile(categories[index]),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryTile(Map<String, dynamic> category) {
    // Get book count from separately loaded counts map
    final categoryId = category['id'] as int;
    final bookCount = _bookCounts?[categoryId] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => CategoryScreen(
              categoryId: category['id'] as int,
              categoryName: (category['name_fa'] as String?) ?? (category['name'] as String?) ?? '',
            ),
          ),
        ),
        tileColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getCategoryIcon((category['name_fa'] as String?) ?? ''),
            color: AppColors.primary,
          ),
        ),
        title: Text(
          (category['name_fa'] as String?) ?? (category['name'] as String?) ?? '',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${FarsiUtils.toFarsiDigits(bookCount)} کتاب',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_left, color: AppColors.textTertiary),
      ),
    );
  }

  IconData _getCategoryIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('رمان') || lower.contains('داستان')) return Icons.auto_stories;
    if (lower.contains('تاریخ')) return Icons.history_edu;
    if (lower.contains('علم') || lower.contains('دانش')) return Icons.science;
    if (lower.contains('روانشناسی') || lower.contains('خودسازی')) return Icons.psychology;
    if (lower.contains('کودک')) return Icons.child_care;
    if (lower.contains('مذهب') || lower.contains('دین')) return Icons.mosque;
    if (lower.contains('اقتصاد') || lower.contains('کسب')) return Icons.business;
    if (lower.contains('هنر')) return Icons.palette;
    if (lower.contains('ورزش')) return Icons.sports;
    if (lower.contains('سفر')) return Icons.flight;
    return Icons.category;
  }
}
