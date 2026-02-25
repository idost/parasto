import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/utils/app_strings.dart';
import 'package:myna/widgets/content_type_micro_icon.dart';

/// Small semi-transparent pill showing content type as Farsi text.
///
/// Positioned at **bottom-start** of cover images. Design:
/// - Background: black 55% opacity, borderRadius 4
/// - Text: 10px, w600, white
/// - Padding: horizontal 6, vertical 2
///
/// Usage:
/// ```dart
/// ContentTypeMicroLabel(type: ContentType.music)
/// ContentTypeMicroLabel.fromData(audiobook)
/// ```
class ContentTypeMicroLabel extends StatelessWidget {
  final ContentType type;

  const ContentTypeMicroLabel({
    super.key,
    required this.type,
  });

  /// Auto-detect content type from audiobook/ebook map data.
  /// Reuses the same detection logic as [ContentTypeMicroIcon].
  factory ContentTypeMicroLabel.fromData(Map<String, dynamic> data) {
    return ContentTypeMicroLabel(type: _detectType(data));
  }

  static ContentType _detectType(Map<String, dynamic> data) {
    final ct = (data['content_type'] as String?) ?? '';
    switch (ct) {
      case 'article': return ContentType.article;
      case 'podcast': return ContentType.podcast;
      case 'music':   return ContentType.music;
      case 'ebook':   return ContentType.ebook;
      default:        return ContentType.audiobook;
    }
  }

  String get _label {
    switch (type) {
      case ContentType.music:
        return AppStrings.musicLabel;
      case ContentType.podcast:
        return AppStrings.podcastLabel;
      case ContentType.article:
        return AppStrings.articleLabel;
      case ContentType.ebook:
        return AppStrings.bookLabel;
      case ContentType.audiobook:
        return AppStrings.audiobookLabel;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _label,
        style: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1.3,
        ),
      ),
    );
  }
}
