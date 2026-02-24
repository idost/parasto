import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/screens/audiobook_detail_screen.dart';
import 'package:myna/screens/listener/category_screen.dart';
import 'package:myna/screens/listener/shelf_detail_screen.dart';
import 'package:myna/screens/listener/audiobook_list_screen.dart';
import 'package:myna/providers/home_providers.dart';
import 'package:myna/providers/promotion_providers.dart';
import 'package:myna/providers/audio_provider.dart';
import 'package:myna/widgets/audiobook_card.dart';
import 'package:myna/widgets/shared/section_header.dart';
import 'package:myna/utils/farsi_utils.dart';
import 'package:myna/utils/app_strings.dart';
import 'package:myna/providers/author_follow_provider.dart';
import 'package:myna/providers/category_affinity_provider.dart';
import 'package:myna/widgets/home/continue_section.dart';
import 'package:myna/widgets/home/categories_section.dart';
import 'package:myna/widgets/home/recommendations.dart';
import 'package:myna/widgets/recently_played_shelf.dart';
import 'package:myna/providers/content_preference_provider.dart';
import 'package:myna/widgets/skeleton_loaders.dart';
import 'package:myna/widgets/home/skeletons.dart' as home_sk;
import 'package:myna/providers/ebook_providers.dart';
import 'package:myna/widgets/ebook_card.dart';
import 'package:myna/screens/listener/ebooks_screen.dart';
import 'package:myna/screens/ebook_detail_screen.dart';

