import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Sleek, low-profile content type micro icon (Apple-like).
///
/// Uses thin-outline SVG icons (Phosphor/Lucide style) for premium feel.
/// Renders at 12–14px, monochrome, 60–75% opacity.
///
/// Usage:
/// ```dart
/// ContentTypeMicroIcon.podcast()
/// ContentTypeMicroIcon.fromData(audiobook)
/// ContentTypeMicroIcon(type: ContentType.music)
/// ```
enum ContentType {
  audiobook,
  music,
  podcast,
  article,
  ebook,
}

class ContentTypeMicroIcon extends StatelessWidget {
  final ContentType type;
  final double size;
  final Color? color;
  final double opacity;

  const ContentTypeMicroIcon({
    super.key,
    required this.type,
    this.size = 13,
    this.color,
    this.opacity = 0.65,
  });

  // ─── Named constructors ─────────────────────────────────
  const ContentTypeMicroIcon.audiobook({
    super.key,
    this.size = 13,
    this.color,
    this.opacity = 0.65,
  }) : type = ContentType.audiobook;

  const ContentTypeMicroIcon.music({
    super.key,
    this.size = 13,
    this.color,
    this.opacity = 0.65,
  }) : type = ContentType.music;

  const ContentTypeMicroIcon.podcast({
    super.key,
    this.size = 13,
    this.color,
    this.opacity = 0.65,
  }) : type = ContentType.podcast;

  const ContentTypeMicroIcon.article({
    super.key,
    this.size = 13,
    this.color,
    this.opacity = 0.65,
  }) : type = ContentType.article;

  const ContentTypeMicroIcon.ebook({
    super.key,
    this.size = 13,
    this.color,
    this.opacity = 0.65,
  }) : type = ContentType.ebook;

  /// Create from audiobook map data (auto-detects content type)
  factory ContentTypeMicroIcon.fromData(
    Map<String, dynamic> data, {
    double size = 13,
    Color? color,
    double opacity = 0.65,
  }) {
    final type = _detectType(data);
    return ContentTypeMicroIcon(
      type: type,
      size: size,
      color: color,
      opacity: opacity,
    );
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

  String get _assetPath {
    switch (type) {
      case ContentType.podcast:
        return 'assets/icons/micro/waveform.svg';
      case ContentType.article:
        return 'assets/icons/micro/document.svg';
      case ContentType.ebook:
        return 'assets/icons/micro/book.svg';
      case ContentType.audiobook:
        return 'assets/icons/micro/headphones.svg';
      case ContentType.music:
        return 'assets/icons/micro/music_note.svg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Colors.white;
    return Opacity(
      opacity: opacity,
      child: SvgPicture.asset(
        _assetPath,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
      ),
    );
  }
}
