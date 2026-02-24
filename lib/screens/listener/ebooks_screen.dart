import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/providers/ebook_providers.dart';
import 'package:myna/widgets/ebook_card.dart';
import 'package:myna/screens/ebook_detail_screen.dart';
import 'package:myna/screens/listener/search_screen.dart';
import 'package:myna/utils/app_strings.dart';

/// Main ebooks screen showing featured, popular, and new ebooks
class EbooksScreen extends ConsumerStatefulWidget {
  const EbooksScreen({super.key});

  @override
  ConsumerState<EbooksScreen> createState() => _EbooksScreenState();
}

class _EbooksScreenState extends ConsumerState<EbooksScreen> {
  @override
  Widget build(BuildContext context) {
    final featuredAsync = ref.watch(ebookFeaturedProvider);
    final newReleasesAsync = ref.watch(ebookNewReleasesProvider);
    final popularAsync = ref.watch(ebookPopularProvider);
    final continueReadingAsync = ref.watch(ebookContinueReadingProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ebookFeaturedProvider);
          ref.invalidate(ebookNewReleasesProvider);
          ref.invalidate(ebookPopularProvider);
          ref.invalidate(ebookContinueReadingProvider);
        },
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          slivers: [
            // App bar
            SliverAppBar(
              floating: true,
              backgroundColor: AppColors.background,
              title: const Text(
                'کتاب‌های الکترونیکی',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                // UI-SEARCH-001: All search entry points open global SearchScreen
                IconButton(
                  icon: const Icon(Icons.search_rounded, color: AppColors.textPrimary, size: 28),
                  tooltip: AppStrings.search,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
                    );
                  },
                ),
              ],
            ),

            // Content
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Continue Reading Section
                  continueReadingAsync.when(
                    data: (ebooks) {
                      if (ebooks.isEmpty) return const SizedBox.shrink();
                      return Column(
                        children: [
                          EbookCardList(
                            title: 'ادامه',
                            ebooks: ebooks,
                            showProgress: true,
                            onEbookTap: _navigateToDetail,
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  // Featured Section
                  featuredAsync.when(
                    data: (ebooks) {
                      if (ebooks.isEmpty) return const SizedBox.shrink();
                      return Column(
                        children: [
                          // Featured hero card (first item)
                          if (ebooks.isNotEmpty)
                            FeaturedEbookCard(
                              ebook: ebooks.first,
                              onTap: () => _navigateToDetail(ebooks.first),
                            ),
                          const SizedBox(height: 24),
                          // Rest as horizontal list
                          if (ebooks.length > 1)
                            EbookCardList(
                              title: 'پیشنهاد شده',
                              ebooks: ebooks.skip(1).toList(),
                              onEbookTap: _navigateToDetail,
                            ),
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                    loading: _buildLoadingSection,
                    error: (error, _) => _buildErrorWidget('خطا در بارگذاری'),
                  ),

                  // New Releases Section
                  newReleasesAsync.when(
                    data: (ebooks) {
                      if (ebooks.isEmpty) return const SizedBox.shrink();
                      return Column(
                        children: [
                          EbookCardList(
                            title: 'تازه',
                            ebooks: ebooks,
                            onEbookTap: _navigateToDetail,
                            onSeeAllTap: () {
                              // Navigate to search with ebook filter applied
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                    loading: _buildLoadingSection,
                    error: (error, _) => const SizedBox.shrink(),
                  ),

                  // Popular Section
                  popularAsync.when(
                    data: (ebooks) {
                      if (ebooks.isEmpty) return const SizedBox.shrink();
                      return Column(
                        children: [
                          EbookCardList(
                            title: 'پرخواننده',
                            ebooks: ebooks,
                            onEbookTap: _navigateToDetail,
                            onSeeAllTap: () {
                              // Navigate to search with ebook filter applied
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                    loading: _buildLoadingSection,
                    error: (error, _) => const SizedBox.shrink(),
                  ),

                  // Bottom padding for mini player
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 260,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsetsDirectional.only(start: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 140,
                      height: 190,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 120,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetail(Map<String, dynamic> ebook) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => EbookDetailScreen(ebook: ebook),
      ),
    );
  }
}
