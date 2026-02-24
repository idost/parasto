import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/models/search_result.dart';
import 'package:myna/models/search_result_presentation.dart';

/// Widget for displaying a single search result
class SearchResultItem extends StatelessWidget {
  final SearchResult result;
  final VoidCallback? onTap;
  final bool showDivider;

  const SearchResultItem({
    super.key,
    required this.result,
    this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(
                  bottom: BorderSide(
                    color: AppColors.borderSubtle,
                    width: 0.5,
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            // Image or icon
            _buildImage(),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type badge and title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: result.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          result.typeLabel,
                          style: TextStyle(
                            color: result.color,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (result.statusLabel != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: result.statusColor?.withValues(alpha: 0.15) ??
                                AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            result.statusLabel!,
                            style: TextStyle(
                              color: result.statusColor ?? AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Title
                  Text(
                    result.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Subtitle
                  if (result.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      result.subtitle!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Arrow
            const Icon(
              Icons.chevron_left_rounded,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (result.imageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: result.imageUrl!,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 44,
            height: 44,
            color: AppColors.surfaceLight,
            child: Icon(
              result.icon,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ),
          errorWidget: (context, url, error) => Container(
            width: 44,
            height: 44,
            color: AppColors.surfaceLight,
            child: Icon(
              result.icon,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ),
        ),
      );
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: result.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        result.icon,
        color: result.color,
        size: 22,
      ),
    );
  }
}

/// Compact search result for inline display
class SearchResultItemCompact extends StatelessWidget {
  final SearchResult result;
  final VoidCallback? onTap;

  const SearchResultItemCompact({
    super.key,
    required this.result,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: result.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                result.icon,
                color: result.color,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),

            // Title
            Expanded(
              child: Text(
                result.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Type label
            Text(
              result.typeLabel,
              style: TextStyle(
                color: result.color,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
