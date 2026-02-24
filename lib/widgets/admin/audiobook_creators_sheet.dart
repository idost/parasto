import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/services/creator_service.dart';
import 'package:myna/utils/app_logger.dart';

/// Bottom sheet for managing creators linked to an audiobook.
///
/// Shows:
/// - Currently linked creators with their roles
/// - Search to find and add new creators
/// - Ability to remove linked creators
class AudiobookCreatorsSheet extends StatefulWidget {
  final int audiobookId;
  final bool isMusic; // Affects which roles are prominently shown

  const AudiobookCreatorsSheet({
    super.key,
    required this.audiobookId,
    this.isMusic = false,
  });

  /// Show this sheet as a modal bottom sheet
  static Future<void> show(BuildContext context, {required int audiobookId, bool isMusic = false}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => AudiobookCreatorsSheet(
          audiobookId: audiobookId,
          isMusic: isMusic,
        ),
      ),
    );
  }

  @override
  State<AudiobookCreatorsSheet> createState() => _AudiobookCreatorsSheetState();
}

class _AudiobookCreatorsSheetState extends State<AudiobookCreatorsSheet> {
  final CreatorService _creatorService = CreatorService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _linkedCreators = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLinkedCreators();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLinkedCreators() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _linkedCreators = await _creatorService.getCreatorsForAudiobook(widget.audiobookId);
      setState(() => _isLoading = false);
    } catch (e, st) {
      AppLogger.e('AudiobookCreatorsSheet: Error loading linked creators', error: e, stackTrace: st);
      setState(() {
        _error = 'خطا در بارگذاری سازندگان';
        _isLoading = false;
      });
    }
  }

  Future<void> _searchCreators(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await _creatorService.searchCreators(query);
      // Filter out already linked creators
      final linkedIds = _linkedCreators.map((c) => c['id']).toSet();
      setState(() {
        _searchResults = results.where((c) => !linkedIds.contains(c['id'])).toList();
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _linkCreator(Map<String, dynamic> creator, String role) async {
    final success = await _creatorService.linkCreatorToAudiobook(
      audiobookId: widget.audiobookId,
      creatorId: creator['id'] as String,
      role: role,
    );

    if (success) {
      _searchController.clear();
      _searchResults = [];
      await _loadLinkedCreators();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${creator['display_name']} اضافه شد'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('خطا در افزودن سازنده'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _unlinkCreator(Map<String, dynamic> creator) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف سازنده'),
          content: Text('آیا از حذف "${creator['display_name']}" اطمینان دارید؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('انصراف'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    final success = await _creatorService.unlinkCreatorFromAudiobook(
      audiobookId: widget.audiobookId,
      creatorId: creator['id'] as String,
      role: creator['role'] as String,
    );

    if (success) {
      await _loadLinkedCreators();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${creator['display_name']} حذف شد'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('خطا در حذف سازنده'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showRoleSelectionDialog(Map<String, dynamic> creator) {
    // Show different roles based on content type
    final roles = widget.isMusic
        ? ['singer', 'composer', 'lyricist', 'musician', 'arranger', 'label', 'other']
        : ['author', 'translator', 'narrator', 'publisher', 'other'];

    showDialog<void>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('نقش ${creator['display_name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: roles.map((role) {
              return ListTile(
                title: Text(CreatorService.getRoleLabel(role)),
                onTap: () {
                  Navigator.pop(context);
                  _linkCreator(creator, role);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.textTertiary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  'مدیریت سازندگان',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),

          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'جستجوی سازنده برای افزودن...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
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
              onChanged: _searchCreators,
            ),
          ),

          // Search results (if searching)
          if (_searchResults.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'نتایج جستجو:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final creator = _searchResults[index];
                  return _SearchResultCard(
                    creator: creator,
                    onTap: () => _showRoleSelectionDialog(creator),
                  );
                },
              ),
            ),
            const Divider(),
          ],

          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),

          // Linked creators section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'سازندگان فعلی (${_linkedCreators.length})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Linked creators list
          Expanded(
            child: _buildLinkedCreatorsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedCreatorsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadLinkedCreators,
              child: const Text('تلاش مجدد'),
            ),
          ],
        ),
      );
    }

    if (_linkedCreators.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add, size: 64, color: AppColors.textTertiary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              'هنوز سازنده‌ای اضافه نشده',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'از جستجو بالا برای افزودن سازنده استفاده کنید',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _linkedCreators.length,
      itemBuilder: (context, index) {
        final creator = _linkedCreators[index];
        return _LinkedCreatorCard(
          creator: creator,
          onRemove: () => _unlinkCreator(creator),
        );
      },
    );
  }
}

/// Card for a search result creator
class _SearchResultCard extends StatelessWidget {
  final Map<String, dynamic> creator;
  final VoidCallback onTap;

  const _SearchResultCard({required this.creator, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final displayName = (creator['display_name'] as String?) ?? '';
    final typeLabel = CreatorService.getCreatorTypeLabel(creator['creator_type'] as String?);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        margin: const EdgeInsetsDirectional.only(start: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Text(
                displayName.isNotEmpty ? displayName[0] : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              displayName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(
              typeLabel,
              style: TextStyle(fontSize: 10, color: AppColors.textSecondary.withValues(alpha: 0.8)),
            ),
            const Icon(Icons.add_circle, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Card for a linked creator
class _LinkedCreatorCard extends StatelessWidget {
  final Map<String, dynamic> creator;
  final VoidCallback onRemove;

  const _LinkedCreatorCard({required this.creator, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final displayName = (creator['display_name'] as String?) ?? '';
    final displayNameLatin = creator['display_name_latin'] as String?;
    final role = creator['role'] as String?;
    final roleLabel = CreatorService.getRoleLabel(role);

    return Card(
      color: AppColors.background,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Text(
            displayName.isNotEmpty ? displayName[0] : '?',
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          displayName,
          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (displayNameLatin != null && displayNameLatin.isNotEmpty)
              Text(
                displayNameLatin,
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withValues(alpha: 0.8)),
                textDirection: TextDirection.ltr,
              ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                roleLabel,
                style: const TextStyle(fontSize: 10, color: AppColors.success),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.remove_circle, color: AppColors.error),
          onPressed: onRemove,
        ),
      ),
    );
  }
}
