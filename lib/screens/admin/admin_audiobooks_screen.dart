import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/screens/admin/admin_dashboard_screen.dart';
import 'package:myna/screens/admin/admin_audiobook_detail_screen.dart';
import 'package:myna/screens/admin/admin_upload_audiobook_screen.dart';
import 'package:myna/widgets/admin/admin_screen_header.dart';
import 'package:myna/widgets/admin/admin_sidebar.dart';
import 'package:myna/widgets/admin/status_badge.dart';
import 'package:myna/widgets/admin/advanced_filter_panel.dart';

/// Provider for all admin audiobooks (no pagination - admins need to see everything)
/// FIXED: Previous version only fetched 50 items. Admins need to see ALL content.
final adminAudiobooksProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, status) async {
  var query = Supabase.instance.client
      .from('audiobooks')
      .select('*, categories(name_fa), book_metadata(narrator_name), music_metadata(artist_name)');

  if (status == 'pending') {
    query = query.inFilter('status', ['submitted', 'under_review']);
  } else if (status == 'featured') {
    query = query.eq('is_featured', true);
  } else if (status != 'all') {
    query = query.eq('status', status);
  }

  final response = await query.order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(response);
});

class AdminAudiobooksScreen extends ConsumerStatefulWidget {
  /// When true, hides AdminScreenHeader and content type chips (used inside hub tabs)
  final bool embedded;
  /// Content type filter passed from hub. Overrides route-based detection.
  /// Values: 'books', 'music', 'podcasts', 'articles', or null (all)
  final String? contentTypeFilter;

  const AdminAudiobooksScreen({super.key, this.embedded = false, this.contentTypeFilter});

  @override
  ConsumerState<AdminAudiobooksScreen> createState() => _AdminAudiobooksScreenState();
}

