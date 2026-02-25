import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/screens/audiobook_detail_screen.dart';
import 'package:myna/services/creator_service.dart';
import 'package:myna/utils/app_logger.dart';

/// Screen displaying a creator's profile and their works.
///
/// Shows:
/// - Creator name, type (in Farsi), optional bio and avatar
/// - List of audiobooks (کتاب‌های صوتی) where content_type = 'audiobook'
/// - List of music (آثار موسیقی) where content_type = 'music'
class CreatorProfileScreen extends StatefulWidget {
  final String creatorId;

  const CreatorProfileScreen({
    super.key,
    required this.creatorId,
  });

  @override
  State<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends State<CreatorProfileScreen> {
  final CreatorService _creatorService = CreatorService();

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _creator;
  List<Map<String, dynamic>> _books = [];
  List<Map<String, dynamic>> _music = [];

  // Filter state: 0 = all, 1 = books, 2 = music
  int _selectedFilter = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load creator profile and works in parallel
      final results = await Future.wait([
        _creatorService.getCreatorById(widget.creatorId),
        _creatorService.getWorksForCreator(widget.creatorId),
      ]);

      final creator = results[0] as Map<String, dynamic>?;
      final works = results[1] as List<Map<String, dynamic>>;

      if (creator == null) {
        setState(() {
          _error = 'سازنده یافت نشد';
          _isLoading = false;
        });
        return;
      }

      // Separate books and music
      final books = works.where((w) => (w['content_type'] as String?) != 'music').toList();
      final music = works.where((w) => (w['content_type'] as String?) == 'music').toList();

      setState(() {
        _creator = creator;
        _books = books;
        _music = music;
        _isLoading = false;
        // Set default filter based on available content
        if (books.isNotEmpty && music.isEmpty) {
          _selectedFilter = 1; // Only books
        } else if (books.isEmpty && music.isNotEmpty) {
          _selectedFilter = 2; // Only music
        } else {
          _selectedFilter = 0; // All
        }
      });
    } catch (e, st) {
      AppLogger.e('CreatorProfileScreen: Error loading data', error: e, stackTrace: st);
      setState(() {
        _error = 'خطا در بارگذاری اطلاعات';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredWorks {
    switch (_selectedFilter) {
      case 1:
        return _books;
      case 2:
        return _music;
      default:
        return [..._books, ..._music];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_creator == null) {
      return const Center(
        child: Text(
          'اطلاعاتی یافت نشد',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Collapsing App Bar with Header
          _buildSliverAppBar(),

          // Stats Row
          if (_books.isNotEmpty || _music.isNotEmpty)
            SliverToBoxAdapter(child: _buildStatsRow()),

          // Bio Section
          if (_creator!['bio'] != null && (_creator!['bio'] as String).isNotEmpty)
            SliverToBoxAdapter(child: _buildBioSection()),

          // Filter Chips (only if both types exist)
          if (_books.isNotEmpty && _music.isNotEmpty)
            SliverToBoxAdapter(child: _buildFilterChips()),

          // Section Title
          if (_filteredWorks.isNotEmpty)
            SliverToBoxAdapter(child: _buildWorksTitle()),

          // Works Grid or Empty State
          if (_filteredWorks.isEmpty)
            SliverToBoxAdapter(child: _buildEmptyState())
          else
            _buildWorksGrid(),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    final displayName = _creator!['display_name'] as String? ?? '';
    final displayNameLatin = _creator!['display_name_latin'] as String?;
    final creatorType = _creator!['creator_type'] as String?;
    final typeLabel = CreatorService.getCreatorTypeLabel(creatorType);
    final avatarUrl = _creator!['avatar_url'] as String?;

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: AppColors.background,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.8),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 18),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary.withValues(alpha: 0.15),
                AppColors.primary.withValues(alpha: 0.05),
                AppColors.background,
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Avatar
                _buildAvatar(avatarUrl, displayName),
                const SizedBox(height: 16),
                // Name
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Latin name
                if (displayNameLatin != null && displayNameLatin.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    displayNameLatin,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                ],
                const SizedBox(height: 12),
                // Type Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    typeLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String? avatarUrl, String displayName) {
    final initial = displayName.isNotEmpty ? displayName[0] : '?';

    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: avatarUrl != null && avatarUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: avatarUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => _buildAvatarPlaceholder(initial),
                errorWidget: (_, __, ___) => _buildAvatarPlaceholder(initial),
              )
            : _buildAvatarPlaceholder(initial),
      ),
    );
  }

  Widget _buildAvatarPlaceholder(String initial) {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.1),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.bold,
            color: AppColors.primary.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_books.isNotEmpty)
            _buildStatItem(
              icon: Icons.menu_book_rounded,
              count: _books.length,
              label: 'کتاب صوتی',
            ),
          if (_books.isNotEmpty && _music.isNotEmpty)
            Container(
              height: 24,
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              color: AppColors.border,
            ),
          if (_music.isNotEmpty)
            _buildStatItem(
              icon: Icons.music_note_rounded,
              count: _music.length,
              label: 'موسیقی',
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required int count,
    required String label,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildBioSection() {
    final bio = _creator!['bio'] as String;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    size: 16,
                    color: AppColors.primary.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'درباره سازنده',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              bio,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          _buildFilterChip(0, 'همه', Icons.apps_rounded),
          const SizedBox(width: 8),
          _buildFilterChip(1, 'کتاب‌ها', Icons.menu_book_rounded),
          const SizedBox(width: 8),
          _buildFilterChip(2, 'موسیقی', Icons.music_note_rounded),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int index, String label, IconData icon) {
    final isSelected = _selectedFilter == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorksTitle() {
    String title;
    IconData icon;

    switch (_selectedFilter) {
      case 1:
        title = 'کتاب‌های صوتی';
        icon = Icons.menu_book_rounded;
        break;
      case 2:
        title = 'آثار موسیقی';
        icon = Icons.music_note_rounded;
        break;
      default:
        title = 'آثار';
        icon = Icons.library_music_rounded;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.textTertiary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_filteredWorks.length}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorksGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.58,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _WorkCard(work: _filteredWorks[index]),
          childCount: _filteredWorks.length,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String title;
    String subtitle;
    IconData icon;

    if (_books.isEmpty && _music.isEmpty) {
      title = 'اثری برای این سازنده ثبت نشده است';
      subtitle = 'هنوز محتوایی از این سازنده در پرستو منتشر نشده';
      icon = Icons.library_music_outlined;
    } else if (_selectedFilter == 1) {
      title = 'کتاب صوتی موجود نیست';
      subtitle = 'این سازنده فقط آثار موسیقی دارد';
      icon = Icons.menu_book_outlined;
    } else {
      title = 'موسیقی موجود نیست';
      subtitle = 'این سازنده فقط کتاب صوتی دارد';
      icon = Icons.music_off_outlined;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: AppColors.textTertiary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _error!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('تلاش مجدد'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card widget for displaying a work (audiobook or music) in the grid.
class _WorkCard extends StatelessWidget {
  final Map<String, dynamic> work;

  const _WorkCard({required this.work});

  @override
  Widget build(BuildContext context) {
    final title = (work['title_fa'] as String?) ?? '';
    final coverUrl = work['cover_url'] as String?;
    final isFree = work['is_free'] == true;
    final contentType = (work['content_type'] as String?) ?? 'audiobook';
    final isMusic = contentType == 'music';
    final role = work['role'] as String?;
    final roleLabel = CreatorService.getRoleLabel(role);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => AudiobookDetailScreen(audiobookId: work['id'] as int),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Cover image
                    coverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: coverUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _buildCoverPlaceholder(contentType),
                            errorWidget: (_, __, ___) => _buildCoverPlaceholder(contentType),
                          )
                        : _buildCoverPlaceholder(contentType),

                    // Gradient overlay at bottom
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 60,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.5),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Type badge (bottom left)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              switch (contentType) {
                                'music' => Icons.music_note_rounded,
                                'podcast' => Icons.podcasts_rounded,
                                'article' => Icons.article_rounded,
                                _ => Icons.menu_book_rounded,
                              },
                              size: 10,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              switch (contentType) {
                                'music' => 'موسیقی',
                                'podcast' => 'پادکست',
                                'article' => 'مقاله',
                                _ => 'کتاب',
                              },
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Free badge (top right)
                    if (isFree)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.success.withValues(alpha: 0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            'رایگان',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              roleLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.primary.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverPlaceholder(String contentType) {
    return Container(
      color: AppColors.surface,
      child: Center(
        child: Icon(
          switch (contentType) {
            'music' => Icons.music_note_rounded,
            'podcast' => Icons.podcasts_rounded,
            'article' => Icons.article_rounded,
            _ => Icons.menu_book_rounded,
          },
          size: 48,
          color: AppColors.textTertiary.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
