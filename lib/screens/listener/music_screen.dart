import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/screens/audiobook_detail_screen.dart';
import 'package:myna/screens/listener/search_screen.dart';
import 'package:myna/screens/listener/music_list_screen.dart';
import 'package:myna/screens/listener/library_screen.dart' show ownedItemsWithProgressProvider, ContentType;
import 'package:myna/providers/home_providers.dart';

// ============================================
// MUSIC SCREEN UX PLAN (Dec 2024)
// ============================================
//
// STRUCTURE (in order):
// 1. Category Filter Chips (همه سبک‌ها, پاپ, سنتی, کلاسیک, etc.)
// 2. ادامه‌ی شنیدن موسیقی (Continue Listening Music) - recently played music
// 3. موسیقی ویژه (Featured Music) - content_type='music', is_featured=true
// 4. جدیدترین‌ها (New Releases) - content_type='music', newest first
// 5. پرشنونده‌ترین‌ها (Popular Music) - content_type='music', by play_count
// 6. همه موسیقی‌ها (All Music) - grid of all music
//
// When a category is selected, only filtered grid is shown.
//
// MUSIC-SPECIFIC LABELS:
// - Detail screen shows "درباره‌ی این اثر" instead of "درباره‌ی کتاب"
// - هنرمند / آهنگساز / سال انتشار used where metadata exists
//
// DATABASE:
// - audiobooks.content_type: 'music' to distinguish music from audiobooks
// - music_categories: 10 predefined genres
// - audiobook_music_categories: junction table for many-to-many relationship
// ============================================

/// Music screen - shows music content (content_type = 'music')
/// This screen is displayed in the bottom navigation "موسیقی" tab
class MusicScreen extends ConsumerStatefulWidget {
  const MusicScreen({super.key, this.initialCategoryId});

  final int? initialCategoryId;

