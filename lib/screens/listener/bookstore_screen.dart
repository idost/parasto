import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/screens/audiobook_detail_screen.dart';
import 'package:myna/screens/listener/categories_list_screen.dart';
import 'package:myna/screens/listener/shelf_detail_screen.dart';
import 'package:myna/screens/listener/audiobook_list_screen.dart';
import 'package:myna/providers/home_providers.dart';
import 'package:myna/providers/promotion_providers.dart';
import 'package:myna/utils/app_strings.dart';
import 'package:myna/widgets/content_type_badge.dart';

// ============================================
// BOOKSTORE SCREEN (NAV-RESTRUCTURE-01)
// ============================================
//
// PURPOSE: Full catalog / store tab (کتاب‌فروشی)
// Part of the 5-tab navigation structure:
//   0. Home (خانه) - discover / promo
//   1. Bookstore (کتاب‌فروشی) - full catalog (THIS SCREEN)
//   2. Audiobooks (کتاب‌های صوتی) - listening hub
//   3. Library (کتابخانه) - my stuff
//   4. Search (جستجو) - global search
//
// V1 STRUCTURE (temporary - reuses existing providers):
// 1. Promo Banners Carousel (same as Home)
// 2. تازه‌ها (New Releases)
// 3. پیشنهاد کتاب‌ها (Featured Books)
// 4. دسته‌بندی‌ها (Categories)
// 5. Promo Shelves (curated collections)
// 6. پرشنونده‌ترین‌ها (Popular Books)
//
// TODO(NAV-RESTRUCTURE-02): Differentiate from Home by:
// - Adding "All Books" grid at bottom
// - Adding filter chips (genre, price, etc.)
// - Adding "Staff Picks" section
// ============================================

class BookstoreScreen extends ConsumerWidget {
  const BookstoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reuse existing providers for v1
    final bannersAsync = ref.watch(homeBannersProvider);
    final featuredAsync = ref.watch(homeFeaturedProvider);
    final categoriesAsync = ref.watch(homeCategoriesProvider);
    final newReleasesAsync = ref.watch(homeNewReleasesProvider);
    final shelvesAsync = ref.watch(homeShelvesProvider);
    final popularAsync = ref.watch(homePopularProvider);

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
            ref.invalidate(homeCategoriesProvider);
          },
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // App Bar
              // NAV-RESTRUCTURE-01: Disable back arrow since this is a tab, not a pushed route
              SliverAppBar(
                floating: true,
                automaticallyImplyLeading: false,
                backgroundColor: AppColors.background,
                elevation: 0,
                title: Text(
                  AppStrings.bookstore,
                  style: AppTypography.heroTitle.copyWith(fontSize: 28),
                ),
                centerTitle: false,
              ),

              // Content
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Promo Banners Carousel
                    bannersAsync.when(
                      loading: () => const _BannerSkeleton(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (banners) => banners.isEmpty
                          ? const SizedBox.shrink()
                          : _PromoBannerCarousel(banners: banners),
                    ),

                    // New Book Releases
                    newReleasesAsync.when(
                      loading: () => const _SectionSkeleton(),
                      error: (e, _) => _SectionError(
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

                    // Featured Books Section
                    featuredAsync.when(
                      loading: () => const _SectionSkeleton(),
                      error: (e, _) => _SectionError(
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
                      loading: () => const _CategoriesSkeleton(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (categories) => categories.isEmpty
                          ? const SizedBox.shrink()
                          : _CategoriesSection(categories: categories),
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

                    // Popular Books
                    popularAsync.when(
                      loading: () => const _SectionSkeleton(),
                      error: (_, __) => _SectionError(
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
}

// ============================================
// SECTION HEADER
// ============================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const _SectionHeader({
    required this.title,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppTypography.sectionTitle,
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppStrings.seeAll,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    AppStrings.isLtr ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================
// AUDIOBOOK SECTION (Horizontal List)
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
        _SectionHeader(title: title, onSeeAll: onSeeAll),
        SizedBox(
          height: AppDimensions.carouselHeightBook,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return _AudiobookCard(book: book);
            },
          ),
        ),
      ],
    );
  }
}

// ============================================
// AUDIOBOOK CARD
// ============================================

class _AudiobookCard extends StatelessWidget {
  final Map<String, dynamic> book;

  const _AudiobookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final coverUrl = book['cover_url'] as String?;
    final title = book['title_fa'] as String? ?? book['title_en'] as String? ?? '';
    final author = book['author_fa'] as String? ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => AudiobookDetailScreen(audiobookId: book['id'] as int),
        ),
      ),
      child: Container(
        width: 160,
        margin: const EdgeInsetsDirectional.only(start: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: coverUrl ?? '',
                width: 160,
                height: 240,
                fit: BoxFit.cover,
                placeholder: (_, __) => const ColoredBox(
                  color: AppColors.surface,
                  child: SizedBox(
                    width: 160,
                    height: 240,
                    child: Center(child: Icon(Icons.book, color: AppColors.textTertiary)),
                  ),
                ),
                errorWidget: (_, __, ___) => const ColoredBox(
                  color: AppColors.surface,
                  child: SizedBox(
                    width: 160,
                    height: 240,
                    child: Center(child: Icon(Icons.book, color: AppColors.textTertiary)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Title
            Text(
              AppStrings.localize(title),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            // Author
            if (author.isNotEmpty)
              Text(
                AppStrings.localize(author),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_pageController.hasClients && widget.banners.isNotEmpty) {
        final nextPage = (_currentPage + 1) % widget.banners.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: widget.banners.length,
            itemBuilder: (context, index) {
              final banner = widget.banners[index];
              return _BannerCard(banner: banner);
            },
          ),
        ),
        const SizedBox(height: 12),
        // Page indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.banners.length,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == index ? 20 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? AppColors.primary
                    : AppColors.textTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  final Map<String, dynamic> banner;

  const _BannerCard({required this.banner});

  @override
  Widget build(BuildContext context) {
    final imageUrl = banner['image_url'] as String?;
    final linkType = banner['link_type'] as String?;
    final linkId = banner['link_id'] as int?;

    return GestureDetector(
      onTap: () {
        if (linkType == 'audiobook' && linkId != null) {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => AudiobookDetailScreen(audiobookId: linkId),
            ),
          );
        } else if (linkType == 'shelf' && linkId != null) {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ShelfDetailScreen(shelfId: linkId),
            ),
          );
        }
        // Note: CategoryScreen requires categoryName which we don't have in banner data
        // For v1, we skip category links from banners
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CachedNetworkImage(
            imageUrl: imageUrl ?? '',
            fit: BoxFit.cover,
            placeholder: (_, __) => const ColoredBox(
              color: AppColors.surface,
              child: Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (_, __, ___) => const ColoredBox(
              color: AppColors.surface,
              child: Center(
                child: Icon(Icons.image_not_supported, size: 48),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================
// CATEGORIES SECTION
// ============================================

class _CategoriesSection extends StatelessWidget {
  final List<Map<String, dynamic>> categories;

  const _CategoriesSection({required this.categories});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: AppStrings.categories,
          onSeeAll: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const CategoriesListScreen(),
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return _CategoryChip(category: category);
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final Map<String, dynamic> category;

  const _CategoryChip({required this.category});

  @override
  Widget build(BuildContext context) {
    final name = category['name_fa'] as String? ?? '';
    final iconUrl = category['icon_url'] as String?;

    return GestureDetector(
      onTap: () {
        // Navigate to CategoriesListScreen - category filtering handled there
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const CategoriesListScreen(),
          ),
        );
      },
      child: Container(
        width: 90,
        margin: const EdgeInsetsDirectional.only(start: 12),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: iconUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: iconUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const Icon(
                          Icons.category,
                          color: AppColors.primary,
                        ),
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.category,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : const Icon(Icons.category, color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.localize(name),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSmall,
            ),
          ],
        ),
      ),
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
    final title = shelf['title_fa'] as String? ?? shelf['title_en'] as String? ?? '';
    final items = (shelf['shelf_items'] as List<dynamic>?) ?? [];

    if (items.isEmpty) return const SizedBox.shrink();

    // Extract audiobooks from shelf items
    final books = items
        .where((item) => item['audiobook'] != null)
        .map((item) => item['audiobook'] as Map<String, dynamic>)
        .toList();

    if (books.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: AppStrings.localize(title),
          onSeeAll: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ShelfDetailScreen(shelfId: shelf['id'] as int),
            ),
          ),
        ),
        SizedBox(
          height: AppDimensions.carouselHeightBook,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              // Promo shelves are mixed content - show badges
              return _PromoShelfCard(book: book);
            },
          ),
        ),
      ],
    );
  }
}

