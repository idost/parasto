import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/utils/farsi_utils.dart';

/// Provider for book categories
final adminCategoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await Supabase.instance.client.from('categories').select('*').order('sort_order');
  return List<Map<String, dynamic>>.from(response);
});

/// Provider for music categories (سبک‌های موسیقی)
final adminMusicCategoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await Supabase.instance.client.from('music_categories').select('*').order('sort_order');
  return List<Map<String, dynamic>>.from(response);
});

class AdminCategoriesScreen extends ConsumerStatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  ConsumerState<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends ConsumerState<AdminCategoriesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('مدیریت دسته‌بندی‌ها'),
          centerTitle: true,
          automaticallyImplyLeading: false,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: const [
              Tab(icon: Icon(Icons.menu_book), text: 'کتاب‌ها'),
              Tab(icon: Icon(Icons.music_note), text: 'موسیقی'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            if (_tabController.index == 0) {
              _showBookCategoryDialog(context, null);
            } else {
              _showMusicCategoryDialog(context, null);
            }
          },
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildBookCategoriesTab(),
            _buildMusicCategoriesTab(),
          ],
        ),
      ),
    );
  }

  /// Book categories tab
  Widget _buildBookCategoriesTab() {
    final categoriesAsync = ref.watch(adminCategoriesProvider);

    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('خطا: $e', style: const TextStyle(color: AppColors.error))),
      data: (categories) {
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminCategoriesProvider),
          color: AppColors.primary,
          child: categories.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: const Center(
                        child: Text('دسته‌بندی کتاب یافت نشد', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    ),
                  ],
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: categories.length,
                  onReorder: (oldIndex, newIndex) => _reorderBookCategories(categories, oldIndex, newIndex),
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return Card(
                      key: ValueKey('book_${cat['id']}'),
                      color: AppColors.surface,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: AppRadius.small),
                          child: Center(child: Text(FarsiUtils.toFarsiDigits(index + 1), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
                        ),
                        title: Text((cat['name_fa'] as String?) ?? '', style: const TextStyle(color: AppColors.textPrimary)),
                        subtitle: Text((cat['is_active'] as bool?) == true ? 'فعال' : 'غیرفعال', style: TextStyle(color: (cat['is_active'] as bool?) == true ? AppColors.success : AppColors.error, fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit, color: AppColors.primary), onPressed: () => _showBookCategoryDialog(context, cat)),
                            IconButton(icon: const Icon(Icons.delete, color: AppColors.error), onPressed: () => _deleteBookCategory(context, cat['id'] as int)),
                            const Icon(Icons.drag_handle, color: AppColors.textTertiary),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  /// Music categories tab
  Widget _buildMusicCategoriesTab() {
    final musicCategoriesAsync = ref.watch(adminMusicCategoriesProvider);

    return musicCategoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('خطا: $e', style: const TextStyle(color: AppColors.error))),
      data: (categories) {
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminMusicCategoriesProvider),
          color: AppColors.primary,
          child: categories.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.music_off, size: 64, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            const Text('سبک موسیقی یافت نشد', style: TextStyle(color: AppColors.textSecondary)),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () => _showMusicCategoryDialog(context, null),
                              icon: const Icon(Icons.add),
                              label: const Text('افزودن سبک جدید'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: categories.length,
                  onReorder: (oldIndex, newIndex) => _reorderMusicCategories(categories, oldIndex, newIndex),
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final icon = cat['icon'] as String? ?? '🎵';
                    return Card(
                      key: ValueKey('music_${cat['id']}'),
                      color: AppColors.surface,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: AppRadius.small),
                          child: Center(child: Text(icon, style: const TextStyle(fontSize: 20))),
                        ),
                        title: Text((cat['name_fa'] as String?) ?? '', style: const TextStyle(color: AppColors.textPrimary)),
                        subtitle: Row(
                          children: [
                            Text(
                              (cat['is_active'] as bool?) == true ? 'فعال' : 'غیرفعال',
                              style: TextStyle(
                                color: (cat['is_active'] as bool?) == true ? AppColors.success : AppColors.error,
                                fontSize: 12,
                              ),
                            ),
                            if ((cat['name_en'] as String?)?.isNotEmpty == true) ...[
                              const SizedBox(width: 8),
                              Text(
                                '(${cat['name_en']})',
                                style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit, color: AppColors.primary), onPressed: () => _showMusicCategoryDialog(context, cat)),
                            IconButton(icon: const Icon(Icons.delete, color: AppColors.error), onPressed: () => _deleteMusicCategory(context, cat['id'] as int)),
                            const Icon(Icons.drag_handle, color: AppColors.textTertiary),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  /// Dialog for adding/editing book categories
  Future<void> _showBookCategoryDialog(BuildContext context, Map<String, dynamic>? category) async {
    final nameController = TextEditingController(text: (category?['name_fa'] as String?) ?? '');
    bool isActive = (category?['is_active'] as bool?) ?? true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(category == null ? 'افزودن دسته‌بندی کتاب' : 'ویرایش دسته‌بندی کتاب', style: const TextStyle(color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'نام دسته‌بندی',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: AppRadius.small),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('فعال', style: TextStyle(color: AppColors.textPrimary)),
                value: isActive,
                onChanged: (v) => setState(() => isActive = v),
                activeColor: AppColors.primary,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(category == null ? 'افزودن' : 'ذخیره')),
          ],
        ),
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        if (category == null) {
          await Supabase.instance.client.from('categories').insert({
            'name_fa': nameController.text.trim(),
            'is_active': isActive,
            'sort_order': 999,
          });
        } else {
          await Supabase.instance.client.from('categories').update({
            'name_fa': nameController.text.trim(),
            'is_active': isActive,
          }).eq('id', category['id'] as int);
        }
        ref.invalidate(adminCategoriesProvider);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ذخیره شد'), backgroundColor: AppColors.success));
      } on PostgrestException catch (e) {
        // Handle unique constraint violation (duplicate slug/name)
        if (e.code == '23505') {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('این دسته‌بندی یا نام مشابه آن از قبل وجود دارد.'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        } else {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا: ${e.message}'), backgroundColor: AppColors.error));
        }
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  /// Dialog for adding/editing music categories
  Future<void> _showMusicCategoryDialog(BuildContext context, Map<String, dynamic>? category) async {
    final nameFaController = TextEditingController(text: (category?['name_fa'] as String?) ?? '');
    final nameEnController = TextEditingController(text: (category?['name_en'] as String?) ?? '');
    final iconController = TextEditingController(text: (category?['icon'] as String?) ?? '🎵');
    bool isActive = (category?['is_active'] as bool?) ?? true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            category == null ? 'افزودن سبک موسیقی' : 'ویرایش سبک موسیقی',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon selector
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: AppRadius.medium,
                      ),
                      child: Center(
                        child: Text(
                          iconController.text.isNotEmpty ? iconController.text : '🎵',
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: iconController,
                        decoration: InputDecoration(
                          labelText: 'آیکون (ایموجی)',
                          hintText: '🎵',
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(borderRadius: AppRadius.small),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameFaController,
                  decoration: InputDecoration(
                    labelText: 'نام فارسی *',
                    hintText: 'مثال: پاپ',
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(borderRadius: AppRadius.small),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameEnController,
                  decoration: InputDecoration(
                    labelText: 'نام انگلیسی (اختیاری)',
                    hintText: 'Example: Pop',
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(borderRadius: AppRadius.small),
                  ),
                  textDirection: TextDirection.ltr,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('فعال', style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: const Text('نمایش در لیست انتخاب', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  value: isActive,
                  onChanged: (v) => setState(() => isActive = v),
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(category == null ? 'افزودن' : 'ذخیره')),
          ],
        ),
      ),
    );

    if (result == true && nameFaController.text.trim().isNotEmpty) {
      try {
        final data = {
          'name_fa': nameFaController.text.trim(),
          'name_en': nameEnController.text.trim().isEmpty ? null : nameEnController.text.trim(),
          'icon': iconController.text.trim().isEmpty ? '🎵' : iconController.text.trim(),
          'is_active': isActive,
        };

        if (category == null) {
          data['sort_order'] = 999;
          await Supabase.instance.client.from('music_categories').insert(data);
        } else {
          await Supabase.instance.client.from('music_categories').update(data).eq('id', category['id'] as int);
        }
        ref.invalidate(adminMusicCategoriesProvider);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ذخیره شد'), backgroundColor: AppColors.success));
      } on PostgrestException catch (e) {
        // Handle unique constraint violation (duplicate slug/name)
        if (e.code == '23505') {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('این سبک موسیقی یا نام مشابه آن از قبل وجود دارد.'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        } else {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا: ${e.message}'), backgroundColor: AppColors.error));
        }
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _deleteBookCategory(BuildContext context, int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('حذف دسته‌بندی', style: TextStyle(color: AppColors.error)),
        content: const Text('آیا مطمئن هستید؟ این عملیات قابل بازگشت نیست.', style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error), child: const Text('حذف')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('categories').delete().eq('id', id);
        ref.invalidate(adminCategoriesProvider);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حذف شد'), backgroundColor: AppColors.success));
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _deleteMusicCategory(BuildContext context, int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('حذف سبک موسیقی', style: TextStyle(color: AppColors.error)),
        content: const Text('آیا مطمئن هستید؟ این عملیات قابل بازگشت نیست.', style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error), child: const Text('حذف')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('music_categories').delete().eq('id', id);
        ref.invalidate(adminMusicCategoriesProvider);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حذف شد'), backgroundColor: AppColors.success));
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _reorderBookCategories(List<Map<String, dynamic>> categories, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final item = categories.removeAt(oldIndex);
    categories.insert(newIndex, item);

    try {
      for (int i = 0; i < categories.length; i++) {
        await Supabase.instance.client.from('categories').update({'sort_order': i}).eq('id', categories[i]['id'] as int);
      }
      ref.invalidate(adminCategoriesProvider);
    } catch (e) {
      ref.invalidate(adminCategoriesProvider);
    }
  }

  Future<void> _reorderMusicCategories(List<Map<String, dynamic>> categories, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final item = categories.removeAt(oldIndex);
    categories.insert(newIndex, item);

    try {
      for (int i = 0; i < categories.length; i++) {
        await Supabase.instance.client.from('music_categories').update({'sort_order': i}).eq('id', categories[i]['id'] as int);
      }
      ref.invalidate(adminMusicCategoriesProvider);
    } catch (e) {
      ref.invalidate(adminMusicCategoriesProvider);
    }
  }
}
