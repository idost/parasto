import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/screens/audiobook_detail_screen.dart';
import 'package:myna/screens/listener/search_screen.dart';
import 'package:myna/screens/listener/library_screen.dart' show ownedItemsWithProgressProvider, ContentType;
import 'package:myna/providers/home_providers.dart';
import 'package:myna/utils/app_strings.dart';

// ============================================
// PODCASTS SCREEN
// ============================================
//
// STRUCTURE (in order):
// 1. ادامه‌ی شنیدن پادکست (Continue Listening) - recently played podcasts
// 2. پادکست‌های جدید (New Podcasts) - is_podcast=true, newest first
// 3. پرشنونده‌ترین‌ها (Popular Podcasts) - is_podcast=true, by play_count
// 4. همه پادکست‌ها (All Podcasts) - grid of all podcasts
//
// DATABASE:
// - audiobooks.is_podcast: boolean to distinguish podcasts
// ============================================

/// Podcasts screen - shows podcast content (is_podcast = true)
/// This screen is displayed in the bottom navigation "پادکست‌ها" tab
class PodcastsScreen extends ConsumerStatefulWidget {
  const PodcastsScreen({super.key});

  @override
  ConsumerState<PodcastsScreen> createState() => _PodcastsScreenState();
}

class _PodcastsScreenState extends ConsumerState<PodcastsScreen> {
  @override
  Widget build(BuildContext context) {
    final ownedPodcastsAsync = ref.watch(ownedItemsWithProgressProvider(ContentType.podcasts));
    final newPodcastsAsync = ref.watch(homePodcastsProvider);
    final popularPodcastsAsync = ref.watch(podcastsPopularProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(homePodcastsProvider);
            ref.invalidate(podcastsPopularProvider);
            ref.invalidate(ownedItemsWithProgressProvider(ContentType.podcasts));
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
                title: Row(
                  children: [
                    const Icon(Icons.podcasts_rounded, color: AppColors.primary, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.podcasts,
                      style: const TextStyle(
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

              // Content
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // پادکست‌های من (My Podcasts) - owned podcasts
                    ownedPodcastsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (items) => items.isEmpty
                          ? const SizedBox.shrink()
                          : _PodcastSection(
                              title: AppStrings.myPodcasts,
                              icon: Icons.headphones_rounded,
                              podcasts: items,
                              showProgress: true,
                            ),
                    ),

                    // پادکست‌های جدید (New Podcasts)
                    newPodcastsAsync.when(
                      loading: () => _buildSectionSkeleton(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (items) => items.isEmpty
                          ? const SizedBox.shrink()
                          : _PodcastSection(
                              title: AppStrings.newPodcasts,
                              icon: Icons.new_releases_rounded,
                              podcasts: items,
                            ),
                    ),

                    // پرشنونده‌ترین‌ها (Popular Podcasts)
                    popularPodcastsAsync.when(
                      loading: () => _buildSectionSkeleton(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (items) => items.isEmpty
                          ? const SizedBox.shrink()
                          : _PodcastSection(
                              title: AppStrings.popularPodcasts,
                              icon: Icons.trending_up_rounded,
                              podcasts: items,
                            ),
                    ),

                    // Empty state if no podcasts available
                    newPodcastsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => _buildEmptyState(),
                      data: (items) => items.isEmpty ? _buildEmptyState() : const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 100), // Bottom padding for mini player
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              itemBuilder: (_, __) => Container(
                width: 140,
                margin: const EdgeInsetsDirectional.only(start: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.podcasts_rounded,
              size: 80,
              color: AppColors.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'هنوز پادکستی موجود نیست',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'به زودی پادکست‌های جدید اضافه می‌شوند',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal podcast section with title and scrollable cards
class _PodcastSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Map<String, dynamic>> podcasts;
  final bool showProgress;

  const _PodcastSection({
    required this.title,
    required this.icon,
    required this.podcasts,
    this.showProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        // Horizontal scrolling cards
        SizedBox(
          height: showProgress ? 200 : 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: podcasts.length,
            itemBuilder: (context, index) {
              final podcast = podcasts[index];
              return Padding(
                padding: const EdgeInsetsDirectional.only(start: 12),
                child: _PodcastCard(
                  podcast: podcast,
                  showProgress: showProgress,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Individual podcast card widget
class _PodcastCard extends StatelessWidget {
  final Map<String, dynamic> podcast;
  final bool showProgress;

  const _PodcastCard({
    required this.podcast,
    this.showProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    final title = (podcast['title_fa'] as String?) ?? '';
    // For podcasts, author_fa contains the host name (میزبان)
    final host = (podcast['author_fa'] as String?) ?? '';
    final coverUrl = podcast['cover_url'] as String?;
    final progress = podcast['progress'] as double? ?? 0.0;
    final isFree = podcast['is_free'] == true;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => AudiobookDetailScreen(audiobookId: podcast['id'] as int),
          ),
        );
      },
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image with podcast badge
            Stack(
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
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
                              child: const Center(
                                child: Icon(Icons.podcasts_rounded, color: AppColors.textTertiary),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: AppColors.surface,
                              child: const Center(
                                child: Icon(Icons.podcasts_rounded, color: AppColors.textTertiary),
                              ),
                            ),
                          )
                        : Container(
                            color: AppColors.surface,
                            child: const Center(
                              child: Icon(Icons.podcasts_rounded, color: AppColors.textTertiary, size: 40),
                            ),
                          ),
                  ),
                ),
                // Podcast badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.podcasts_rounded, color: AppColors.textOnPrimary, size: 10),
                        SizedBox(width: 2),
                        Text(
                          'پادکست',
                          style: TextStyle(
                            color: AppColors.textOnPrimary,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Free badge
                if (isFree)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'رایگان',
                        style: TextStyle(
                          color: AppColors.textOnPrimary,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            // Host (میزبان)
            if (host.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                host,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            // Progress bar
            if (showProgress && progress > 0) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.surfaceLight,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
