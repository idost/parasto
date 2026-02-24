import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/widgets/tap_scale.dart';

/// Base widget for content cards (audiobooks, music, ebooks, podcasts)
/// Provides consistent styling for cover images with shadow, badges, and text layout
///
/// Usage:
/// ```dart
/// ContentCardBase(
///   coverUrl: book['cover_url'],
///   width: 140,
///   coverHeight: AppDimensions.cardCoverHeight, // 210 for 2:3 books
///   title: book['title_fa'],
///   subtitle: book['author_fa'],
///   onTap: () => Navigator.push(...),
///   badge: ContentTypeBadge.fromAudiobook(book),
///   bottomWidget: _buildPriceBadge(price),
/// )
/// ```
class ContentCardBase extends StatelessWidget {
  /// Cover image URL (nullable - shows placeholder if null)
  final String? coverUrl;

  /// Card width (default: AppDimensions.cardWidth = 140)
  final double width;

  /// Cover image height (use AppDimensions.cardCoverHeight for 2:3 books,
  /// AppDimensions.musicCardCoverHeight for 1:1 music)
  final double coverHeight;

  /// Title text (first line, up to 2 lines)
  final String title;

  /// Subtitle text (second line, single line, e.g., author/narrator)
  final String? subtitle;

  /// Callback when card is tapped
  final VoidCallback? onTap;

  /// Badge widget to show on top-right of cover
  final Widget? badge;

  /// Secondary badge widget (e.g., completion indicator on top-left)
  final Widget? secondaryBadge;

  /// Widget to show at the bottom of the card (e.g., price badge, progress bar)
  final Widget? bottomWidget;

  /// Micro label widget at bottom-start of cover (e.g., ContentTypeMicroLabel)
  final Widget? microLabel;

  /// Placeholder icon when cover is missing
  final IconData placeholderIcon;

  /// Start margin between cards in horizontal lists (RTL-safe)
  final double startMargin;

  /// Border radius for cover image
  final double borderRadius;

  /// Hero tag for cover image transitions (e.g., 'cover_$id')
  /// When set, the cover image will animate smoothly to detail screens.
  final String? heroTag;

  const ContentCardBase({
    super.key,
    this.coverUrl,
    this.width = AppDimensions.cardWidth,
    required this.coverHeight,
    required this.title,
    this.subtitle,
    this.onTap,
    this.badge,
    this.secondaryBadge,
    this.bottomWidget,
    this.microLabel,
    this.placeholderIcon = Icons.headphones_rounded,
    this.startMargin = 12,
    this.borderRadius = 12,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: TapScale(
      onTap: onTap,
      child: Container(
        width: width,
        margin: EdgeInsetsDirectional.only(start: startMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cover with shadow
            _buildCover(),
            const SizedBox(height: 8),

            // Title (fixed height container for 2 lines)
            SizedBox(
              height: 36,
              child: Text(
                title,
                style: AppTypography.cardTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Subtitle (if provided)
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 2),
              SizedBox(
                height: 18,
                child: Text(
                  subtitle!,
                  style: AppTypography.cardSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],

            // Bottom widget (if provided)
            if (bottomWidget != null) ...[
              const SizedBox(height: 6),
              bottomWidget!,
            ],
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildCover() {
    Widget coverImage = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: coverUrl != null
          ? CachedNetworkImage(
              imageUrl: coverUrl!,
              fit: BoxFit.cover,
              width: width,
              height: coverHeight,
              memCacheWidth: (width * 2).toInt(),
              memCacheHeight: (coverHeight * 2).toInt(),
              placeholder: (_, __) => _buildPlaceholder(),
              errorWidget: (_, __, ___) => _buildPlaceholder(),
            )
          : _buildPlaceholder(),
    );

    // Wrap in Hero for smooth list→detail transitions
    if (heroTag != null) {
      coverImage = Hero(
        tag: heroTag!,
        child: coverImage,
      );
    }

    return SizedBox(
      height: coverHeight,
      width: width,
      child: Stack(
        children: [
          coverImage,

          // Primary badge (top-right)
          if (badge != null)
            Positioned(
              top: 8,
              right: 8,
              child: badge!,
            ),

          // Secondary badge (top-left)
          if (secondaryBadge != null)
            Positioned(
              top: 8,
              left: 8,
              child: secondaryBadge!,
            ),

          // Micro label (bottom-start)
          if (microLabel != null)
            Positioned(
              bottom: 6,
              left: 6,
              child: microLabel!,
            ),
        ],
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

/// Helper widget for price badge at bottom of content cards
class PriceBadge extends StatelessWidget {
  /// Price in Toman (use 0 for free items)
  final num price;

  /// Whether the item is free
  final bool isFree;

  /// Custom text to display (overrides price formatting)
  final String? customText;

  const PriceBadge({
    super.key,
    this.price = 0,
    this.isFree = false,
    this.customText,
  });

  @override
  Widget build(BuildContext context) {
    final displayText = customText ?? (isFree ? 'رایگان' : _formatPrice(price));
    final color = isFree ? AppColors.success : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isFree ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        displayText,
        style: AppTypography.badge.copyWith(color: color),
      ),
    );
  }

  String _formatPrice(num price) {
    // Price is stored as USD
    if (price < 1) {
      return '\$${price.toStringAsFixed(2)}';
    }
    return '\$${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)}';
  }
}
