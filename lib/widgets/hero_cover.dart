import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:myna/theme/app_theme.dart';

/// Shared Hero cover widget for smooth list → detail transitions.
///
/// Wraps a [CachedNetworkImage] in a [Hero] with consistent clipping
/// so the cover image smoothly flies from card to detail screen.
///
/// Usage in card (source):
/// ```dart
/// HeroCover(
///   tag: 'cover_$id',
///   imageUrl: coverUrl,
///   width: 160, height: 240,
///   borderRadius: 12,
/// )
/// ```
///
/// Usage in detail screen (destination):
/// ```dart
/// HeroCover(
///   tag: 'cover_$id',
///   imageUrl: coverUrl,
///   width: coverWidth, height: coverHeight,
///   borderRadius: 16,
/// )
/// ```
class HeroCover extends StatelessWidget {
  final String tag;
  final String? imageUrl;
  final double width;
  final double height;
  final double borderRadius;
  final IconData placeholderIcon;
  final BoxFit fit;

  const HeroCover({
    super.key,
    required this.tag,
    this.imageUrl,
    required this.width,
    required this.height,
    this.borderRadius = 12,
    this.placeholderIcon = Icons.headphones_rounded,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: SizedBox(
          width: width,
          height: height,
          child: imageUrl != null
              ? CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: fit,
                  width: width,
                  height: height,
                  memCacheWidth: (width * 2).toInt(),
                  memCacheHeight: (height * 2).toInt(),
                  placeholder: (_, __) => _buildPlaceholder(),
                  errorWidget: (_, __, ___) => _buildPlaceholder(),
                )
              : _buildPlaceholder(),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return ColoredBox(
      color: AppColors.surface,
      child: Center(
        child: Icon(
          placeholderIcon,
          color: AppColors.textTertiary,
          size: 40,
        ),
      ),
    );
  }
}
