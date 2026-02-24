import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/screens/audiobook_detail_screen.dart';
import 'package:myna/screens/listener/library_screen.dart';
import 'package:myna/screens/player/player_screen.dart';
import 'package:myna/providers/home_providers.dart';
import 'package:myna/providers/audio_provider.dart';
import 'package:myna/utils/app_strings.dart';
import 'package:myna/utils/farsi_utils.dart';

// ============================================
// AUDIOBOOKS SCREEN (NAV-RESTRUCTURE-01)
// ============================================
//
// PURPOSE: Listening hub tab (کتاب‌های صوتی)
// Part of the 5-tab navigation structure:
//   0. Home (خانه) - discover / promo
//   1. Bookstore (کتاب‌فروشی) - full catalog
//   2. Audiobooks (کتاب‌های صوتی) - listening hub (THIS SCREEN)
//   3. Library (کتابخانه) - my stuff
//   4. Search (جستجو) - global search
//
// V1 STRUCTURE (temporary - reuses existing providers):
// 1. ادامه‌ی شنیدن (Continue Listening) - hero card for most recent
// 2. کتاب‌های صوتی پیشنهادی (Featured Audiobooks)
// 3. تازه‌ها (New Audiobooks)
// 4. پرشنونده‌ترین‌ها (Popular Audiobooks)
//
// This tab focuses on AUDIOBOOK content only.
// Podcasts and Music have their own dedicated tabs.
//
// TODO(NAV-RESTRUCTURE-02): Enhance with:
// - Filter chips (audiobooks, podcasts, music)
// - "Now Playing" section if something is playing
// - Sleep timer shortcut
// - Playback speed preset
// ============================================

class AudiobooksScreen extends ConsumerWidget {
  const AudiobooksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only watch hasAudio — avoids rebuilds on position/duration ticks (~10 Hz)
    // _NowPlayingHero independently watches its own needed fields
    final hasAudio = ref.watch(audioProvider.select((s) => s.hasAudio));

    // Listening-focused providers
    final recentlyPlayedAsync = ref.watch(homeRecentlyPlayedProvider);
    final ownedBooksAsync = ref.watch(ownedItemsWithProgressProvider(ContentType.books));

