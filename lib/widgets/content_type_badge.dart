import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/widgets/content_type_micro_icon.dart';

/// Unified content type badge for Parasto
/// Displays content type (audiobook, music, podcast, ebook) with sleek micro icon and label
class ContentTypeBadge extends StatelessWidget {
  final bool isEbook;
  final bool isMusic;
  final bool isPodcast;
  final bool isArticle;
  final bool compact;

  const ContentTypeBadge({
    super.key,
    this.isEbook = false,
    this.isMusic = false,
    this.isPodcast = false,
    this.isArticle = false,
    this.compact = true,
  });

  /// Create from audiobook map data
  factory ContentTypeBadge.fromAudiobook(Map<String, dynamic> item, {bool compact = true}) {
    final ct = (item['content_type'] as String?) ?? 'audiobook';
    return ContentTypeBadge(
      isMusic: ct == 'music',
      isPodcast: ct == 'podcast',
      isArticle: ct == 'article',
      isEbook: ct == 'ebook',
      compact: compact,
    );
  }

  /// Create for ebook
  factory ContentTypeBadge.ebook({bool compact = true}) {
    return ContentTypeBadge(isEbook: true, compact: compact);
  }

  /// Create for article
  factory ContentTypeBadge.article({bool compact = true}) {
    return ContentTypeBadge(isArticle: true, compact: compact);
  }

  ContentType get _contentType {
    if (isArticle) return ContentType.article;
    if (isEbook) return ContentType.ebook;
    if (isMusic) return ContentType.music;
    if (isPodcast) return ContentType.podcast;
    return ContentType.audiobook;
  }

  String get _label {
    if (isArticle) return 'مقاله';
    if (isEbook) return 'کتاب';
    if (isMusic) return 'موسیقی';
    if (isPodcast) return 'پادکست';
    return 'صوتی';
  }

  Color get _color {
    if (isArticle) return const Color(0xFF14B8A6); // Teal for articles
    if (isEbook) return AppColors.primary; // Gold for ebooks
    if (isMusic) return const Color(0xFFA855F7); // Purple for music
    if (isPodcast) return AppColors.secondary; // Orange for podcasts
    return AppColors.info; // Blue for audiobooks
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 11.0 : 14.0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ContentTypeMicroIcon(
            type: _contentType,
            size: iconSize,
            color: AppColors.textOnSecondary,
            opacity: 0.9,
          ),
          SizedBox(width: compact ? 3 : 5),
          Text(
            _label,
            style: TextStyle(
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textOnSecondary,
              fontFamily: AppTypography.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}
