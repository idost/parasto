import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/providers/promotion_providers.dart';
import 'package:myna/screens/admin/admin_banner_form_screen.dart';
import 'package:myna/screens/admin/admin_shelf_form_screen.dart';
import 'package:myna/screens/admin/admin_shelf_items_screen.dart';

class AdminPromotionsScreen extends ConsumerWidget {
  const AdminPromotionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            title: const Text('تبلیغات و پیشنهادات'),
            centerTitle: true,
            bottom: const TabBar(
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textTertiary,
              tabs: [
                Tab(text: 'بنرها', icon: Icon(Icons.view_carousel)),
                Tab(text: 'قفسه‌ها', icon: Icon(Icons.shelves)),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              _BannersTab(),
              _ShelvesTab(),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// BANNERS TAB
// ============================================

class _BannersTab extends ConsumerWidget {
  const _BannersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannersAsync = ref.watch(adminBannersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: bannersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              const Text('خطا در بارگذاری بنرها', style: TextStyle(color: AppColors.error)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(adminBannersProvider),
                child: const Text('تلاش مجدد'),
              ),
            ],
          ),
        ),
        data: (banners) {
          if (banners.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.view_carousel_outlined, size: 64, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text('هنوز بنری ایجاد نشده', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _addBanner(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('افزودن بنر'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminBannersProvider),
            color: AppColors.primary,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: banners.length,
              itemBuilder: (context, index) {
                final banner = banners[index];
                return _BannerCard(banner: banner, onUpdate: () => ref.invalidate(adminBannersProvider));
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addBanner(context, ref),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _addBanner(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AdminBannerFormScreen()),
    );
    if (result == true) {
      ref.invalidate(adminBannersProvider);
    }
  }
}

class _BannerCard extends StatelessWidget {
  final Map<String, dynamic> banner;
  final VoidCallback onUpdate;

  const _BannerCard({required this.banner, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final isActive = banner['is_active'] == true;
    final targetType = banner['target_type'] as String? ?? 'audiobook';

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner image preview
          if (banner['image_url'] != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                banner['image_url'] as String,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 120,
                  color: AppColors.surfaceLight,
                  child: const Center(child: Icon(Icons.broken_image, color: AppColors.textTertiary)),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (banner['title_fa'] as String?) ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isActive ? 'فعال' : 'غیرفعال',
                        style: TextStyle(color: isActive ? AppColors.success : AppColors.error, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                if (banner['subtitle_fa'] != null && (banner['subtitle_fa'] as String).isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    banner['subtitle_fa'] as String,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      targetType == 'audiobook' ? Icons.book : targetType == 'shelf' ? Icons.shelves : Icons.category,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      targetType == 'audiobook' ? 'کتاب' : targetType == 'shelf' ? 'قفسه' : 'دسته‌بندی',
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    ),
                    const Spacer(),
                    Text(
                      'ترتیب: ${banner['sort_order'] ?? 0}',
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _editBanner(context),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('ویرایش'),
                    ),
                    TextButton.icon(
                      onPressed: () => _toggleActive(context),
                      icon: Icon(isActive ? Icons.visibility_off : Icons.visibility, size: 18),
                      label: Text(isActive ? 'غیرفعال' : 'فعال'),
                    ),
                    TextButton.icon(
                      onPressed: () => _deleteBanner(context),
                      icon: const Icon(Icons.delete, size: 18, color: AppColors.error),
                      label: const Text('حذف', style: TextStyle(color: AppColors.error)),
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

  void _editBanner(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AdminBannerFormScreen(banner: banner)),
    );
    if (result == true) {
      onUpdate();
    }
  }

  Future<void> _toggleActive(BuildContext context) async {
    try {
      await Supabase.instance.client
          .from('promo_banners')
          .update({'is_active': !(banner['is_active'] == true)})
          .eq('id', banner['id'] as Object);
      onUpdate();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteBanner(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('حذف بنر', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('آیا از حذف این بنر اطمینان دارید؟', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('promo_banners').delete().eq('id', banner['id'] as Object);
        onUpdate();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطا: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }
}

// ============================================
// SHELVES TAB
// ============================================

class _ShelvesTab extends ConsumerWidget {
  const _ShelvesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shelvesAsync = ref.watch(adminShelvesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: shelvesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              const Text('خطا در بارگذاری قفسه‌ها', style: TextStyle(color: AppColors.error)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(adminShelvesProvider),
                child: const Text('تلاش مجدد'),
              ),
            ],
          ),
        ),
        data: (shelves) {
          if (shelves.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shelves, size: 64, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text('هنوز قفسه‌ای ایجاد نشده', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _addShelf(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('افزودن قفسه'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminShelvesProvider),
            color: AppColors.primary,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: shelves.length,
              itemBuilder: (context, index) {
                final shelf = shelves[index];
                return _ShelfCard(shelf: shelf, onUpdate: () => ref.invalidate(adminShelvesProvider));
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addShelf(context, ref),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _addShelf(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AdminShelfFormScreen()),
    );
    if (result == true) {
      ref.invalidate(adminShelvesProvider);
    }
  }
}

class _ShelfCard extends StatelessWidget {
  final Map<String, dynamic> shelf;
  final VoidCallback onUpdate;

  const _ShelfCard({required this.shelf, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final isActive = shelf['is_active'] == true;

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shelves, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    (shelf['title_fa'] as String?) ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isActive ? 'فعال' : 'غیرفعال',
                    style: TextStyle(color: isActive ? AppColors.success : AppColors.error, fontSize: 12),
                  ),
                ),
              ],
            ),
            if (shelf['description_fa'] != null && (shelf['description_fa'] as String).isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                shelf['description_fa'] as String,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'ترتیب: ${shelf['sort_order'] ?? 0}',
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _manageItems(context),
                    icon: const Icon(Icons.library_books, size: 18),
                    label: const Text('مدیریت کتاب‌ها'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _editShelf(context),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('ویرایش'),
                ),
                TextButton.icon(
                  onPressed: () => _toggleActive(context),
                  icon: Icon(isActive ? Icons.visibility_off : Icons.visibility, size: 18),
                  label: Text(isActive ? 'غیرفعال' : 'فعال'),
                ),
                TextButton.icon(
                  onPressed: () => _deleteShelf(context),
                  icon: const Icon(Icons.delete, size: 18, color: AppColors.error),
                  label: const Text('حذف', style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _manageItems(BuildContext context) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AdminShelfItemsScreen(
          shelfId: shelf['id'] as int,
          shelfTitle: (shelf['title_fa'] as String?) ?? '',
        ),
      ),
    );
    onUpdate();
  }

  void _editShelf(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AdminShelfFormScreen(shelf: shelf)),
    );
    if (result == true) {
      onUpdate();
    }
  }

  Future<void> _toggleActive(BuildContext context) async {
    try {
      await Supabase.instance.client
          .from('promo_shelves')
          .update({'is_active': !(shelf['is_active'] == true)})
          .eq('id', shelf['id'] as Object);
      onUpdate();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteShelf(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('حذف قفسه', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('آیا از حذف این قفسه اطمینان دارید؟ تمام کتاب‌های این قفسه حذف خواهند شد.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('promo_shelves').delete().eq('id', shelf['id'] as Object);
        onUpdate();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطا: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }
}
