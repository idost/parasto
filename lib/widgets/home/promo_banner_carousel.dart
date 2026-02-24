import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/utils/app_strings.dart';

/// Callback type for banner tap events.
typedef OnBannerTap = void Function(Map<String, dynamic> banner);

/// Auto-scrolling promotional banner carousel.
/// Extracted from home_screen.dart for better maintainability.
class PromoBannerCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> banners;
  final OnBannerTap? onBannerTap;
  final double height;
  final Duration autoScrollDuration;
  final Duration resumeDelay;

  const PromoBannerCarousel({
    super.key,
    required this.banners,
    this.onBannerTap,
    this.height = 180,
    this.autoScrollDuration = const Duration(seconds: 5),
    this.resumeDelay = const Duration(seconds: 3),
  });

  @override
  State<PromoBannerCarousel> createState() => _PromoBannerCarouselState();
}

class _PromoBannerCarouselState extends State<PromoBannerCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _autoScrollTimer;
  bool _userInteracting = false;

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
    _autoScrollTimer = Timer.periodic(widget.autoScrollDuration, (_) {
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
    Future.delayed(widget.resumeDelay, () {
      if (mounted && !_userInteracting) {
        _startAutoScroll();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: GestureDetector(
            onPanDown: (_) => _onUserInteractionStart(),
            onPanEnd: (_) => _onUserInteractionEnd(),
            onPanCancel: _onUserInteractionEnd,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.banners.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) {
                final banner = widget.banners[index];
                return _BannerItem(
                  banner: banner,
                  onTap: widget.onBannerTap != null ? () => widget.onBannerTap!(banner) : null,
                  showPageIndicators: widget.banners.length > 1,
                  currentPage: _currentPage,
                  totalPages: widget.banners.length,
                  pageIndex: index,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _BannerItem extends StatelessWidget {
  final Map<String, dynamic> banner;
  final VoidCallback? onTap;
  final bool showPageIndicators;
  final int currentPage;
  final int totalPages;
  final int pageIndex;

  const _BannerItem({
    required this.banner,
    this.onTap,
    required this.showPageIndicators,
    required this.currentPage,
    required this.totalPages,
    required this.pageIndex,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Image
              CachedNetworkImage(
                imageUrl: banner['image_url'] as String,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                memCacheWidth: 800, // Banner max ~400px wide * 2x DPR
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
                    child: Icon(Icons.campaign_rounded, size: 48, color: Colors.white),
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
                      Colors.black.withValues(alpha: 0.8),
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
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Page indicators inside banner with blur
              if (showPageIndicators)
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        color: Colors.black.withValues(alpha: 0.4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            totalPages,
                            (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: currentPage == i ? 18 : 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: currentPage == i
                                    ? AppColors.primary
                                    : Colors.white.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton loader for the banner carousel.
class BannerSkeleton extends StatelessWidget {
  final double height;

  const BannerSkeleton({super.key, this.height = 180});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