  @override
  ConsumerState<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends ConsumerState<MusicScreen> {
  @override
  void initState() {
    super.initState();
    // Set initial category if provided
    if (widget.initialCategoryId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedMusicCategoryProvider.notifier).state = widget.initialCategoryId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ownedMusicAsync = ref.watch(ownedItemsWithProgressProvider(ContentType.music));
    final continueListeningAsync = ref.watch(musicContinueListeningProvider);
    final featuredAsync = ref.watch(musicFeaturedProvider);
    final newReleasesAsync = ref.watch(musicNewReleasesProvider);
    final popularAsync = ref.watch(musicPopularProvider);
    final categoriesAsync = ref.watch(musicCategoriesForFilterProvider);
    final selectedCategory = ref.watch(selectedMusicCategoryProvider);
    final filteredMusicAsync = ref.watch(musicByCategoryProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(musicContinueListeningProvider);
            ref.invalidate(musicFeaturedProvider);
            ref.invalidate(musicNewReleasesProvider);
            ref.invalidate(musicPopularProvider);
            ref.invalidate(musicCategoriesForFilterProvider);
            ref.invalidate(musicByCategoryProvider);
          },
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // App Bar
              SliverAppBar(
                floating: true,
                backgroundColor: AppColors.background,
                elevation: 0,
                title: const Row(
                  children: [
                    Icon(Icons.music_note, color: AppColors.primary, size: 28),
                    SizedBox(width: 8),
                    Text(
                      'موسیقی',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                centerTitle: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.search, size: 28),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // Category Filter Chips
              SliverToBoxAdapter(
                child: categoriesAsync.when(
                  loading: () => const SizedBox(height: 48),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (categories) => categories.isEmpty
                      ? const SizedBox.shrink()
                      : _MusicCategoryFilter(
                          categories: categories,
                          selectedCategoryId: selectedCategory,
                          onCategorySelected: (id) {
                            ref.read(selectedMusicCategoryProvider.notifier).state = id;
                          },
                        ),
                ),
              ),

              // Content
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Show horizontal sections only when no category filter is selected
                    if (selectedCategory == null) ...[
                      // موسیقی‌های من (My Music) - owned music section
                      ownedMusicAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (items) => items.isEmpty
                            ? const SizedBox.shrink()
                            : _OwnedMusicSection(items: items),
                      ),

                      // Continue Listening Music Section (ادامه‌ی شنیدن موسیقی)
                      continueListeningAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (items) => items.isEmpty
                            ? const SizedBox.shrink()
                            : _MusicContinueListeningSection(items: items),
                      ),

                      // Featured Music Section
                      featuredAsync.when(
                        loading: () => const _MusicSectionSkeleton(),
                        error: (e, _) => _MusicSectionError(
                          message: 'خطا در بارگذاری موسیقی ویژه',
                          onRetry: () => ref.invalidate(musicFeaturedProvider),
                        ),
                        data: (items) => items.isEmpty
                            ? const SizedBox.shrink()
                            : _MusicSection(
                                title: 'موسیقی ویژه',
                                icon: Icons.auto_awesome_rounded,
                                items: items,
                                listType: MusicListType.featured,
                              ),
                      ),

                      // New Releases
                      newReleasesAsync.when(
                        loading: () => const _MusicSectionSkeleton(),
                        error: (e, _) => _MusicSectionError(
                          message: 'خطا در بارگذاری موسیقی جدید',
                          onRetry: () => ref.invalidate(musicNewReleasesProvider),
                        ),
                        data: (items) => items.isEmpty
                            ? const SizedBox.shrink()
                            : _MusicSection(
                                title: 'جدیدترین‌ها',
                                icon: Icons.new_releases_rounded,
                                items: items,
                                listType: MusicListType.newReleases,
                              ),
                      ),

                      // Popular Music
                      popularAsync.when(
                        loading: () => const _MusicSectionSkeleton(),
                        error: (e, _) => _MusicSectionError(
                          message: 'خطا در بارگذاری موسیقی محبوب',
                          onRetry: () => ref.invalidate(musicPopularProvider),
                        ),
                        data: (items) => items.isEmpty
                            ? const SizedBox.shrink()
                            : _MusicSection(
                                title: 'پرشنونده‌ترین‌ها',
                                icon: Icons.trending_up_rounded,
                                items: items,
                                listType: MusicListType.popular,
                              ),
                      ),
                    ],

                    // All Music Grid (filtered by category if selected)
                    if (selectedCategory != null) ...[
                      // When category is selected, show filtered results only
                      filteredMusicAsync.when(
                        loading: () => const _MusicGridSkeleton(),
                        error: (e, _) => _MusicSectionError(
                          message: 'خطا در بارگذاری موسیقی',
                          onRetry: () => ref.invalidate(musicByCategoryProvider),
                        ),
                        data: (items) => items.isEmpty
                            ? _buildEmptyCategoryState()
                            : _MusicGrid(items: items, showAllTitle: false),
                      ),
                    ] else ...[
                      // No filter - show all music at bottom
                      filteredMusicAsync.when(
                        loading: () => const _MusicGridSkeleton(),
                        error: (e, _) => _MusicSectionError(
                          message: 'خطا در بارگذاری موسیقی',
                          onRetry: () => ref.invalidate(musicByCategoryProvider),
                        ),
                        data: (items) => items.isEmpty
                            ? _buildEmptyState()
                            : _MusicGrid(items: items, showAllTitle: true),
                      ),
                    ],

                    // Bottom padding for mini player clearance
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_off,
              size: 64,
              color: AppColors.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'هنوز موسیقی‌ای اضافه نشده',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'به زودی موسیقی‌های جدید اضافه می‌شود',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCategoryState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: AppColors.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'موسیقی‌ای در این سبک یافت نشد',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'سبک دیگری را امتحان کنید',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// MUSIC CATEGORY FILTER (Horizontal Chips)
// ============================================

class _MusicCategoryFilter extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final int? selectedCategoryId;
  final ValueChanged<int?> onCategorySelected;

  const _MusicCategoryFilter({
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length + 1, // +1 for "All" option
        itemBuilder: (context, index) {
          if (index == 0) {
            // "All" option
            final isSelected = selectedCategoryId == null;
            return Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: _CategoryChip(
                label: 'همه سبک‌ها',
                isSelected: isSelected,
                onTap: () => onCategorySelected(null),
              ),
            );
          }

          final category = categories[index - 1];
          final categoryId = category['id'] as int;
          final isSelected = selectedCategoryId == categoryId;
          final nameFa = (category['name_fa'] as String?) ?? '';

          return Padding(
            padding: const EdgeInsetsDirectional.only(start: 8),
            child: _CategoryChip(
              label: nameFa,
              isSelected: isSelected,
              onTap: () => onCategorySelected(categoryId),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.textOnPrimary : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ============================================
// MUSIC CONTINUE LISTENING SECTION
// ============================================

class _MusicContinueListeningSection extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const _MusicContinueListeningSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with View All button
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              const Icon(Icons.play_circle_outline, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'ادامه‌ی شنیدن',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const MusicListScreen(
                        title: 'ادامه‌ی شنیدن',
                        listType: MusicListType.continueListening,
                      ),
                    ),
                  );
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'مشاهده همه',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_back_ios, size: 12, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Horizontal list with sleek cards
        SizedBox(
          height: 128,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(end: 20, start: 8),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _MusicContinueCard(
                key: ValueKey(item['id']),
                item: item,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MusicContinueCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _MusicContinueCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final title = (item['title_fa'] as String?) ?? '';
    final isParastoBrand = (item['is_parasto_brand'] as bool?) ?? false;
    final author = (item['author_fa'] as String?) ?? '';
    final musicMeta = item['music_metadata'] as Map<String, dynamic>?;
    final artistRaw = (musicMeta?['artist_name'] as String?) ?? '';
    final artist = isParastoBrand
        ? 'پرستو'
        : (author.isNotEmpty ? author : (artistRaw.isNotEmpty ? artistRaw : 'موسیقی'));
    final coverUrl = item['cover_url'] as String?;
    final progress = item['progress'] as Map<String, dynamic>?;
    final completionPercentage = (progress?['completion_percentage'] as num?)?.toInt() ?? 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => AudiobookDetailScreen(audiobookId: item['id'] as int),
          ),
        );
      },
      child: Container(
        width: 280,
        margin: const EdgeInsetsDirectional.only(start: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Cover image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: coverUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _buildPlaceholder(),
                        errorWidget: (_, __, ___) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
            ),
            const SizedBox(width: 14),
            // Info section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    artist,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  // Progress bar
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerRight,
                            widthFactor: completionPercentage / 100,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '٪${completionPercentage.toString().replaceAllMapped(RegExp(r'\d'), (m) => String.fromCharCode(m.group(0)!.codeUnitAt(0) + 0x6C0))}',
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Play button
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: AppColors.textOnPrimary,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return const ColoredBox(
      color: AppColors.surfaceLight,
      child: Center(
        child: Icon(Icons.music_note_rounded, color: AppColors.textTertiary, size: 32),
      ),
    );
  }
}

// ============================================
// MUSIC SECTION (Horizontal Scroll)
// ============================================

class _MusicSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Map<String, dynamic>> items;
  final MusicListType listType;

  const _MusicSection({
    required this.title,
    required this.icon,
    required this.items,
    required this.listType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with View All button
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => MusicListScreen(
                        title: title,
                        listType: listType,
                      ),
                    ),
                  );
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'مشاهده همه',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_back_ios, size: 12, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Horizontal list
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(end: 20, start: 8),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _MusicCard(
                key: ValueKey(item['id']),
                item: item,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================
// MUSIC CARD
// ============================================

class _MusicCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _MusicCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final title = (item['title_fa'] as String?) ?? '';
    final isParastoBrand = (item['is_parasto_brand'] as bool?) ?? false;
    final author = (item['author_fa'] as String?) ?? '';
    // Get artist from music_metadata (not profiles which is the uploader account)
    final musicMeta = item['music_metadata'] as Map<String, dynamic>?;
    final artistRaw = (musicMeta?['artist_name'] as String?) ?? '';
    final artist = isParastoBrand
        ? 'پرستو'
        : (author.isNotEmpty ? author : (artistRaw.isNotEmpty ? artistRaw : 'موسیقی'));
    final coverUrl = item['cover_url'] as String?;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => AudiobookDetailScreen(audiobookId: item['id'] as int),
          ),
        );
      },
      child: Container(
        width: 160,
        margin: const EdgeInsetsDirectional.only(start: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover with shadow (square for music)
            Container(
              height: 160,
              width: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    coverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: coverUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _buildPlaceholder(),
                            errorWidget: (_, __, ___) => _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                    // Music icon overlay
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          size: 16,
                          color: AppColors.textOnPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),

            // Artist (always shown for music)
            Text(
              artist,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return const ColoredBox(
      color: AppColors.surface,
      child: Center(
        child: Icon(Icons.music_note, color: AppColors.textTertiary, size: 36),
      ),
    );
  }
}

// ============================================
// MUSIC GRID (All Music)
// ============================================

class _MusicGrid extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final bool showAllTitle;

  const _MusicGrid({required this.items, this.showAllTitle = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header (only show when not filtering by category)
        if (showAllTitle)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Row(
              children: [
                Icon(Icons.library_music, size: 20, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'همه موسیقی‌ها',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          )
        else
          const SizedBox(height: 16), // Just add some space when filtered
        // Grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.78,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _MusicGridItem(
                key: ValueKey(item['id']),
                item: item,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MusicGridItem extends StatelessWidget {
  final Map<String, dynamic> item;

  const _MusicGridItem({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final title = (item['title_fa'] as String?) ?? '';
    final isParastoBrand = (item['is_parasto_brand'] as bool?) ?? false;
    final author = (item['author_fa'] as String?) ?? '';
    // Get artist from music_metadata (not profiles which is the uploader account)
    final musicMeta = item['music_metadata'] as Map<String, dynamic>?;
    final artistRaw = (musicMeta?['artist_name'] as String?) ?? '';
    final artist = isParastoBrand
        ? 'پرستو'
        : (author.isNotEmpty ? author : (artistRaw.isNotEmpty ? artistRaw : 'موسیقی'));
    final coverUrl = item['cover_url'] as String?;
    final isFree = item['is_free'] == true;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => AudiobookDetailScreen(audiobookId: item['id'] as int),
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
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    coverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: coverUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _buildPlaceholder(),
                            errorWidget: (_, __, ___) => _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                    // Play icon
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          size: 20,
                          color: AppColors.textOnPrimary,
                        ),
                      ),
                    ),
                    // Free badge
                    if (isFree)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'رایگان',
                            style: TextStyle(
                              color: AppColors.textOnPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Title
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          // Artist (always shown for music)
          Text(
            artist,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return const ColoredBox(
      color: AppColors.surface,
      child: Center(
        child: Icon(Icons.music_note, color: AppColors.textTertiary, size: 40),
      ),
    );
  }
}

// ============================================
// SKELETONS
// ============================================

class _MusicSectionSkeleton extends StatelessWidget {
  const _MusicSectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Container(
            width: 120,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(end: 20),
            itemCount: 4,
            itemBuilder: (context, index) {
              return Container(
                width: 160,
                margin: const EdgeInsetsDirectional.only(start: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 160,
                      width: 160,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 14,
                      width: 100,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 10,
                      width: 70,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MusicGridSkeleton extends StatelessWidget {
  const _MusicGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
        ),
        itemCount: 4,
        itemBuilder: (context, index) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 14,
                width: 100,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                height: 10,
                width: 70,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MusicSectionError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _MusicSectionError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: const Text('تلاش مجدد'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// OWNED MUSIC SECTION - User's purchased music
// ============================================

class _OwnedMusicSection extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const _OwnedMusicSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              const Icon(Icons.library_music_rounded, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'موسیقی‌های من',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        // Horizontal list of owned music
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(end: 20, start: 8),
            itemCount: items.length > 10 ? 10 : items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _OwnedMusicCard(
                key: ValueKey(item['id']),
                item: item,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OwnedMusicCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _OwnedMusicCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final title = (item['title_fa'] as String?) ?? '';
    final isParastoBrand = (item['is_parasto_brand'] as bool?) ?? false;
    final author = (item['author_fa'] as String?) ?? '';
    final musicMeta = item['music_metadata'] as Map<String, dynamic>?;
    final artistRaw = (musicMeta?['artist_name'] as String?) ?? '';
    final artist = isParastoBrand
        ? 'پرستو'
        : (author.isNotEmpty ? author : (artistRaw.isNotEmpty ? artistRaw : 'موسیقی'));
    final coverUrl = item['cover_url'] as String?;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => AudiobookDetailScreen(audiobookId: item['id'] as int),
          ),
        );
      },
      child: Container(
        width: 160,
        margin: const EdgeInsetsDirectional.only(start: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: coverUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: AppColors.surface,
                          child: const Icon(Icons.music_note_rounded, color: AppColors.textTertiary, size: 40),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.surface,
                          child: const Icon(Icons.music_note_rounded, color: AppColors.textTertiary, size: 40),
                        ),
                      )
                    : Container(
                        color: AppColors.surface,
                        child: const Icon(Icons.music_note_rounded, color: AppColors.textTertiary, size: 40),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            // Title
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Artist
            Text(
              artist,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
