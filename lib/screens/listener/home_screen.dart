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
import 'package:myna/services/auth_service.dart';

// ============================================
// HOME SCREEN — Redesigned with Visual Rhythm
// ============================================
//
// SECTION ORDER (3-act structure):
//
// ACT 1: YOUR WORLD
// 1. Greeting header (time-aware + user name)
// 2. Featured banner carousel
// 3. Continue listening
// 4. Listening stats (moved up)
// 5. "Because you listened to..." (NEW)
//
// ACT 2: WHAT'S HAPPENING
// 6. New releases (LARGE cards)
// 7. Popular (NUMBERED vertical list)
// 8. Narrator spotlight (NEW)
// 9. Parasto Originals (NEW, LARGE cards)
//
// ACT 3: GO DEEPER
// 10. Music
// 11. Podcasts
// 12. Ebooks
// 13+ Favorite categories (algorithmic)
// 14. Followed authors
// 15. Promo shelves (COMPACT cards for deep browse)
// 16. Recently played (moved down)
// 17. Featured/Suggestions
// 18. Articles
// 19. Categories (keep at end)
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

    // New providers for redesign
    final originalsAsync = ref.watch(homeOriginalsProvider);
    final musicAsync = ref.watch(homeMusicProvider);
    final becauseYouListenedAsync = ref.watch(becauseYouListenedProvider);
    final narratorSpotlightAsync = ref.watch(narratorSpotlightProvider);

    // User profile for greeting
    final profileAsync = ref.watch(profileProvider);

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
            ref.invalidate(homeOriginalsProvider);
            ref.invalidate(homeMusicProvider);
            ref.invalidate(becauseYouListenedProvider);
            ref.invalidate(narratorSpotlightProvider);
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
                    // ════════════════════════════════════════════
                    // ACT 1: YOUR WORLD
                    // ════════════════════════════════════════════

                    // 1. Greeting Header (NEW)
                    profileAsync.maybeWhen(
                      data: (profile) => _GreetingHeader(
                        userName: profile?.displayName ?? profile?.fullName,
                      ),
                      orElse: () => const _GreetingHeader(userName: null),
                    ),

                    // 2. Featured Banner Carousel (keep as-is)
                    bannersAsync.when(
                      loading: () => const ShimmerBox(width: double.infinity, height: 180),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (banners) => banners.isEmpty
                          ? const SizedBox.shrink()
                          : _PromoBannerCarousel(banners: banners),
                    ),

                    // 3. Continue Listening (keep as-is)
                    continueAllAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (items) => items.isEmpty
                          ? const SizedBox.shrink()
                          : ContinueSection(items: items),
                    ),

                    // 4. Listening Stats (MOVED UP from near bottom)
                    listeningStatsAsync.maybeWhen(
                      data: (stats) => stats.totalListenTimeSeconds > 0
                          ? _ListeningStatsSection(stats: stats)
                          : const SizedBox.shrink(),
                      orElse: () => const SizedBox.shrink(),
                    ),

                    // 5. "Because you listened to..." (NEW)
                    becauseYouListenedAsync.maybeWhen(
                      data: (data) => data == null
                          ? const SizedBox.shrink()
                          : _AudiobookSection(
                              title: AppStrings.becauseYouListenedTo(data.sourceBookTitle),
                              books: data.recommendations,
                            ),
                      orElse: () => const SizedBox.shrink(),
                    ),

                    // ════════════════════════════════════════════
                    // ACT 2: WHAT'S HAPPENING
                    // ════════════════════════════════════════════

                    // 6. New Releases (LARGE cards)
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
                              cardWidth: AppDimensions.cardWidthLarge,
                              cardCoverHeight: 270.0,
                              carouselHeight: 390.0,
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

                    // 7. Popular Books (NUMBERED VERTICAL LIST)
                    popularAsync.when(
                      loading: () => const BookCardListSkeleton(),
                      error: (_, __) => home_sk.SectionError(
                        message: AppStrings.errorLoading(AppStrings.popularBooks),
                        onRetry: () => ref.invalidate(homePopularProvider),
                      ),
                      data: (books) => books.isEmpty
                          ? const SizedBox.shrink()
                          : _PopularNumberedList(
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

                    // 8. Narrator Spotlight (NEW)
                    narratorSpotlightAsync.maybeWhen(
                      data: (data) => data == null
                          ? const SizedBox.shrink()
                          : _NarratorSpotlightSection(data: data),
                      orElse: () => const SizedBox.shrink(),
                    ),

                    // 9. Parasto Originals (NEW, LARGE cards)
                    originalsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (books) => books.isEmpty
                          ? const SizedBox.shrink()
                          : _AudiobookSection(
                              title: AppStrings.parastoOriginals,
                              books: books,
                              icon: Icons.auto_awesome_rounded,
                              cardWidth: AppDimensions.cardWidthLarge,
                              cardCoverHeight: 270.0,
                              carouselHeight: 390.0,
                            ),
                    ),

                    // ════════════════════════════════════════════
                    // ACT 3: GO DEEPER
                    // ════════════════════════════════════════════

                    // 10. Music (NEW on home screen)
                    musicAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (items) => items.isEmpty
                          ? const SizedBox.shrink()
                          : _AudiobookSection(
                              title: AppStrings.music,
                              books: items,
                            ),
                    ),

                    // 11. Podcasts
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

                    // 12. Ebooks
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

                    // 13. Favorite categories (algorithmic — "برتر در شعر", etc.)
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

                    // 14. New from followed authors
                    followedAuthorsAsync.maybeWhen(
                      data: (books) => books.isEmpty
                          ? const SizedBox.shrink()
                          : NewFromFollowedSection(books: books),
                      orElse: () => const SizedBox.shrink(),
                    ),

                    // 15. Promo Shelves (COMPACT cards for deep browse)
                    shelvesAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (shelves) => Column(
                        children: shelves
                            .map((shelf) => _PromoShelfSection(
                                  shelf: shelf,
                                  compact: true,
                                ))
                            .toList(),
                      ),
                    ),

                    // 16. Recently Played (moved down)
                    recentlyPlayedAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (books) => books.isEmpty
                          ? const SizedBox.shrink()
                          : RecentlyPlayedShelf(
                              books: books,
                              onSeeAll: () => navigateToRecentlyPlayedList(context),
                            ),
                    ),

                    // 17. Featured/Suggestions (moved to end)
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
                              cardWidth: AppDimensions.cardWidthSmall,
                              cardCoverHeight: AppDimensions.cardCoverHeightSmall,
                              carouselHeight: 280.0,
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

                    // 18. Articles
                    articlesAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (articles) => articles.isEmpty
                            ? const SizedBox.shrink()
                            : _AudiobookSection(
                                title: AppStrings.articles,
                                books: articles,
                                cardWidth: AppDimensions.cardWidthSmall,
                                cardCoverHeight: AppDimensions.cardCoverHeightSmall,
                                carouselHeight: 280.0,
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

                    // 19. Categories (keep at end)
                    categoriesAsync.when(
                      loading: () => const CategoryChipsSkeleton(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (categories) => categories.isEmpty
                          ? const SizedBox.shrink()
                          : CategoriesSection(categories: categories),
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

// ============================================
// GREETING HEADER (Phase 2A)
// ============================================

class _GreetingHeader extends StatelessWidget {
  final String? userName;

  const _GreetingHeader({required this.userName});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    String greeting;
    String emoji;

    if (hour >= 5 && hour < 12) {
      greeting = AppStrings.isLtr ? 'Good morning' : 'صبح بخیر';
      emoji = '☀️';
    } else if (hour >= 12 && hour < 17) {
      greeting = AppStrings.isLtr ? 'Good afternoon' : 'ظهر بخیر';
      emoji = '🌤️';
    } else if (hour >= 17 && hour < 21) {
      greeting = AppStrings.isLtr ? 'Good evening' : 'عصر بخیر';
      emoji = '🌅';
    } else {
      greeting = AppStrings.isLtr ? 'Good night' : 'شب بخیر';
      emoji = '🌙';
    }

    final displayName = userName ?? '';
    final fullGreeting = displayName.isNotEmpty
        ? '$greeting، $displayName $emoji'
        : '${AppStrings.isLtr ? 'Hello' : 'سلام'} $emoji';

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fullGreeting,
            style: AppTypography.headlineLarge.copyWith(
              fontSize: 22,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.greetingSubtitle,
            style: AppTypography.bodyMedium.copyWith(
              fontSize: 14,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// AUDIOBOOK SECTION (supports card size variations)
// ============================================

class _AudiobookSection extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> books;
  final VoidCallback? onSeeAll;
  final IconData? icon;
  final double cardWidth;
  final double cardCoverHeight;
  final double carouselHeight;

  const _AudiobookSection({
    required this.title,
    required this.books,
    this.onSeeAll,
    this.icon,
    this.cardWidth = AppDimensions.cardWidth,
    this.cardCoverHeight = AppDimensions.cardCoverHeight,
    this.carouselHeight = AppDimensions.carouselHeightBook,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, onSeeAll: onSeeAll, icon: icon),
        SizedBox(
          height: carouselHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 20, 0),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return AudiobookCard(
                key: ValueKey(book['id']),
                book: book,
                width: cardWidth,
                coverHeight: cardCoverHeight,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================
// POPULAR NUMBERED LIST (Phase 3B)
// ============================================

class _PopularNumberedList extends StatelessWidget {
  final List<Map<String, dynamic>> books;
  final VoidCallback? onSeeAll;

  const _PopularNumberedList({
    required this.books,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final topBooks = books.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: AppStrings.popularBooks,
          onSeeAll: onSeeAll,
          icon: Icons.local_fire_department_rounded,
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
          child: Column(
            children: List.generate(topBooks.length, (index) {
              final book = topBooks[index];
              final title = (book['title_fa'] as String?) ?? '';
              final author = (book['author_fa'] as String?) ?? '';
              final coverUrl = book['cover_url'] as String?;
              final playCount = (book['play_count'] as num?)?.toInt() ?? 0;
              final bookId = book['id'] as int?;
              final rank = FarsiUtils.toFarsiDigits(index + 1);

              return GestureDetector(
                onTap: () {
                  if (bookId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => AudiobookDetailScreen(audiobookId: bookId),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: index < topBooks.length - 1
                        ? Border(
                            bottom: BorderSide(
                              color: AppColors.borderSubtle,
                              width: 0.5,
                            ),
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      // Rank number
                      SizedBox(
                        width: 32,
                        child: Text(
                          rank,
                          style: AppTypography.displayLarge.copyWith(
                            fontSize: 28,
                            color: AppColors.primary.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Cover thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: coverUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: coverUrl,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 112,
                                  memCacheHeight: 112,
                                  placeholder: (_, __) => const ColoredBox(
                                    color: AppColors.surface,
                                  ),
                                  errorWidget: (_, __, ___) => const ColoredBox(
                                    color: AppColors.surface,
                                    child: Icon(Icons.headphones_rounded,
                                        size: 24, color: AppColors.textTertiary),
                                  ),
                                )
                              : const ColoredBox(
                                  color: AppColors.surface,
                                  child: Icon(Icons.headphones_rounded,
                                      size: 24, color: AppColors.textTertiary),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Title + author + play count
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: AppTypography.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (author.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                author,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 2),
                            Text(
                              AppStrings.playCount(
                                FarsiUtils.toFarsiDigits(playCount),
                              ),
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Play icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

// ============================================
// NARRATOR SPOTLIGHT SECTION (Phase 2C)
// ============================================

class _NarratorSpotlightSection extends StatelessWidget {
  final NarratorSpotlightData data;

  const _NarratorSpotlightSection({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: AppStrings.narratorSpotlight,
          icon: Icons.mic_rounded,
        ),
        // Narrator card
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceLight,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: data.avatarUrl != null
                        ? CachedNetworkImage(
                            imageUrl: data.avatarUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Icon(
                              Icons.mic_rounded,
                              size: 28,
                              color: AppColors.textTertiary,
                            ),
                            errorWidget: (_, __, ___) => const Icon(
                              Icons.mic_rounded,
                              size: 28,
                              color: AppColors.textTertiary,
                            ),
                          )
                        : const Icon(
                            Icons.mic_rounded,
                            size: 28,
                            color: AppColors.textTertiary,
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                // Name + book count
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.narratorName,
                        style: AppTypography.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppStrings.narratorBookCount(
                          FarsiUtils.toFarsiDigits(data.bookCount),
                        ),
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Narrator's top books
        SizedBox(
          height: AppDimensions.carouselHeightBook,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 20, 0),
            itemCount: data.topBooks.length,
            itemBuilder: (context, index) {
              final book = data.topBooks[index];
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
// PROMO SHELF SECTION (supports compact mode)
// ============================================

class _PromoShelfSection extends StatelessWidget {
  final Map<String, dynamic> shelf;
  final bool compact;

  const _PromoShelfSection({
    required this.shelf,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final audiobooks = shelf['audiobooks'] as List<dynamic>? ?? [];
    if (audiobooks.isEmpty) return const SizedBox.shrink();

    final shelfTitle = (shelf['title_fa'] as String?) ?? '';
    final shelfId = shelf['id'] as int;

    final double effectiveWidth = compact
        ? AppDimensions.cardWidthSmall
        : AppDimensions.cardWidth;
    final double effectiveCoverHeight = compact
        ? AppDimensions.cardCoverHeightSmall
        : AppDimensions.cardCoverHeight;
    final double effectiveCarouselHeight = compact ? 280.0 : AppDimensions.carouselHeightBook;

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
          height: effectiveCarouselHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 20, 0),
            itemCount: audiobooks.length,
            itemBuilder: (context, index) {
              final book = audiobooks[index] as Map<String, dynamic>;
              return AudiobookCard(
                key: ValueKey(book['id']),
                book: book,
                width: effectiveWidth,
                coverHeight: effectiveCoverHeight,
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
