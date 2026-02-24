import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:myna/theme/app_theme.dart';

/// Optimized cover image widget with automatic resolution optimization
///
/// PERFORMANCE OPTIMIZATIONS:
/// - Automatically resizes images based on display size
/// - Limits memory cache to prevent excessive RAM usage
/// - Adds Supabase image transformation for bandwidth optimization
/// - Provides consistent placeholder and error states
///
/// Usage:
/// ```dart
/// OptimizedCoverImage(
///   coverUrl: audiobook.coverUrl,
///   width: 200,
///   height: 200,
/// )
/// ```
class OptimizedCoverImage extends StatelessWidget {
  final String coverUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const OptimizedCoverImage({
    required this.coverUrl,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Add Supabase image transformation for bandwidth optimization
    final optimizedUrl = _getOptimizedUrl(
      coverUrl,
      width.toInt(),
      height.toInt(),
    );

    final imageWidget = CachedNetworkImage(
      imageUrl: optimizedUrl,
      fit: fit,
      // PERFORMANCE: Limit decoded image size in memory
      memCacheWidth: (width * MediaQuery.of(context).devicePixelRatio).toInt(),
      memCacheHeight: (height * MediaQuery.of(context).devicePixelRatio).toInt(),
      placeholder: (_, __) => _buildPlaceholder(),
      errorWidget: (_, __, ___) => _buildErrorWidget(),
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 100),
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  /// Generates optimized image URL with Supabase transformations
  ///
  /// For Supabase storage URLs, adds query parameters to resize images
  /// server-side, reducing bandwidth and improving load times.
  String _getOptimizedUrl(String url, int targetWidth, int targetHeight) {
    if (!url.contains('supabase.co/storage')) {
      return url; // External URL, can't optimize
    }

    // Calculate optimal dimensions (2x for retina displays, but capped)
    final optimalWidth = (targetWidth * 2).clamp(200, 800);
    final optimalHeight = (targetHeight * 2).clamp(200, 800);

    // Add Supabase image transformation parameters
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}width=$optimalWidth&height=$optimalHeight&quality=85&resize=cover';
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: AppColors.surface,
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: width * 0.4,
          color: AppColors.textTertiary.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      color: AppColors.surface,
      child: Center(
        child: Icon(
          Icons.broken_image_rounded,
          size: width * 0.4,
          color: AppColors.error.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

/// Compact version for small thumbnails (list items, etc.)
class OptimizedThumbnail extends StatelessWidget {
  final String coverUrl;
  final double size;

  const OptimizedThumbnail({
    required this.coverUrl,
    this.size = 56,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return OptimizedCoverImage(
      coverUrl: coverUrl,
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(8),
    );
  }
}

/// Full-width responsive cover for detail screens
class OptimizedHeroCover extends StatelessWidget {
  final String coverUrl;
  final double aspectRatio;

  const OptimizedHeroCover({
    required this.coverUrl,
    this.aspectRatio = 1.0,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return OptimizedCoverImage(
      coverUrl: coverUrl,
      width: screenWidth,
      height: screenWidth / aspectRatio,
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(16),
      ),
    );
  }
}