    return Directionality(
      textDirection: AppStrings.isLtr ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(homeRecentlyPlayedProvider);
            ref.invalidate(ownedItemsWithProgressProvider(ContentType.books));
          },
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // App Bar
              SliverAppBar(
                floating: true,
                automaticallyImplyLeading: false,
                backgroundColor: AppColors.background,
                elevation: 0,
                title: Row(
                  children: [
                    const Icon(Icons.headphones_rounded, color: AppColors.primary, size: 28),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      AppStrings.audiobooks,
                      style: AppTypography.heroTitle.copyWith(fontSize: 24),
                    ),
                  ],
                ),
                centerTitle: false,
              ),

              // Content
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.sm),

                    // === NOW PLAYING ===
                    // Show current playback if audio is active
                    if (hasAudio)
                      _NowPlayingHero(ref: ref),

                    // === CONTINUE LISTENING ===
                    // All in-progress books (not just most recent)
                    ownedBooksAsync.when(
                      loading: () => const _SectionSkeleton(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (items) {
                        final inProgress = items.where((item) {
                          final progress = item['progress'] as Map<String, dynamic>?;
                          if (progress == null) return false;
                          final pct = (progress['completion_percentage'] as int?) ?? 0;
                          final done = progress['is_completed'] == true;
                          return pct > 0 && !done;
                        }).toList();

                        if (inProgress.isEmpty) return const SizedBox.shrink();

                        return _InProgressSection(items: inProgress, ref: ref);
                      },
                    ),

                    // === RECENTLY PLAYED ===
                    recentlyPlayedAsync.when(
                      loading: () => const _SectionSkeleton(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (books) => books.isEmpty
                          ? const SizedBox.shrink()
                          : _RecentlyPlayedSection(books: books),
                    ),

                    // === EMPTY STATE ===
                    // Show when nothing is playing and no listening history
                    Builder(
                      builder: (context) {
                        final hasPlaying = hasAudio;
                        final hasRecent = recentlyPlayedAsync.hasValue &&
                            (recentlyPlayedAsync.value?.isNotEmpty ?? false);
                        final hasInProgress = ownedBooksAsync.hasValue &&
                            (ownedBooksAsync.value?.any((item) {
                              final p = item['progress'] as Map<String, dynamic>?;
                              return p != null &&
                                  ((p['completion_percentage'] as int?) ?? 0) > 0 &&
                                  p['is_completed'] != true;
                            }) ?? false);

                        if (!hasPlaying && !hasRecent && !hasInProgress &&
                            recentlyPlayedAsync.hasValue && ownedBooksAsync.hasValue) {
                          return const _EmptyState();
                        }
                        return const SizedBox.shrink();
                      },
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
// NOW PLAYING HERO
// ============================================

class _NowPlayingHero extends StatelessWidget {
  final WidgetRef ref;

  const _NowPlayingHero({required this.ref});

  @override
  Widget build(BuildContext context) {
    // Select only the fields needed — avoids rebuilds on position/duration ticks
    final audio = ref.watch(
      audioProvider.select(
        (s) => (
          audiobook: s.audiobook,
          chapters: s.chapters,
          currentChapterIndex: s.currentChapterIndex,
          isPlaying: s.isPlaying,
        ),
      ),
    );
    final audiobook = audio.audiobook;
    if (audiobook == null) return const SizedBox.shrink();
    final coverUrl = audiobook['cover_url'] as String?;
    final title = (audiobook['title_fa'] as String?) ?? (audiobook['title_en'] as String?) ?? '';
    final chapters = audio.chapters;
    final currentChapter = audio.currentChapterIndex < chapters.length
        ? chapters[audio.currentChapterIndex]
        : null;
    final chapterTitle = (currentChapter?['title_fa'] as String?) ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.2),
            AppColors.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Text(
            'در حال پخش',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              // Large cover
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: CachedNetworkImage(
                  imageUrl: coverUrl ?? '',
                  width: 80,
                  height: 110,
                  fit: BoxFit.cover,
                  memCacheWidth: 160, // 80 * 2x DPR
                  memCacheHeight: 220, // 110 * 2x DPR
                  placeholder: (_, __) => Container(
                    width: 80, height: 110,
                    color: AppColors.surface,
                    child: const Icon(Icons.headphones_rounded, color: AppColors.textTertiary),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 80, height: 110,
                    color: AppColors.surface,
                    child: const Icon(Icons.headphones_rounded, color: AppColors.textTertiary),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              // Title + chapter + controls
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.localize(title),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (chapterTitle.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        AppStrings.localize(chapterTitle),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    // Play/Pause button
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            ref.read(audioProvider.notifier).togglePlayPause();
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              audio.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: AppColors.textOnPrimary,
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        // Open player
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => PlayerScreen(
                                  audiobook: audiobook,
                                  chapters: chapters,
                                  initialChapterIndex: audio.currentChapterIndex,
                                  playbackAlreadyStarted: true,
                                ),
                              ),
                            );
                          },
                          child: Text(
                            'باز کردن پلیر',
                            style: AppTypography.labelMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================
// IN-PROGRESS SECTION (all books being listened to)
// ============================================

class _InProgressSection extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final WidgetRef ref;

  const _InProgressSection({required this.items, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'ادامه گوش دادن',
          icon: Icons.play_circle_outline_rounded,
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final coverUrl = item['cover_url'] as String?;
              final title = (item['title_fa'] as String?) ?? '';
              final progress = item['progress'] as Map<String, dynamic>?;
              final pct = (progress?['completion_percentage'] as int?) ?? 0;
              final chapters = item['chapters'] as List<dynamic>? ?? [];
              final sortedChapters = List<Map<String, dynamic>>.from(chapters)
                ..sort((a, b) => ((a['chapter_index'] as int?) ?? 0)
                    .compareTo((b['chapter_index'] as int?) ?? 0));
              final currentChapterIndex = (progress?['current_chapter_index'] as int?) ?? 0;
              final positionSeconds = (progress?['position_seconds'] as int?) ?? 0;

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
                  margin: EdgeInsetsDirectional.only(start: index > 0 ? AppSpacing.md : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cover with progress overlay + play button
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            child: CachedNetworkImage(
                              imageUrl: coverUrl ?? '',
                              width: 160,
                              height: 160,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                width: 160, height: 160,
                                color: AppColors.surface,
                              ),
                              errorWidget: (_, __, ___) => Container(
                                width: 160, height: 160,
                                color: AppColors.surface,
                                child: const Icon(Icons.headphones, color: AppColors.textTertiary),
                              ),
                            ),
                          ),
                          // Progress bar at bottom
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(AppRadius.sm),
                              ),
                              child: LinearProgressIndicator(
                                value: pct / 100,
                                backgroundColor: Colors.black.withValues(alpha: 0.4),
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                                minHeight: 4,
                              ),
                            ),
                          ),
                          // Play button
                          Positioned(
                            bottom: AppSpacing.sm,
                            left: AppSpacing.sm,
                            child: GestureDetector(
                              onTap: sortedChapters.isEmpty
                                  ? null
                                  : () {
                                      ref.read(audioProvider.notifier).play(
                                        audiobook: item,
                                        chapters: sortedChapters,
                                        chapterIndex: currentChapterIndex,
                                        seekTo: positionSeconds,
                                        isOwned: true,
                                      );
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) => PlayerScreen(
                                            audiobook: item,
                                            chapters: sortedChapters,
                                            initialChapterIndex: currentChapterIndex,
                                            playbackAlreadyStarted: true,
                                          ),
                                        ),
                                      );
                                    },
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: AppColors.textOnPrimary,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        AppStrings.localize(title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${FarsiUtils.toFarsiDigits(pct)}٪',
                        style: AppTypography.labelSmall.copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================
// RECENTLY PLAYED SECTION (vertical list)
// ============================================

class _RecentlyPlayedSection extends StatelessWidget {
  final List<Map<String, dynamic>> books;

  const _RecentlyPlayedSection({required this.books});

  @override
  Widget build(BuildContext context) {
    final displayBooks = books.length > 10 ? books.sublist(0, 10) : books;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'اخیراً شنیده شده',
          icon: Icons.history_rounded,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: displayBooks.map((book) {
              final coverUrl = book['cover_url'] as String?;
              final title = (book['title_fa'] as String?) ?? '';
              final author = (book['author_fa'] as String?) ?? '';
              final progressMap = book['progress'] as Map<String, dynamic>?;
              final pct = ((progressMap?['completion_percentage'] as num?)?.toInt()) ?? 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => AudiobookDetailScreen(audiobookId: book['id'] as int),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            child: CachedNetworkImage(
                              imageUrl: coverUrl ?? '',
                              width: 48,
                              height: 64,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                width: 48, height: 64, color: AppColors.surfaceLight,
                              ),
                              errorWidget: (_, __, ___) => Container(
                                width: 48, height: 64, color: AppColors.surfaceLight,
                                child: const Icon(Icons.headphones, size: 18, color: AppColors.textTertiary),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.localize(title),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                                ),
                                if (author.isNotEmpty)
                                  Text(
                                    AppStrings.localize(author),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                                  ),
                              ],
                            ),
                          ),
                          if (pct > 0)
                            Text(
                              '${FarsiUtils.toFarsiDigits(pct)}٪',
                              style: AppTypography.labelSmall.copyWith(color: AppColors.primary),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ============================================
// SECTION HEADER
// ============================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  final IconData? icon;

  const _SectionHeader({
    required this.title,
    this.onSeeAll,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: AppTypography.sectionTitle,
              ),
            ],
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
// SKELETONS & ERROR STATES
// ============================================

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
            width: 160,
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
                      height: 240, // 2:3 aspect ratio for book covers
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

// ============================================
// EMPTY STATE
// ============================================

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.headphones_rounded,
            size: 64,
            color: AppColors.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'کتاب صوتی یافت نشد', // No audiobooks found
            style: AppTypography.headlineSmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'کتاب‌های صوتی اینجا نمایش داده می‌شوند',
            // Audiobooks will appear here
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
