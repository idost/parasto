import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';

class AdminShelfItemsScreen extends ConsumerStatefulWidget {
  final int shelfId;
  final String shelfTitle;

  const AdminShelfItemsScreen({
    super.key,
    required this.shelfId,
    required this.shelfTitle,
  });

  @override
  ConsumerState<AdminShelfItemsScreen> createState() => _AdminShelfItemsScreenState();
}

class _AdminShelfItemsScreenState extends ConsumerState<AdminShelfItemsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  bool _isAdding = false;

  // Search state
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('promo_shelf_items')
          .select('*, audiobooks(id, title_fa, cover_url)')
          .eq('shelf_id', widget.shelfId)
          .order('sort_order');
      setState(() {
        _items = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _searchAudiobooks(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      // Get IDs of books already in shelf
      final existingIds = _items.map((i) => i['audiobook_id']).toSet();

      // Search for audiobooks to add to shelf - show more results for better UX
      final response = await Supabase.instance.client
          .from('audiobooks')
          .select('id, title_fa, cover_url')
          .or('title_fa.ilike.%$query%,title_en.ilike.%$query%')
          .eq('status', 'approved')
          .limit(50);

      final results = List<Map<String, dynamic>>.from(response)
          .where((book) => !existingIds.contains(book['id']))
          .toList();

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _addBook(Map<String, dynamic> book) async {
    setState(() => _isAdding = true);
    try {
      // Get max sort_order
      final maxOrder = _items.isEmpty ? 0 : _items.map((i) => (i['sort_order'] as int?) ?? 0).reduce((a, b) => a > b ? a : b);

      await Supabase.instance.client.from('promo_shelf_items').insert({
        'shelf_id': widget.shelfId,
        'audiobook_id': book['id'],
        'sort_order': maxOrder + 1,
      });

      _searchController.clear();
      setState(() {
        _searchResults = [];
      });
      await _loadItems();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('کتاب اضافه شد'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() => _isAdding = false);
    }
  }

  Future<void> _removeBook(int itemId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('حذف کتاب', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('آیا از حذف این کتاب از قفسه اطمینان دارید؟', style: TextStyle(color: AppColors.textSecondary)),
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
        await Supabase.instance.client.from('promo_shelf_items').delete().eq('id', itemId);
        await _loadItems();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('کتاب حذف شد'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطا: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    setState(() {
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });

    // Update sort_order for all items
    try {
      for (int i = 0; i < _items.length; i++) {
        await Supabase.instance.client
            .from('promo_shelf_items')
            .update({'sort_order': i})
            .eq('id', _items[i]['id'] as Object);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در ذخیره ترتیب: $e'), backgroundColor: AppColors.error),
        );
      }
      await _loadItems(); // Reload to get correct order
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text('کتاب‌های "${widget.shelfTitle}"'),
          centerTitle: true,
        ),
        body: Column(
          children: [
            // Search/Add section
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('افزودن کتاب جدید', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'جستجوی کتاب...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchResults = []);
                              },
                            )
                          : null,
                    ),
                    onChanged: _searchAudiobooks,
                  ),
                  if (_isSearching)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    ),
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.surfaceLight),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final book = _searchResults[index];
                          return ListTile(
                            leading: book['cover_url'] != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(book['cover_url'] as String, width: 40, height: 60, fit: BoxFit.cover), // 2:3 ratio
                                  )
                                : Container(
                                    width: 40,
                                    height: 60, // 2:3 ratio
                                    color: AppColors.surfaceLight,
                                    child: const Icon(Icons.book, color: AppColors.textTertiary),
                                  ),
                            title: Text(
                              (book['title_fa'] as String?) ?? '',
                              style: const TextStyle(color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: _isAdding
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                                : IconButton(
                                    icon: const Icon(Icons.add_circle, color: AppColors.success),
                                    onPressed: () => _addBook(book),
                                  ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Items list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.library_books_outlined, size: 64, color: AppColors.textTertiary.withValues(alpha: 0.5)),
                              const SizedBox(height: 16),
                              const Text('هنوز کتابی به این قفسه اضافه نشده', style: TextStyle(color: AppColors.textSecondary)),
                              const SizedBox(height: 8),
                              const Text('از بخش بالا کتاب جستجو و اضافه کنید', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                            ],
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Text(
                                    'کتاب‌های قفسه (${_items.length})',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.drag_indicator, size: 16, color: AppColors.textTertiary),
                                  const SizedBox(width: 4),
                                  const Text('بکشید برای تغییر ترتیب', style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ReorderableListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _items.length,
                                onReorder: _reorder,
                                itemBuilder: (context, index) {
                                  final item = _items[index];
                                  final book = item['audiobooks'] as Map<String, dynamic>?;
                                  return Card(
                                    key: ValueKey(item['id']),
                                    color: AppColors.surface,
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ReorderableDragStartListener(
                                            index: index,
                                            child: const Icon(Icons.drag_handle, color: AppColors.textTertiary),
                                          ),
                                          const SizedBox(width: 8),
                                          book?['cover_url'] != null
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(4),
                                                  child: Image.network(book!['cover_url'] as String, width: 40, height: 60, fit: BoxFit.cover), // 2:3 ratio
                                                )
                                              : Container(
                                                  width: 40,
                                                  height: 60, // 2:3 ratio
                                                  color: AppColors.surfaceLight,
                                                  child: const Icon(Icons.book, color: AppColors.textTertiary),
                                                ),
                                        ],
                                      ),
                                      title: Text(
                                        (book?['title_fa'] as String?) ?? 'کتاب ناشناخته',
                                        style: const TextStyle(color: AppColors.textPrimary),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        'ترتیب: ${index + 1}',
                                        style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.remove_circle, color: AppColors.error),
                                        onPressed: () => _removeBook(item['id'] as int),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
