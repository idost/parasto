import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/widgets/admin/admin_screen_header.dart';
import 'package:myna/widgets/admin/status_badge.dart';
import 'package:myna/widgets/ebook_cover_image.dart';
import 'package:myna/widgets/content_type_badge.dart';
import 'package:myna/screens/admin/admin_upload_audiobook_screen.dart';
import 'package:myna/screens/admin/admin_edit_audiobook_screen.dart';
import 'package:myna/utils/farsi_utils.dart';

/// Provider for all admin ebooks (no pagination - admins need to see everything)
final adminEbooksProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, status) async {
  var query = Supabase.instance.client
      .from('ebooks')
      .select('*, categories(name_fa)');

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

class AdminEbooksScreen extends ConsumerStatefulWidget {
  /// When true, hides AdminScreenHeader (used inside hub tabs)
  final bool embedded;

  const AdminEbooksScreen({super.key, this.embedded = false});

  @override
  ConsumerState<AdminEbooksScreen> createState() => _AdminEbooksScreenState();
}

class _AdminEbooksScreenState extends ConsumerState<AdminEbooksScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.embedded;
  late TabController _tabController;
  String _searchQuery = '';

  // Bulk selection state
  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshAll() {
    ref.invalidate(adminEbooksProvider('pending'));
    ref.invalidate(adminEbooksProvider('approved'));
    ref.invalidate(adminEbooksProvider('rejected'));
    ref.invalidate(adminEbooksProvider('featured'));
    ref.invalidate(adminEbooksProvider('all'));
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
          content: Text('آیا ${_selectedIds.length} ایبوک انتخاب شده تأیید شوند؟'),
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
      await Supabase.instance.client.from('ebooks').update({
        'status': 'approved',
        'published_at': DateTime.now().toIso8601String(),
      }).inFilter('id', _selectedIds.toList());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_selectedIds.length} ایبوک تأیید شد'), backgroundColor: AppColors.success),
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
              Text('${_selectedIds.length} ایبوک انتخاب شده رد شوند؟'),
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
      await Supabase.instance.client.from('ebooks').update({
        'status': 'rejected',
        'rejection_reason': reasonController.text.isNotEmpty ? reasonController.text : null,
      }).inFilter('id', _selectedIds.toList());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_selectedIds.length} ایبوک رد شد'), backgroundColor: AppColors.warning),
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

    return Column(
      children: [
        // Header (hidden when embedded in hub)
        if (!widget.embedded)
          AdminScreenHeader(
            title: 'مدیریت ایبوک‌ها',
            icon: Icons.auto_stories_rounded,
            actions: [
            // Selection mode toggle
            if (_isSelectionMode) ...[
              Text('${_selectedIds.length} انتخاب شده', style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(Icons.check_circle, size: 18),
                label: const Text('تأیید'),
                style: TextButton.styleFrom(foregroundColor: AppColors.success),
                onPressed: _selectedIds.isNotEmpty ? _batchApprove : null,
              ),
              TextButton.icon(
                icon: const Icon(Icons.cancel, size: 18),
                label: const Text('رد'),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                onPressed: _selectedIds.isNotEmpty ? _batchReject : null,
              ),
              TextButton.icon(
                icon: const Icon(Icons.close, size: 18),
                label: const Text('لغو'),
                onPressed: _clearSelection,
              ),
            ] else ...[
              IconButton(
                icon: const Icon(Icons.checklist_rounded),
                tooltip: 'حالت انتخاب',
                onPressed: _toggleSelectionMode,
              ),
            ],
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'بروزرسانی',
              onPressed: _refreshAll,
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('افزودن ایبوک'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AdminUploadAudiobookScreen(initialContentType: 'ebook')),
                );
              },
            ),
          ],
        ),

        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'جستجوی ایبوک...',
              prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: AppRadius.medium,
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.medium,
                borderSide: const BorderSide(color: AppColors.border),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),

        // Tabs
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.medium,
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            indicator: BoxDecoration(
              color: AppColors.primary,
              borderRadius: AppRadius.small,
            ),
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: const [
              Tab(text: 'در انتظار'),
              Tab(text: 'تأیید شده'),
              Tab(text: 'رد شده'),
              Tab(text: 'ویژه'),
              Tab(text: 'همه'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildEbooksList('pending'),
              _buildEbooksList('approved'),
              _buildEbooksList('rejected'),
              _buildEbooksList('featured'),
              _buildEbooksList('all'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEbooksList(String status) {
    final ebooksAsync = ref.watch(adminEbooksProvider(status));

    return ebooksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('خطا در بارگذاری: $error', style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _refreshAll, child: const Text('تلاش مجدد')),
          ],
        ),
      ),
      data: (ebooks) {
        // Filter by search query
        final filtered = _searchQuery.isEmpty
            ? ebooks
            : ebooks.where((e) {
                final titleFa = (e['title_fa'] as String?) ?? '';
                final titleEn = (e['title_en'] as String?) ?? '';
                final authorFa = (e['author_fa'] as String?) ?? '';
                final query = _searchQuery.toLowerCase();
                return titleFa.toLowerCase().contains(query) ||
                    titleEn.toLowerCase().contains(query) ||
                    authorFa.toLowerCase().contains(query);
              }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_stories_outlined, size: 64, color: AppColors.textTertiary),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty ? 'ایبوکی با این جستجو یافت نشد' : 'ایبوکی وجود ندارد',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
                ),
                if (_searchQuery.isEmpty) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('افزودن ایبوک'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const AdminUploadAudiobookScreen(initialContentType: 'ebook')),
                      );
                    },
                  ),
                ],
              ],
            ),
          );
        }

        // Selection mode header
        if (_isSelectionMode) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => _selectAll(filtered),
                      child: const Text('انتخاب همه'),
                    ),
                    const Spacer(),
                    Text('${filtered.length} ایبوک', style: const TextStyle(color: AppColors.textTertiary)),
                  ],
                ),
              ),
              Expanded(child: _buildListView(filtered)),
            ],
          );
        }

        return _buildListView(filtered);
      },
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> ebooks) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: ebooks.length,
      itemBuilder: (context, index) => _buildEbookCard(ebooks[index]),
    );
  }

  Widget _buildEbookCard(Map<String, dynamic> ebook) {
    final id = ebook['id'] as int;
    final titleFa = (ebook['title_fa'] as String?) ?? 'بدون عنوان';
    final authorFa = (ebook['author_fa'] as String?) ?? 'ناشناس';
    final coverUrl = ebook['cover_url'] as String?;
    final status = ebook['status'] as String? ?? 'draft';
    final isFeatured = ebook['is_featured'] as bool? ?? false;
    final isFree = ebook['is_free'] as bool? ?? false;
    final priceToman = ebook['price_toman'] as int? ?? 0;
    final pageCount = ebook['page_count'] as int? ?? 0;
    final readCount = ebook['read_count'] as int? ?? 0;
    final categoryName = (ebook['categories'] as Map<String, dynamic>?)?['name_fa'] as String?;
    final createdAt = ebook['created_at'] != null
        ? DateTime.parse(ebook['created_at'] as String)
        : DateTime.now();

    final isSelected = _selectedIds.contains(id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.medium,
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: AppRadius.medium,
        onTap: _isSelectionMode
            ? () => _toggleSelection(id)
            : () => _showEbookDetails(ebook),
        onLongPress: () {
          if (!_isSelectionMode) {
            _toggleSelectionMode();
            _toggleSelection(id);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Selection checkbox
              if (_isSelectionMode) ...[
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleSelection(id),
                  fillColor: const WidgetStatePropertyAll(AppColors.primary),
                ),
                const SizedBox(width: 8),
              ],

              // Cover image with type badge
              Stack(
                children: [
                  EbookCoverImage(
                    coverUrl: coverUrl,
                    coverStoragePath: ebook['cover_storage_path'] as String?,
                    width: 60,
                    height: 90,
                    borderRadius: AppRadius.small,
                  ),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: ContentTypeBadge.ebook(),
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row with badges
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            titleFa,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isFeatured)
                          Container(
                            margin: const EdgeInsetsDirectional.only(end: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.2),
                              borderRadius: AppRadius.small,
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star, size: 14, color: AppColors.warning),
                                SizedBox(width: 4),
                                Text('ویژه', style: TextStyle(fontSize: 12, color: AppColors.warning)),
                              ],
                            ),
                          ),
                        _buildStatusBadge(status),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Author & Category
                    Text(
                      '$authorFa${categoryName != null ? ' • $categoryName' : ''}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Stats row
                    Row(
                      children: [
                        _buildStatChip(Icons.menu_book_outlined, '$pageCount صفحه'),
                        const SizedBox(width: 12),
                        _buildStatChip(Icons.visibility_outlined, '$readCount مطالعه'),
                        const SizedBox(width: 12),
                        _buildStatChip(
                          isFree ? Icons.card_giftcard : Icons.monetization_on_outlined,
                          isFree ? 'رایگان' : '$priceToman تومان',
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Date
                    Text(
                      'ایجاد: ${_formatDate(createdAt)}',
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    ),
                  ],
                ),
              ),

              // Actions
              if (!_isSelectionMode)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                  onSelected: (value) => _handleAction(value, ebook),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'view', child: Text('مشاهده')),
                    const PopupMenuItem(value: 'edit', child: Text('ویرایش')),
                    const PopupMenuDivider(),
                    if (status != 'approved')
                      const PopupMenuItem(value: 'approve', child: Text('تأیید')),
                    if (status != 'rejected')
                      const PopupMenuItem(value: 'reject', child: Text('رد')),
                    PopupMenuItem(
                      value: 'feature',
                      child: Text(isFeatured ? 'حذف از ویژه' : 'ویژه کردن'),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('حذف', style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    String label;
    Color color;

    switch (status) {
      case 'approved':
        label = 'تأیید شده';
        color = AppColors.success;
        break;
      case 'rejected':
        label = 'رد شده';
        color = AppColors.error;
        break;
      case 'submitted':
        label = 'ارسال شده';
        color = AppColors.info;
        break;
      case 'under_review':
        label = 'در بررسی';
        color = AppColors.warning;
        break;
      case 'draft':
      default:
        label = 'پیش‌نویس';
        color = AppColors.textTertiary;
        break;
    }

    return StatusBadge(label: label, color: color);
  }

  String _formatDate(DateTime date) {
    return '${FarsiUtils.toFarsiDigits(date.year)}/${FarsiUtils.toFarsiDigits(date.month.toString().padLeft(2, '0'))}/${FarsiUtils.toFarsiDigits(date.day.toString().padLeft(2, '0'))}';
  }

  /// Looks up the corresponding audiobook row for an ebook (bridge until Phase 5
  /// migrates ebook reads to the audiobooks table).
  Future<void> _navigateToEditEbook(Map<String, dynamic> ebook) async {
    final titleFa = ebook['title_fa'] as String?;
    if (titleFa == null || titleFa.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('عنوان ایبوک یافت نشد')),
        );
      }
      return;
    }

    try {
      final result = await Supabase.instance.client
          .from('audiobooks')
          .select()
          .eq('content_type', 'ebook')
          .eq('title_fa', titleFa)
          .maybeSingle();

      if (!mounted) return;

      if (result != null) {
        final didUpdate = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => AdminEditAudiobookScreen(
              audiobook: result,
              onUpdate: () => ref.invalidate(adminEbooksProvider),
            ),
          ),
        );
        if (didUpdate == true) {
          ref.invalidate(adminEbooksProvider);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ایبوک در جدول محتوا یافت نشد')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در بارگذاری: $e')),
        );
      }
    }
  }

  void _showEbookDetails(Map<String, dynamic> ebook) {
    _navigateToEditEbook(ebook);
  }

  Future<void> _handleAction(String action, Map<String, dynamic> ebook) async {
    final id = ebook['id'] as int;

    switch (action) {
      case 'view':
      case 'edit':
        await _navigateToEditEbook(ebook);
        break;

      case 'approve':
        await _updateStatus(id, 'approved');
        break;

      case 'reject':
        final reason = await _showRejectDialog();
        if (reason != null) {
          await _updateStatus(id, 'rejected', rejectionReason: reason);
        }
        break;

      case 'feature':
        final isFeatured = ebook['is_featured'] as bool? ?? false;
        await _toggleFeatured(id, !isFeatured);
        break;

      case 'delete':
        await _deleteEbook(id);
        break;
    }
  }

  Future<void> _updateStatus(int id, String status, {String? rejectionReason}) async {
    try {
      final update = <String, dynamic>{
        'status': status,
      };
      if (status == 'approved') {
        update['published_at'] = DateTime.now().toIso8601String();
      }
      if (rejectionReason != null) {
        update['rejection_reason'] = rejectionReason;
      }

      await Supabase.instance.client.from('ebooks').update(update).eq('id', id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'approved' ? 'ایبوک تأیید شد' : 'ایبوک رد شد'),
            backgroundColor: status == 'approved' ? AppColors.success : AppColors.warning,
          ),
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

  Future<String?> _showRejectDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('دلیل رد', style: TextStyle(color: AppColors.textPrimary)),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'دلیل رد را بنویسید...',
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(borderRadius: AppRadius.small),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('رد'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFeatured(int id, bool featured) async {
    try {
      await Supabase.instance.client.from('ebooks').update({'is_featured': featured}).eq('id', id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(featured ? 'ایبوک ویژه شد' : 'از ویژه‌ها حذف شد'),
            backgroundColor: AppColors.success,
          ),
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

  /// Delete an ebook with proper cleanup
  /// First fetches the ebook to get storage paths, then deletes storage files,
  /// then deletes the database record. All related records (entitlements,
  /// progress, bookmarks, reviews) are automatically deleted via CASCADE.
  Future<void> _deleteEbook(int id) async {
    // First, fetch the ebook to get storage paths for cleanup
    Map<String, dynamic>? ebook;
    try {
      final response = await Supabase.instance.client
          .from('ebooks')
          .select('title_fa, status, cover_storage_path, epub_storage_path')
          .eq('id', id)
          .maybeSingle();
      ebook = response;
    } catch (e) {
      debugPrint('Failed to fetch ebook for deletion: $e');
    }

    final title = ebook?['title_fa'] ?? 'ایبوک';
    final status = ebook?['status'] ?? 'unknown';
    final isPublished = status == 'approved';

    if (!mounted) return;

    // Show confirmation dialog with appropriate warning
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('حذف ایبوک', style: TextStyle(color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'آیا از حذف "$title" مطمئن هستید؟',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              if (isPublished) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'این ایبوک منتشر شده است و کاربران ممکن است آن را خریداری کرده باشند.',
                          style: TextStyle(color: AppColors.warning, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const Text(
                'این عمل قابل بازگشت نیست و تمام داده‌های مرتبط حذف می‌شود:',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 8),
              const Text(
                '• فایل ایبوک و تصویر جلد\n• سوابق خرید کاربران\n• پیشرفت مطالعه و نشانک‌ها\n• نظرات و امتیازات',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('حذف کامل'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('در حال حذف...'),
            ],
          ),
          duration: Duration(seconds: 30),
          backgroundColor: AppColors.surface,
        ),
      );
    }

    try {
      // Step 1: Delete storage files (cover and epub)
      final coverPath = ebook?['cover_storage_path'] as String?;
      final epubPath = ebook?['epub_storage_path'] as String?;

      if (coverPath != null && coverPath.isNotEmpty) {
        try {
          await Supabase.instance.client.storage
              .from('ebook-files')
              .remove([coverPath]);
          debugPrint('Deleted cover file: $coverPath');
        } catch (e) {
          debugPrint('Failed to delete cover file: $e');
          // Continue even if storage delete fails
        }
      }

      if (epubPath != null && epubPath.isNotEmpty) {
        try {
          await Supabase.instance.client.storage
              .from('ebook-files')
              .remove([epubPath]);
          debugPrint('Deleted epub file: $epubPath');
        } catch (e) {
          debugPrint('Failed to delete epub file: $e');
          // Continue even if storage delete fails
        }
      }

      // Step 2: Delete the database record
      // CASCADE will automatically delete: entitlements, reading_progress, bookmarks, reviews
      await Supabase.instance.client.from('ebooks').delete().eq('id', id);

      if (mounted) {
        // Hide loading snackbar and show success
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ایبوک "$title" حذف شد'),
            backgroundColor: AppColors.success,
          ),
        );
        _refreshAll();
      }
    } on PostgrestException catch (e) {
      debugPrint('PostgrestException during ebook deletion: ${e.code} - ${e.message}');

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        // Provide user-friendly error messages in Farsi
        String errorMessage;
        if (e.code == '42501' || e.message.contains('permission denied')) {
          errorMessage = 'شما دسترسی حذف این ایبوک را ندارید. لطفاً نقش ادمین خود را بررسی کنید.';
        } else if (e.code == '23503' || e.message.contains('foreign key')) {
          errorMessage = 'امکان حذف وجود ندارد. داده‌های مرتبط هنوز موجود هستند.';
        } else {
          errorMessage = 'خطای پایگاه داده: ${e.message}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      debugPrint('Unexpected error during ebook deletion: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطای غیرمنتظره: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}
