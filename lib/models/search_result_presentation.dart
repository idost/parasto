import 'package:flutter/material.dart';
import 'package:myna/theme/app_theme.dart';
import 'package:myna/models/search_result.dart';

/// UI presentation extensions for [SearchResult].
/// Keeps Color, IconData, and AppColors references out of the data model.
extension SearchResultPresentation on SearchResult {
  /// Icon for the result type
  IconData get icon {
    switch (type) {
      case SearchResultType.audiobook:
        return switch (metadata['content_type'] as String? ?? 'audiobook') {
          'music' => Icons.music_note_rounded,
          'podcast' => Icons.podcasts_rounded,
          'article' => Icons.article_rounded,
          'ebook' => Icons.auto_stories_rounded,
          _ => Icons.menu_book_rounded,
        };
      case SearchResultType.user:
        return Icons.person_rounded;
      case SearchResultType.creator:
        return Icons.record_voice_over_rounded;
      case SearchResultType.ticket:
        return Icons.support_agent_rounded;
    }
  }

  /// Color for the result type
  Color get color {
    switch (type) {
      case SearchResultType.audiobook:
        return switch (metadata['content_type'] as String? ?? 'audiobook') {
          'music' => AppColors.secondary,
          'podcast' => AppColors.info,
          'ebook' => const Color(0xFF10B981), // Emerald
          _ => AppColors.primary,
        };
      case SearchResultType.user:
        return AppColors.info;
      case SearchResultType.creator:
        return const Color(0xFFA855F7); // Purple
      case SearchResultType.ticket:
        return AppColors.warning;
    }
  }

  /// Status color
  Color? get statusColor {
    final status = metadata['status'] as String?;
    if (status == null) return null;

    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      case 'open':
        return AppColors.info;
      case 'closed':
        return AppColors.textTertiary;
      default:
        return AppColors.textSecondary;
    }
  }
}