class _AdminAudiobooksScreenState extends ConsumerState<AdminAudiobooksScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String? _contentTypeFilter; // null=all, 'books', 'music', 'podcasts', 'articles'

  @override
  bool get wantKeepAlive => widget.embedded;

  // Bulk selection state
  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};

  // Advanced filters
  bool _showFilters = false;
  ContentFilters _filters = const ContentFilters();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    // Use constructor param if provided (hub mode), otherwise route detection in build()
    if (widget.contentTypeFilter != null) {
      _contentTypeFilter = widget.contentTypeFilter;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshAll() {
    ref.invalidate(adminAudiobooksProvider('pending'));
    ref.invalidate(adminAudiobooksProvider('approved'));
    ref.invalidate(adminAudiobooksProvider('rejected'));
    ref.invalidate(adminAudiobooksProvider('featured'));
    ref.invalidate(adminAudiobooksProvider('all'));
    ref.invalidate(adminStatsProvider);
    _clearSelection();
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedIds.clear();
      }
    });
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<Map<String, dynamic>> items) {
    setState(() {
      _selectedIds.addAll(items.map((e) => e['id'] as int));
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _batchApprove() async {
    if (_selectedIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('تأیید دسته‌جمعی', style: TextStyle(color: AppColors.textPrimary)),
          content: Text('آیا ${_selectedIds.length} مورد انتخاب شده تأیید شوند؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              child: const Text('تأیید همه'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await Supabase.instance.client.from('audiobooks').update({
        'status': 'approved',
        'reviewed_at': DateTime.now().toIso8601String(),
        'reviewed_by': Supabase.instance.client.auth.currentUser?.id,
      }).inFilter('id', _selectedIds.toList());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_selectedIds.length} مورد تأیید شد'), backgroundColor: AppColors.success),
        );
        _refreshAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _batchReject() async {
    if (_selectedIds.isEmpty) return;

    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('رد دسته‌جمعی', style: TextStyle(color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_selectedIds.length} مورد انتخاب شده رد شوند؟'),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'دلیل رد',
                  hintText: 'دلیل رد را بنویسید...',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: AppRadius.small),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('رد همه'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await Supabase.instance.client.from('audiobooks').update({
        'status': 'rejected',
        'rejection_reason': reasonController.text.trim(),
        'reviewed_at': DateTime.now().toIso8601String(),
        'reviewed_by': Supabase.instance.client.auth.currentUser?.id,
      }).inFilter('id', _selectedIds.toList());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_selectedIds.length} مورد رد شد'), backgroundColor: AppColors.warning),
        );
        _refreshAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _batchToggleFeatured(bool setFeatured) async {
    if (_selectedIds.isEmpty) return;

    final action = setFeatured ? 'ویژه کردن' : 'حذف از ویژه';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(action, style: const TextStyle(color: AppColors.textPrimary)),
          content: Text('${_selectedIds.length} مورد انتخاب شده $action شوند؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: Text(action),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await Supabase.instance.client.from('audiobooks').update({
        'is_featured': setFeatured,
      }).inFilter('id', _selectedIds.toList());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_selectedIds.length} مورد $action شد'), backgroundColor: AppColors.success),
        );
        _refreshAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _batchDelete() async {
    if (_selectedIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('حذف دسته‌جمعی', style: TextStyle(color: AppColors.error)),
          content: Text(
            'آیا ${_selectedIds.length} مورد انتخاب شده حذف شوند؟\n\nاین عمل قابل بازگشت نیست!',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('حذف همه'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await Supabase.instance.client.from('audiobooks').delete().inFilter('id', _selectedIds.toList());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_selectedIds.length} مورد حذف شد'), backgroundColor: AppColors.warning),
        );
        _refreshAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // In embedded mode (hub tabs), use constructor param; skip route-based detection
    final bool isEmbedded = widget.embedded;
    final activeRoute = isEmbedded ? '' : ref.watch(adminActiveRouteProvider);
    final isMusic = !isEmbedded && activeRoute == '/admin/content/music';
    final isPodcast = !isEmbedded && activeRoute == '/admin/content/podcasts';
    final isApprovalQueue = !isEmbedded && activeRoute == '/admin/content';

    // Set content type filter based on route (only when NOT embedded)
    if (!isEmbedded) {
      if (isMusic && _contentTypeFilter != 'music') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() => _contentTypeFilter = 'music');
        });
      } else if (isPodcast && _contentTypeFilter != 'podcasts') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() => _contentTypeFilter = 'podcasts');
        });
      } else if (!isMusic && !isPodcast && activeRoute == '/admin/content/books' && _contentTypeFilter != 'books') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() => _contentTypeFilter = 'books');
        });
      } else if (activeRoute == '/admin/content' && _contentTypeFilter != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() => _contentTypeFilter = null);
        });
      }

      // For approval queue, default to pending tab
      if (isApprovalQueue && _tabController.index != 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _tabController.animateTo(0);
        });
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header (hidden when embedded in hub)
          if (!isEmbedded)
            AdminScreenHeader(
              title: isApprovalQueue
                  ? 'صف تأیید محتوا'
                  : (isPodcast ? 'مدیریت پادکست‌ها' : (isMusic ? 'مدیریت موسیقی' : 'مدیریت کتاب‌ها')),
              icon: isApprovalQueue
                  ? Icons.pending_actions_rounded
                  : (isPodcast ? Icons.podcasts_rounded : (isMusic ? Icons.library_music_rounded : Icons.menu_book_rounded)),
              actions: [
                // Selection mode toggle
                IconButton(
                  onPressed: _toggleSelectionMode,
                  icon: Icon(
                    _isSelectionMode ? Icons.close : Icons.checklist_rounded,
                    color: _isSelectionMode ? AppColors.error : AppColors.textSecondary,
                  ),
                  tooltip: _isSelectionMode ? 'لغو انتخاب' : 'انتخاب چندتایی',
                ),
              ],
            ),

          // Bulk action bar (when items selected)
          if (_isSelectionMode && _selectedIds.isNotEmpty)
            _buildBulkActionBar(),

          // Tabs
          Container(
            color: AppColors.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              isScrollable: true,
              tabs: const [
                Tab(text: 'صف بررسی'),
                Tab(text: 'منتشر شده'),
                Tab(text: 'رد شده'),
                Tab(text: 'ویژه'),
                Tab(text: 'همه'),
              ],
            ),
          ),

          // Body
          Expanded(
            child: Column(
              children: [
                // Content type filter (hidden when embedded — hub tabs handle type selection)
                if (!isEmbedded && activeRoute != '/admin/content/books' && activeRoute != '/admin/content/music' && activeRoute != '/admin/content/podcasts')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Row(
                      children: [
                        _buildContentTypeChip(
                          label: 'همه',
                          isSelected: _contentTypeFilter == null,
                          onTap: () => setState(() => _contentTypeFilter = null),
                        ),
                        const SizedBox(width: 8),
                        _buildContentTypeChip(
                          label: '📚 کتاب‌ها',
                          isSelected: _contentTypeFilter == 'books',
                          onTap: () => setState(() => _contentTypeFilter = 'books'),
                        ),
                        const SizedBox(width: 8),
                        _buildContentTypeChip(
                          label: '🎵 موسیقی',
                          isSelected: _contentTypeFilter == 'music',
                          onTap: () => setState(() => _contentTypeFilter = 'music'),
                        ),
                        const SizedBox(width: 8),
                        _buildContentTypeChip(
                          label: '🎙️ پادکست',
                          isSelected: _contentTypeFilter == 'podcasts',
                          onTap: () => setState(() => _contentTypeFilter = 'podcasts'),
                        ),
                      ],
                    ),
                  ),

                // Search bar and filter button
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: _contentTypeFilter == 'podcasts' ? 'جستجوی پادکست...' : (_contentTypeFilter == 'music' ? 'جستجوی موسیقی...' : 'جستجوی کتاب...'),
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(borderRadius: AppRadius.medium, borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilterButton(
                        filters: _filters,
                        onTap: () => setState(() => _showFilters = !_showFilters),
                      ),
                    ],
                  ),
                ),

                // Advanced filter panel
                if (_showFilters)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: AdvancedFilterPanel(
                      filters: _filters,
                      onFiltersChanged: (newFilters) => setState(() => _filters = newFilters),
                      onClose: () => setState(() => _showFilters = false),
                    ),
                  ),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _AudiobooksList(
                        status: 'pending',
                        searchQuery: _searchQuery,
                        contentTypeFilter: _contentTypeFilter,
                        filters: _filters,
                        onRefresh: _refreshAll,
                        isSelectionMode: _isSelectionMode,
                        selectedIds: _selectedIds,
                        onToggleSelection: _toggleSelection,
                        onSelectAll: _selectAll,
                      ),
                      _AudiobooksList(
                        status: 'approved',
                        searchQuery: _searchQuery,
                        contentTypeFilter: _contentTypeFilter,
                        filters: _filters,
                        onRefresh: _refreshAll,
                        isSelectionMode: _isSelectionMode,
                        selectedIds: _selectedIds,
                        onToggleSelection: _toggleSelection,
                        onSelectAll: _selectAll,
                      ),
                      _AudiobooksList(
                        status: 'rejected',
                        searchQuery: _searchQuery,
                        contentTypeFilter: _contentTypeFilter,
                        filters: _filters,
                        onRefresh: _refreshAll,
                        isSelectionMode: _isSelectionMode,
                        selectedIds: _selectedIds,
                        onToggleSelection: _toggleSelection,
                        onSelectAll: _selectAll,
                      ),
                      _AudiobooksList(
                        status: 'featured',
                        searchQuery: _searchQuery,
                        contentTypeFilter: _contentTypeFilter,
                        filters: _filters,
                        onRefresh: _refreshAll,
                        isSelectionMode: _isSelectionMode,
                        selectedIds: _selectedIds,
                        onToggleSelection: _toggleSelection,
                        onSelectAll: _selectAll,
                      ),
                      _AudiobooksList(
                        status: 'all',
                        searchQuery: _searchQuery,
                        contentTypeFilter: _contentTypeFilter,
                        filters: _filters,
                        onRefresh: _refreshAll,
                        isSelectionMode: _isSelectionMode,
                        selectedIds: _selectedIds,
                        onToggleSelection: _toggleSelection,
                        onSelectAll: _selectAll,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute<bool>(builder: (_) => const AdminUploadAudiobookScreen()),
                );
                if (result == true) {
                  _refreshAll();
                }
              },
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add),
              label: const Text('آپلود محتوا'),
            ),
    );
  }

  Widget _buildBulkActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: AppRadius.large,
            ),
            child: Text(
              '${_selectedIds.length} انتخاب شده',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _BulkActionButton(
                    icon: Icons.check_circle,
                    label: 'تأیید',
                    color: AppColors.success,
                    onTap: _batchApprove,
                  ),
                  const SizedBox(width: 8),
                  _BulkActionButton(
                    icon: Icons.cancel,
                    label: 'رد',
                    color: AppColors.error,
                    onTap: _batchReject,
                  ),
                  const SizedBox(width: 8),
                  _BulkActionButton(
                    icon: Icons.workspace_premium_rounded,
                    label: 'ویژه',
                    color: Colors.amber,
                    onTap: () => _batchToggleFeatured(true),
                  ),
                  const SizedBox(width: 8),
                  _BulkActionButton(
                    icon: Icons.workspace_premium_outlined,
                    label: 'حذف ویژه',
                    color: AppColors.textSecondary,
                    onTap: () => _batchToggleFeatured(false),
                  ),
                  const SizedBox(width: 8),
                  _BulkActionButton(
                    icon: Icons.delete,
                    label: 'حذف',
                    color: AppColors.error,
                    onTap: _batchDelete,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: _clearSelection,
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
            tooltip: 'لغو انتخاب',
          ),
        ],
      ),
    );
  }

  Widget _buildContentTypeChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: AppRadius.extraLarge,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.chip.copyWith(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _BulkActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _BulkActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.15),
      borderRadius: AppRadius.small,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.small,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudiobooksList extends ConsumerWidget {
  final String status;
  final String searchQuery;
  final String? contentTypeFilter; // null=all, 'books', 'music', 'podcasts', 'articles'
  final ContentFilters filters;
  final VoidCallback onRefresh;
  final bool isSelectionMode;
  final Set<int> selectedIds;
  final void Function(int) onToggleSelection;
  final void Function(List<Map<String, dynamic>>) onSelectAll;

  const _AudiobooksList({
    required this.status,
    required this.searchQuery,
    required this.contentTypeFilter,
    required this.filters,
    required this.onRefresh,
    required this.isSelectionMode,
    required this.selectedIds,
    required this.onToggleSelection,
    required this.onSelectAll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audiobooksAsync = ref.watch(adminAudiobooksProvider(status));

    return audiobooksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('خطا: $e', style: const TextStyle(color: AppColors.error))),
      data: (audiobooks) {
        var filtered = audiobooks;

        // Apply content type filter (uses content_type column)
        if (contentTypeFilter != null) {
          switch (contentTypeFilter) {
            case 'books':
              filtered = filtered.where((book) => book['content_type'] == 'audiobook').toList();
            case 'music':
              filtered = filtered.where((book) => book['content_type'] == 'music').toList();
            case 'podcasts':
              filtered = filtered.where((book) => book['content_type'] == 'podcast').toList();
            case 'articles':
              filtered = filtered.where((book) => book['content_type'] == 'article').toList();
          }
        }

        // Apply category filter
        if (filters.categoryId != null) {
          filtered = filtered.where((book) => book['category_id'] == filters.categoryId).toList();
        }

        // Apply price filter
        if (filters.priceFilter != null) {
          if (filters.priceFilter == 'free') {
            filtered = filtered.where((book) => book['is_free'] == true).toList();
          } else if (filters.priceFilter == 'paid') {
            filtered = filtered.where((book) => book['is_free'] != true).toList();
          }
        }

        // Apply search filter
        if (searchQuery.isNotEmpty) {
          filtered = filtered.where((book) {
            final titleFa = (book['title_fa'] ?? '').toString().toLowerCase();
            final titleEn = (book['title_en'] ?? '').toString().toLowerCase();
            final isMusic = book['content_type'] == 'music';
            final String narratorName;
            if (isMusic) {
              final musicMeta = book['music_metadata'] as Map<String, dynamic>?;
              narratorName = (musicMeta?['artist_name'] ?? book['author_fa'] ?? '').toString().toLowerCase();
            } else {
              final bookMeta = book['book_metadata'] as Map<String, dynamic>?;
              narratorName = (bookMeta?['narrator_name'] ?? '').toString().toLowerCase();
            }
            return titleFa.contains(searchQuery) || titleEn.contains(searchQuery) || narratorName.contains(searchQuery);
          }).toList();
        }

        // Apply sorting
        switch (filters.sortBy) {
          case 'newest':
            filtered.sort((a, b) {
              final aDate = DateTime.tryParse(a['created_at'] as String? ?? '') ?? DateTime(1970);
              final bDate = DateTime.tryParse(b['created_at'] as String? ?? '') ?? DateTime(1970);
              return bDate.compareTo(aDate);
            });
            break;
          case 'oldest':
            filtered.sort((a, b) {
              final aDate = DateTime.tryParse(a['created_at'] as String? ?? '') ?? DateTime(1970);
              final bDate = DateTime.tryParse(b['created_at'] as String? ?? '') ?? DateTime(1970);
              return aDate.compareTo(bDate);
            });
            break;
          case 'title':
            filtered.sort((a, b) {
              final aTitle = (a['title_fa'] as String?) ?? '';
              final bTitle = (b['title_fa'] as String?) ?? '';
              return aTitle.compareTo(bTitle);
            });
            break;
          case 'popular':
            filtered.sort((a, b) {
              final aPlays = (a['play_count'] as int?) ?? 0;
              final bPlays = (b['play_count'] as int?) ?? 0;
              return bPlays.compareTo(aPlays);
            });
            break;
        }

        if (filtered.isEmpty) {
          final isMusic = contentTypeFilter == 'music';
          final isPodcast = contentTypeFilter == 'podcasts';
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isMusic ? Icons.music_note_outlined : (isPodcast ? Icons.podcasts_outlined : Icons.library_books_outlined),
                  size: 64,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  searchQuery.isEmpty
                      ? (isMusic ? 'موسیقی یافت نشد' : 'کتابی یافت نشد')
                      : 'نتیجه‌ای یافت نشد',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Select all row (when in selection mode)
            if (isSelectionMode)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => onSelectAll(filtered),
                      icon: const Icon(Icons.select_all, size: 18),
                      label: Text('انتخاب همه (${filtered.length})'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                    ),
                    const Spacer(),
                    Text(
                      '${selectedIds.length} از ${filtered.length}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => onRefresh(),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _AudiobookCard(
                    audiobook: filtered[index],
                    onAction: onRefresh,
                    isSelectionMode: isSelectionMode,
                    isSelected: selectedIds.contains(filtered[index]['id'] as int),
                    onToggleSelection: () => onToggleSelection(filtered[index]['id'] as int),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AudiobookCard extends StatelessWidget {
  final Map<String, dynamic> audiobook;
  final VoidCallback onAction;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onToggleSelection;

  const _AudiobookCard({
    required this.audiobook,
    required this.onAction,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onToggleSelection,
  });

  @override
  Widget build(BuildContext context) {
    final category = audiobook['categories'] as Map<String, dynamic>?;
    final status = audiobook['status'] as String? ?? 'draft';
    final isFeatured = audiobook['is_featured'] == true;
    final isPending = status == 'submitted' || status == 'under_review';
    final isMusic = audiobook['content_type'] == 'music';
    final isPodcast = audiobook['content_type'] == 'podcast';

    // Get narrator/artist/host from metadata
    String creatorDisplay;
    String creatorLabel;
    if (isPodcast) {
      // For podcasts, author_fa contains host name
      creatorDisplay = (audiobook['author_fa'] as String?) ?? 'نامشخص';
      creatorLabel = 'میزبان';
    } else if (isMusic) {
      final musicMeta = audiobook['music_metadata'] as Map<String, dynamic>?;
      creatorDisplay = (musicMeta?['artist_name'] as String?) ??
          (audiobook['author_fa'] as String?) ??
          'نامشخص';
      creatorLabel = 'هنرمند';
    } else {
      final bookMeta = audiobook['book_metadata'] as Map<String, dynamic>?;
      creatorDisplay = (bookMeta?['narrator_name'] as String?) ?? 'نامشخص';
      creatorLabel = 'گوینده';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
        borderRadius: AppRadius.medium,
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.borderSubtle,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: isSelectionMode
            ? onToggleSelection
            : () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => AdminAudiobookDetailScreen(audiobook: audiobook, onUpdate: onAction),
                  ),
                ),
        onLongPress: isSelectionMode ? null : onToggleSelection,
        borderRadius: AppRadius.medium,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selection checkbox
                  if (isSelectionMode)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 8),
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (_) => onToggleSelection(),
                        activeColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xs)),
                      ),
                    ),

                  // Cover with content type badge
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: AppRadius.small,
                        child: audiobook['cover_url'] != null
                            ? Image.network(
                                audiobook['cover_url'] as String,
                                width: 60,
                                height: 90, // 2:3 aspect ratio
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildPlaceholderCover(isMusic, isPodcast),
                              )
                            : _buildPlaceholderCover(isMusic, isPodcast),
                      ),
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isPodcast ? Colors.teal.withValues(alpha: 0.9) : (isMusic ? Colors.purple.withValues(alpha: 0.9) : AppColors.primary.withValues(alpha: 0.9)),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                          child: Icon(
                            isPodcast ? Icons.podcasts : (isMusic ? Icons.music_note : Icons.headphones),
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                (audiobook['title_fa'] as String?) ?? (audiobook['title'] as String?) ?? 'بدون عنوان',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isFeatured) const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 18),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$creatorLabel: $creatorDisplay',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        Text(
                          'دسته: ${category?['name_fa'] ?? 'نامشخص'}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        Row(
                          children: [
                            Text(
                              audiobook['is_free'] == true ? 'رایگان' : '${(audiobook['price_toman'] as num?) ?? 0} تومان',
                              style: const TextStyle(color: AppColors.primary, fontSize: 12),
                            ),
                            const Spacer(),
                            _buildStatusBadge(status),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Inline actions for pending items (only in non-selection mode)
              if (isPending && !isSelectionMode) ...[
                const SizedBox(height: 12),
                if (status == 'submitted') ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _markUnderReview(context),
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('شروع بررسی'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _approveAudiobook(context),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('تأیید'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showRejectDialog(context),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('رد'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // Rejection reason
              if (status == 'rejected' && audiobook['rejection_reason'] != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: AppRadius.small,
                  ),
                  child: Text(
                    'دلیل رد: ${audiobook['rejection_reason'] as String}',
                    style: const TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderCover(bool isMusic, bool isPodcast) {
    return Container(
      width: 60,
      height: 90, // 2:3 aspect ratio
      color: AppColors.surfaceLight,
      child: Icon(
        isPodcast ? Icons.podcasts : (isMusic ? Icons.music_note : Icons.book),
        color: AppColors.textTertiary,
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case 'approved':
        color = AppColors.success;
        label = 'منتشر شده';
        icon = Icons.check_circle;
        break;
      case 'rejected':
        color = AppColors.error;
        label = 'رد شده';
        icon = Icons.cancel;
        break;
      case 'submitted':
        color = AppColors.warning;
        label = 'ارسال شده';
        icon = Icons.schedule;
        break;
      case 'under_review':
        color = Colors.blue;
        label = 'در حال بررسی';
        icon = Icons.visibility;
        break;
      case 'draft':
      default:
        color = AppColors.textTertiary;
        label = 'پیش‌نویس';
        icon = Icons.edit_note;
    }

    return StatusBadge(label: label, color: color, icon: icon);
  }

  Future<void> _markUnderReview(BuildContext context) async {
    FocusScope.of(context).unfocus();

    try {
      await Supabase.instance.client.from('audiobooks').update({
        'status': 'under_review',
      }).eq('id', audiobook['id'] as Object);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('وضعیت به "در حال بررسی" تغییر کرد'), backgroundColor: Colors.blue),
        );
        onAction();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _approveAudiobook(BuildContext context) async {
    FocusScope.of(context).unfocus();

    try {
      await Supabase.instance.client.from('audiobooks').update({
        'status': 'approved',
        'reviewed_at': DateTime.now().toIso8601String(),
        'reviewed_by': Supabase.instance.client.auth.currentUser?.id,
      }).eq('id', audiobook['id'] as Object);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('محتوا تأیید شد'), backgroundColor: AppColors.success),
        );
        onAction();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _showRejectDialog(BuildContext context) async {
    FocusScope.of(context).unfocus();

    final reasonController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('رد محتوا', style: TextStyle(color: AppColors.textPrimary)),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'دلیل رد',
              hintText: 'دلیل رد را بنویسید...',
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(borderRadius: AppRadius.small),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('رد محتوا'),
            ),
          ],
        ),
      ),
    );

    if (result == true && context.mounted) {
      try {
        await Supabase.instance.client.from('audiobooks').update({
          'status': 'rejected',
          'rejection_reason': reasonController.text.trim(),
          'reviewed_at': DateTime.now().toIso8601String(),
          'reviewed_by': Supabase.instance.client.auth.currentUser?.id,
        }).eq('id', audiobook['id'] as Object);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('محتوا رد شد'), backgroundColor: AppColors.warning),
          );
          onAction();
        }
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