// ============================================
// HOME SCREEN UX PLAN (Dec 2024)
// ============================================
//
// CURRENT STRUCTURE (in order):
// 1. Promo Banners Carousel
// 2. ادامه گوش دادن (Continue Listening) - most recent incomplete (books ONLY now)
// 3. اخیراً شنیده شده (Recently Played) - recent items (books ONLY now)
// 4. پیشنهاد کتاب‌ها (Featured Books) - is_music=false ✓
// 5. دسته‌بندی‌ها (Categories) - book categories
// 6. جدیدترین کتاب‌ها (New Books) - is_music=false ✓
// 7. Promo Shelves (curated collections)
// 8. پرشنونده‌ترین کتاب‌ها (Popular Books) - is_music=false ✓
//
// CHANGES MADE:
// - Section titles now include "کتاب" for clarity (پیشنهاد کتاب‌ها, جدیدترین کتاب‌ها, etc.)
// - Continue Listening and Recently Played already filter books via existing providers
// - Promo Shelves remain mixed (admin curated - can contain books or music)
//
// MUSIC UX is handled separately in music_screen.dart
// ============================================

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // PERFORMANCE: Priority 1 - Above the fold content (visible immediately)
    final bannersAsync = ref.watch(homeBannersProvider);
    final featuredAsync = ref.watch(homeFeaturedProvider);

    // PERFORMANCE: Priority 2 - Visible after slight scroll
    final categoriesAsync = ref.watch(homeCategoriesProvider);
    final newReleasesAsync = ref.watch(homeNewReleasesProvider);

    // PERFORMANCE: Priority 3 - Below fold content
    final shelvesAsync = ref.watch(homeShelvesProvider);
    final popularAsync = ref.watch(homePopularProvider);
    final podcastsAsync = ref.watch(homePodcastsProvider);
    final articlesAsync = ref.watch(homeArticlesProvider);
    final recentlyPlayedAsync = ref.watch(homeRecentlyPlayedProvider);
    final listeningStatsAsync = ref.watch(listeningStatsProvider);
    final ebookFeaturedAsync = ref.watch(ebookFeaturedProvider);

    // PERFORMANCE: Priority 4 - Personalization (user-specific)
    final continueAllAsync = ref.watch(continueListeningAllProvider);
    final followedAuthorsAsync = ref.watch(newFromFollowedAuthorsProvider);
    final favoriteCategoriesAsync = ref.watch(favoriteCategoriesContentProvider);

    // Content type preferences — controls which sections are visible
    final contentPrefs = ref.watch(contentPreferenceProvider);

    return Directionality(
      textDirection: AppStrings.isLtr ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(homeBannersProvider);
            ref.invalidate(homeShelvesProvider);
            ref.invalidate(homeFeaturedProvider);
            ref.invalidate(homeNewReleasesProvider);
            ref.invalidate(homePopularProvider);
            ref.invalidate(homePodcastsProvider);
            ref.invalidate(homeArticlesProvider);
            ref.invalidate(homeCategoriesProvider);
            ref.invalidate(homeRecentlyPlayedProvider);
            ref.invalidate(listeningStatsProvider);
            ref.invalidate(continueListeningAllProvider);
            ref.invalidate(newFromFollowedAuthorsProvider);
            ref.invalidate(favoriteCategoriesContentProvider);
            ref.invalidate(ebookFeaturedProvider);
          },
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Custom App Bar
              SliverAppBar(
                floating: true,
                backgroundColor: AppColors.background,
                elevation: 0,
                title: Text(
                  AppStrings.appName,
                  style: AppTypography.heroTitle.copyWith(fontSize: 28),
                ),
                centerTitle: false,
                actions: [
                  // Streak indicator (only shows when streak > 0)
                  listeningStatsAsync.maybeWhen(
                    data: (stats) => stats.currentStreak > 0
                        ? _StreakBadge(streak: stats.currentStreak)
                        : const SizedBox.shrink(),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // Content
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.sm),

                    // Promo Banners Carousel
                    bannersAsync.when(
                      loading: () => const ShimmerBox(width: double.infinity, height: 180),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (banners) => banners.isEmpty
                          ? const SizedBox.shrink()
                          : _PromoBannerCarousel(banners: banners),
                    ),

                    // Continue Listening Carousel (all incomplete books)
                    continueAllAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (items) => items.isEmpty
                          ? const SizedBox.shrink()
                          : ContinueSection(items: items),
                    ),

                    // Recently Played Section (extracted shelf widget)
                    recentlyPlayedAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (books) => books.isEmpty
                          ? const _EmptySection(
                              icon: Icons.history_rounded,
                              message: 'هنوز کتابی گوش ندادید',
                              actionLabel: 'مشاهده کتاب‌ها',
                              onAction: null, // Scrolling down reveals browse content
                            )
                          : RecentlyPlayedShelf(
                              books: books,
                              onSeeAll: () => navigateToRecentlyPlayedList(context),
                            ),
                    ),

                    // New Book Releases (is_music=false) - shown first
                    newReleasesAsync.when(
                      loading: () => const BookCardListSkeleton(),
                      error: (e, _) => home_sk.SectionError(
                        message: AppStrings.errorLoading(AppStrings.newBooks),
                        onRetry: () => ref.invalidate(homeNewReleasesProvider),
                      ),
                      data: (books) => books.isEmpty
                          ? const SizedBox.shrink()
                          : _AudiobookSection(
                              title: AppStrings.newBooks,
                              books: books,
                              onSeeAll: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => AudiobookListScreen(
                                    title: AppStrings.newBooks,
                                    listType: AudiobookListType.newReleases,
                                  ),
                                ),
                              ),
                            ),
                    ),

                    // Featured Books Section (is_music=false)
                    featuredAsync.when(
                      loading: () => const BookCardListSkeleton(),
                      error: (e, _) => home_sk.SectionError(
                        message: AppStrings.errorLoading(AppStrings.featuredBooks),
                        onRetry: () => ref.invalidate(homeFeaturedProvider),
                      ),
                      data: (books) => books.isEmpty
                          ? const SizedBox.shrink()
                          : _AudiobookSection(
                              title: AppStrings.featuredBooks,
                              books: books,
                              onSeeAll: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => AudiobookListScreen(
                                    title: AppStrings.featuredBooks,
                                    listType: AudiobookListType.featured,
                                  ),
                                ),
                              ),
                            ),
                    ),

                    // Categories
                    categoriesAsync.when(
                      loading: () => const CategoryChipsSkeleton(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (categories) => categories.isEmpty
                          ? const _EmptySection(
                              icon: Icons.category_rounded,
                              message: 'دسته‌بندی‌ها در دسترس نیست',
                            )
                          : CategoriesSection(categories: categories),
                    ),

                    // Listening Stats (Audible-style card)
                    listeningStatsAsync.maybeWhen(
                      data: (stats) => stats.totalListenTimeSeconds > 0
                          ? _ListeningStatsSection(stats: stats)
                          : const SizedBox.shrink(),
                      orElse: () => const SizedBox.shrink(),
                    ),

                    // Recommendations: New from followed authors
                    followedAuthorsAsync.maybeWhen(
                      data: (books) => books.isEmpty
                          ? const SizedBox.shrink()
                          : NewFromFollowedSection(books: books),
                      orElse: () => const SizedBox.shrink(),
                    ),

                    // Recommendations: Favorite categories
                    favoriteCategoriesAsync.maybeWhen(
                      data: (categories) => categories.isEmpty
                          ? const SizedBox.shrink()
                          : Column(
                              children: categories
                                  .map((cat) => FavoriteCategorySection(data: cat))
                                  .toList(),
                            ),
                      orElse: () => const SizedBox.shrink(),
                    ),

                    // Promo Shelves (curated collections)
                    shelvesAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (shelves) => Column(
                        children: shelves
                            .map((shelf) => _PromoShelfSection(shelf: shelf))
                            .toList(),
                      ),
                    ),

                    // Popular Books (is_music=false)
                    popularAsync.when(
                      loading: () => const BookCardListSkeleton(),
                      error: (_, __) => home_sk.SectionError(
                        message: AppStrings.errorLoading(AppStrings.popularBooks),
                        onRetry: () => ref.invalidate(homePopularProvider),
                      ),
                      data: (books) => books.isEmpty
                          ? const SizedBox.shrink()
                          : _AudiobookSection(
                              title: AppStrings.popularBooks,
                              books: books,
                              onSeeAll: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => AudiobookListScreen(
                                    title: AppStrings.popularBooks,
                                    listType: AudiobookListType.popular,
                                  ),
                                ),
                              ),
                            ),
                    ),

                    // Ebooks Section — respects content preferences
                    if (contentPrefs.showEbooks)
                      ebookFeaturedAsync.when(
                        loading: () => const BookCardListSkeleton(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (ebooks) => ebooks.isEmpty
                            ? const SizedBox.shrink()
                            : EbookCardList(
                                title: AppStrings.books,
                                ebooks: ebooks,
                                onSeeAllTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => const EbooksScreen(),
                                  ),
                                ),
                                onEbookTap: (ebook) => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => EbookDetailScreen(
                                      ebook: ebook,
                                    ),
                                  ),
                                ),
                              ),
                      ),

                    // Podcasts Section (is_podcast=true) — respects content preferences
                    if (contentPrefs.showPodcasts)
                      podcastsAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (podcasts) => podcasts.isEmpty
                            ? const SizedBox.shrink()
                            : _AudiobookSection(
                                title: AppStrings.podcasts,
                                books: podcasts,
                                onSeeAll: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => AudiobookListScreen(
                                      title: AppStrings.podcasts,
                                      listType: AudiobookListType.podcasts,
                                    ),
                                  ),
                                ),
                              ),
                      ),

                    // Articles Section (is_article=true) — no dedicated preference toggle
                    articlesAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (articles) => articles.isEmpty
                            ? const SizedBox.shrink()
                            : _AudiobookSection(
                                title: AppStrings.articles,
                                books: articles,
                                onSeeAll: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => AudiobookListScreen(
                                      title: AppStrings.articles,
                                      listType: AudiobookListType.articles,
                                    ),
                                  ),
                                ),
                              ),
                      ),

                    // Bottom padding: account for mini-player + nav bar + safe area
                    SizedBox(
                      height: ref.watch(audioProvider.select((s) => s.hasAudio))
                          ? 100  // mini-player (~68px) + buffer
                          : 24,  // minimal bottom padding
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// SectionHeader is now imported from lib/widgets/shared/section_header.dart

// _AudiobookCard removed — now using shared AudiobookCard from lib/widgets/audiobook_card.dart

// ============================================
// AUDIOBOOK SECTION
// ============================================

class _AudiobookSection extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> books;
  final VoidCallback? onSeeAll;

  const _AudiobookSection({
    required this.title,
    required this.books,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, onSeeAll: onSeeAll),
        SizedBox(
          height: AppDimensions.carouselHeightBook,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 20, 0),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return AudiobookCard(
                key: ValueKey(book['id']),
                book: book,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================
// PROMO SHELF SECTION
// ============================================

class _PromoShelfSection extends StatelessWidget {
  final Map<String, dynamic> shelf;

  const _PromoShelfSection({required this.shelf});

  @override
  Widget build(BuildContext context) {
    final audiobooks = shelf['audiobooks'] as List<dynamic>? ?? [];
    if (audiobooks.isEmpty) return const SizedBox.shrink();

    final shelfTitle = (shelf['title_fa'] as String?) ?? '';
    final shelfId = shelf['id'] as int;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: AppStrings.localize(shelfTitle),
          icon: Icons.auto_awesome_rounded,
          onSeeAll: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ShelfDetailScreen(
                  shelfId: shelfId,
                  shelfTitle: shelfTitle,
                ),
              ),
            );
          },
        ),
        SizedBox(
          height: AppDimensions.carouselHeightBook,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 20, 0),
            itemCount: audiobooks.length,
            itemBuilder: (context, index) {
              final book = audiobooks[index] as Map<String, dynamic>;
              return AudiobookCard(
                key: ValueKey(book['id']),
                book: book,
              );
            },
          ),
        ),
      ],
    );
  }
}