class _PromoShelfCard extends StatelessWidget {
  final Map<String, dynamic> book;

  const _PromoShelfCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final coverUrl = book['cover_url'] as String?;
    final title = book['title_fa'] as String? ?? book['title_en'] as String? ?? '';
    final author = book['author_fa'] as String? ?? '';
    final isMusic = book['is_music'] == true;
    final isPodcast = book['is_podcast'] == true;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => AudiobookDetailScreen(audiobookId: book['id'] as int),
        ),
      ),
      child: Container(
        width: 160,
        margin: const EdgeInsetsDirectional.only(start: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image with badge
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: coverUrl ?? '',
                    width: 160,
                    height: 240,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const ColoredBox(
                      color: AppColors.surface,
                      child: SizedBox(
                        width: 160,
                        height: 240,
                        child: Center(child: Icon(Icons.book, color: AppColors.textTertiary)),
                      ),
                    ),
                    errorWidget: (_, __, ___) => const ColoredBox(
                      color: AppColors.surface,
                      child: SizedBox(
                        width: 160,
                        height: 240,
                        child: Center(child: Icon(Icons.book, color: AppColors.textTertiary)),
                      ),
                    ),
                  ),
                  // Content type badge for mixed promo shelf
                  Positioned(
                    top: 8,
                    right: 8,
                    child: ContentTypeBadge(
                      isMusic: isMusic,
                      isPodcast: isPodcast,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Title
            Text(
              AppStrings.localize(title),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            // Author
            if (author.isNotEmpty)
              Text(
                AppStrings.localize(author),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// SKELETONS & ERROR STATES
// ============================================

class _BannerSkeleton extends StatelessWidget {
  const _BannerSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Container(
            width: 120,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        SizedBox(
          height: AppDimensions.carouselHeightBook,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 4,
            itemBuilder: (context, index) {
              return Container(
                width: 160,
                margin: const EdgeInsetsDirectional.only(start: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 160,
                      height: 240,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 100,
                      height: 16,
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

class _CategoriesSkeleton extends StatelessWidget {
  const _CategoriesSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Container(
            width: 100,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 5,
            itemBuilder: (context, index) {
              return Container(
                width: 90,
                margin: const EdgeInsetsDirectional.only(start: 12),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 70,
                      height: 14,
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

class _SectionError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _SectionError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            message,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: Text(AppStrings.retry),
          ),
        ],
      ),
    );
  }
}
