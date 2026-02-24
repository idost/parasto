import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:myna/theme/app_theme.dart';

/// Base shimmer configuration
class _ShimmerConfig {
  static const baseColor = AppColors.surface;
  static const highlightColor = AppColors.surfaceLight;
  static const duration = Duration(milliseconds: 1500);
}

/// Generic shimmer wrapper
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _ShimmerConfig.baseColor,
      highlightColor: _ShimmerConfig.highlightColor,
      period: _ShimmerConfig.duration,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _ShimmerConfig.baseColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Skeleton for horizontal book card list (home screen sections)
class BookCardListSkeleton extends StatelessWidget {
  final int itemCount;

  const BookCardListSkeleton({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppDimensions.carouselHeightBook,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, index) => const _BookCardSkeleton(),
      ),
    );
  }
}

class _BookCardSkeleton extends StatelessWidget {
  const _BookCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _ShimmerConfig.baseColor,
      highlightColor: _ShimmerConfig.highlightColor,
      period: _ShimmerConfig.duration,
      child: Container(
        width: 160,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 240,
              width: 160,
              decoration: BoxDecoration(
                color: _ShimmerConfig.baseColor,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 14,
              width: 100,
              decoration: BoxDecoration(
                color: _ShimmerConfig.baseColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 12,
              width: 60,
              decoration: BoxDecoration(
                color: _ShimmerConfig.baseColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for category chips
class CategoryChipsSkeleton extends StatelessWidget {
  final int itemCount;

  const CategoryChipsSkeleton({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, index) => Shimmer.fromColors(
          baseColor: _ShimmerConfig.baseColor,
          highlightColor: _ShimmerConfig.highlightColor,
          period: _ShimmerConfig.duration,
          child: Container(
            width: 80 + (index % 3) * 20.0, // Varying widths
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: _ShimmerConfig.baseColor,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton for grid of book cards (category screen)
class BookGridSkeleton extends StatelessWidget {
  final int itemCount;

  const BookGridSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.58,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => const _GridBookSkeleton(),
    );
  }
}

class _GridBookSkeleton extends StatelessWidget {
  const _GridBookSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _ShimmerConfig.baseColor,
      highlightColor: _ShimmerConfig.highlightColor,
      period: _ShimmerConfig.duration,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _ShimmerConfig.baseColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: const BoxDecoration(
                  color: _ShimmerConfig.baseColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _ShimmerConfig.highlightColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 12,
                      width: 80,
                      decoration: BoxDecoration(
                        color: _ShimmerConfig.highlightColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Container(
                          height: 12,
                          width: 40,
                          decoration: BoxDecoration(
                            color: _ShimmerConfig.highlightColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          height: 16,
                          width: 40,
                          decoration: BoxDecoration(
                            color: _ShimmerConfig.highlightColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for search result list
class SearchResultSkeleton extends StatelessWidget {
  final int itemCount;

  const SearchResultSkeleton({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      itemBuilder: (context, index) => const _SearchItemSkeleton(),
    );
  }
}

class _SearchItemSkeleton extends StatelessWidget {
  const _SearchItemSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _ShimmerConfig.baseColor,
      highlightColor: _ShimmerConfig.highlightColor,
      period: _ShimmerConfig.duration,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _ShimmerConfig.baseColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 60,
              decoration: BoxDecoration(
                color: _ShimmerConfig.highlightColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _ShimmerConfig.highlightColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 12,
                    width: 100,
                    decoration: BoxDecoration(
                      color: _ShimmerConfig.highlightColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 14,
              width: 60,
              decoration: BoxDecoration(
                color: _ShimmerConfig.highlightColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for library screen (owned books list)
class LibraryListSkeleton extends StatelessWidget {
  final int itemCount;

  const LibraryListSkeleton({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      itemBuilder: (context, index) => const _LibraryItemSkeleton(),
    );
  }
}

class _LibraryItemSkeleton extends StatelessWidget {
  const _LibraryItemSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _ShimmerConfig.baseColor,
      highlightColor: _ShimmerConfig.highlightColor,
      period: _ShimmerConfig.duration,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _ShimmerConfig.baseColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 100,
              decoration: BoxDecoration(
                color: _ShimmerConfig.highlightColor,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _ShimmerConfig.highlightColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 120,
                    decoration: BoxDecoration(
                      color: _ShimmerConfig.highlightColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 8,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _ShimmerConfig.highlightColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        height: 12,
                        width: 60,
                        decoration: BoxDecoration(
                          color: _ShimmerConfig.highlightColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        height: 28,
                        width: 60,
                        decoration: BoxDecoration(
                          color: _ShimmerConfig.highlightColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section header skeleton
class SectionHeaderSkeleton extends StatelessWidget {
  const SectionHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _ShimmerConfig.baseColor,
      highlightColor: _ShimmerConfig.highlightColor,
      period: _ShimmerConfig.duration,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        child: Container(
          height: 20,
          width: 100,
          decoration: BoxDecoration(
            color: _ShimmerConfig.baseColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

/// Skeleton for audiobook detail screen
class AudiobookDetailSkeleton extends StatelessWidget {
  const AudiobookDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _ShimmerConfig.baseColor,
      highlightColor: _ShimmerConfig.highlightColor,
      period: _ShimmerConfig.duration,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image area
            Container(
              height: 280,
              width: double.infinity,
              color: _ShimmerConfig.baseColor,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Container(
                    height: 24,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _ShimmerConfig.highlightColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Author
                  Container(
                    height: 16,
                    width: 150,
                    decoration: BoxDecoration(
                      color: _ShimmerConfig.highlightColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Narrator
                  Container(
                    height: 16,
                    width: 120,
                    decoration: BoxDecoration(
                      color: _ShimmerConfig.highlightColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Rating and stats row
                  Row(
                    children: [
                      Container(
                        height: 20,
                        width: 80,
                        decoration: BoxDecoration(
                          color: _ShimmerConfig.highlightColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        height: 20,
                        width: 60,
                        decoration: BoxDecoration(
                          color: _ShimmerConfig.highlightColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        height: 20,
                        width: 70,
                        decoration: BoxDecoration(
                          color: _ShimmerConfig.highlightColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Action buttons row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: _ShimmerConfig.highlightColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          color: _ShimmerConfig.highlightColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Description section header
                  Container(
                    height: 18,
                    width: 80,
                    decoration: BoxDecoration(
                      color: _ShimmerConfig.highlightColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Description lines
                  ...List.generate(4, (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _ShimmerConfig.highlightColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  )),
                  const SizedBox(height: 24),
                  // Chapters section header
                  Container(
                    height: 18,
                    width: 100,
                    decoration: BoxDecoration(
                      color: _ShimmerConfig.highlightColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Chapter items
                  ...List.generate(3, (index) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _ShimmerConfig.baseColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _ShimmerConfig.highlightColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 14,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: _ShimmerConfig.highlightColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                height: 12,
                                width: 60,
                                decoration: BoxDecoration(
                                  color: _ShimmerConfig.highlightColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for profile screen
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _ShimmerConfig.baseColor,
      highlightColor: _ShimmerConfig.highlightColor,
      period: _ShimmerConfig.duration,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Avatar
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: _ShimmerConfig.baseColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 16),
            // Name
            Container(
              height: 22,
              width: 140,
              decoration: BoxDecoration(
                color: _ShimmerConfig.highlightColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            // Email
            Container(
              height: 14,
              width: 180,
              decoration: BoxDecoration(
                color: _ShimmerConfig.highlightColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 32),
            // Stats cards row
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: _ShimmerConfig.baseColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: _ShimmerConfig.baseColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: _ShimmerConfig.baseColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Menu items
            ...List.generate(5, (index) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              height: 56,
              decoration: BoxDecoration(
                color: _ShimmerConfig.baseColor,
                borderRadius: BorderRadius.circular(12),
              ),
            )),
          ],
        ),
      ),
    );
  }
}