// _CategoriesSection + _CategoryChip removed — now using CategoriesSection from lib/widgets/home/categories_section.dart

// ============================================
// PROMO BANNER CAROUSEL
// ============================================

class _PromoBannerCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> banners;

  const _PromoBannerCarousel({required this.banners});

  @override
  State<_PromoBannerCarousel> createState() => _PromoBannerCarouselState();
}

class _PromoBannerCarouselState extends State<_PromoBannerCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _autoScrollTimer;
  bool _userInteracting = false;

  static const _autoScrollDuration = Duration(seconds: 5);
  static const _resumeDelay = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
    _startAutoScroll();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    if (widget.banners.length <= 1) return;

    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(_autoScrollDuration, (_) {
      if (_userInteracting || !mounted) return;

      final nextPage = (_currentPage + 1) % widget.banners.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  void _onUserInteractionStart() {
    _userInteracting = true;
    _autoScrollTimer?.cancel();
  }

  void _onUserInteractionEnd() {
    _userInteracting = false;
    // Resume auto-scroll after delay
    Future.delayed(_resumeDelay, () {
      if (mounted && !_userInteracting) {
        _startAutoScroll();
      }
    });
  }

  void _onBannerTap(Map<String, dynamic> banner) {
    final targetType = banner['target_type'] as String?;
    final targetId = banner['target_id'] as int?;

    if (targetType == null || targetId == null) return;

    switch (targetType) {
      case 'audiobook':
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => AudiobookDetailScreen(audiobookId: targetId),
          ),
        );
        break;
      case 'shelf':
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ShelfDetailScreen(
              shelfId: targetId,
              shelfTitle: banner['title_fa'] as String?,
            ),
          ),
        );
        break;
      case 'category':
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => CategoryScreen(
              categoryId: targetId,
              categoryName: (banner['title_fa'] as String?) ?? '',
            ),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: GestureDetector(
            // Pause auto-scroll when user starts interacting
            onPanDown: (_) => _onUserInteractionStart(),
            onPanEnd: (_) => _onUserInteractionEnd(),
            onPanCancel: _onUserInteractionEnd,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.banners.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) {
                final banner = widget.banners[index];
                return GestureDetector(
                  onTap: () => _onBannerTap(banner),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha:0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Background Image
                        CachedNetworkImage(
                          imageUrl: banner['image_url'] as String,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          memCacheWidth: 800, // Banner ~400px wide * 2x DPR
                          memCacheHeight: 360, // Banner 180px tall * 2x DPR
                          placeholder: (_, __) => const ColoredBox(
                            color: AppColors.surface,
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (_, __, ___) => const ColoredBox(
                            color: AppColors.primary,
                            child: Center(
                              child: Icon(Icons.campaign_rounded, size: 48, color: AppColors.textOnPrimary),
                            ),
                          ),
                        ),
                        // Gradient Overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha:0.8),
                              ],
                              stops: const [0.4, 1.0],
                            ),
                          ),
                        ),
                        // Text Content
                        Positioned(
                          bottom: 20,
                          right: 20,
                          left: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.localize((banner['title_fa'] as String?) ?? ''),
                                style: AppTypography.bannerTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (banner['subtitle_fa'] != null &&
                                  (banner['subtitle_fa'] as String).isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  AppStrings.localize(banner['subtitle_fa'] as String),
                                  style: AppTypography.bannerSubtitle.copyWith(
                                    color: AppColors.textOnPrimary.withValues(alpha:0.9),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
              },
            ),
          ),
        ),
        // Page Indicator
        if (widget.banners.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.banners.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? AppColors.primary
                        : AppColors.textTertiary.withValues(alpha:0.3),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================
// EMPTY SECTION (subtle hint when no content)
// ============================================

class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptySection({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sectionPaddingHorizontal,
        vertical: AppSpacing.md,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xl,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            Icon(icon, size: AppDimensions.iconLarge, color: AppColors.textTertiary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(
                onPressed: onAction,
                child: Text(
                  actionLabel!,
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// _BannerSkeleton, _SectionSkeleton, _CategoriesSkeleton removed — now using shimmer-based loaders from lib/widgets/skeleton_loaders.dart
// _SectionError removed — now using SectionError from lib/widgets/home/skeletons.dart

// ============================================
// RECENTLY PLAYED SECTION (Continue Listening)
// ============================================

// _RecentlyPlayedSection + _RecentlyPlayedCard removed — now using RecentlyPlayedShelf from lib/widgets/recently_played_shelf.dart
// _CompactResumeBar + _ContinueListeningCard removed — now using ContinueSection from lib/widgets/home/continue_section.dart

// ============================================
// STREAK BADGE
// ============================================

class _StreakBadge extends StatelessWidget {
  final int streak;

  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha:0.15),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.warning.withValues(alpha:0.25),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.whatshot_rounded,
              size: 18,
              color: AppColors.warning,
            ),
            const SizedBox(width: 4),
            Text(
              FarsiUtils.toFarsiDigits(streak),
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.warning,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// LISTENING STATS SECTION (Audible-style)
// ============================================

class _ListeningStatsSection extends StatelessWidget {
  final ListeningStats stats;

  const _ListeningStatsSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    final hasStats = stats.totalListenTimeSeconds > 0;

    return Container(
      margin: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha:0.08),
            AppColors.secondary.withValues(alpha:0.05),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.primary.withValues(alpha:0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                hasStats ? Icons.bar_chart_rounded : Icons.headphones_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                hasStats ? AppStrings.yourListeningStats : AppStrings.startListening,
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats Row or Encouragement Message
          if (hasStats)
            Row(
              children: [
                // Total Listen Time
                Expanded(
                  child: _StatItem(
                    icon: Icons.headphones_rounded,
                    value: stats.formattedTotalTime,
                    label: AppStrings.listeningTime,
                    color: AppColors.primary,
                  ),
                ),
                // Books Completed
                Expanded(
                  child: _StatItem(
                    icon: Icons.task_alt_rounded,
                    value: FarsiUtils.toFarsiDigits(stats.booksCompleted),
                    label: AppStrings.booksFinished,
                    color: AppColors.success,
                  ),
                ),
                // Current Streak
                if (stats.currentStreak > 0)
                  Expanded(
                    child: _StatItem(
                      icon: Icons.whatshot_rounded,
                      value: AppStrings.streakDays(stats.currentStreak),
                      label: AppStrings.streakRecord,
                      color: AppColors.warning,
                    ),
                  ),
              ],
            )
          else
            Text(
              AppStrings.startListeningMessage,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textTertiary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
