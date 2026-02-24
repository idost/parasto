import 'package:myna/utils/farsi_utils.dart';

enum UserRole { listener, narrator, admin }

enum AudiobookStatus { draft, submitted, underReview, approved, rejected }

class Profile {
  final String id;
  final String email;
  final String? fullName;
  final String? displayName;
  final UserRole role;
  final String? avatarUrl;
  final String? bio;
  final DateTime createdAt;

  Profile({
    required this.id,
    required this.email,
    this.fullName,
    this.displayName,
    required this.role,
    this.avatarUrl,
    this.bio,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'].toString(),
      email: (json['email'] as String?) ?? '',
      fullName: json['full_name'] as String?,
      displayName: json['display_name'] as String?,
      role: UserRole.values.firstWhere(
        (e) => e.name == (json['role'] as String?),
        orElse: () => UserRole.listener,
      ),
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get nameToShow => displayName ?? fullName ?? email.split('@').first;
}

class Category {
  final int id;
  final String slug;
  final String nameFa;
  final String nameEn;
  final bool isActive;
  final int sortOrder;

  Category({
    required this.id,
    required this.slug,
    required this.nameFa,
    required this.nameEn,
    required this.isActive,
    required this.sortOrder,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      slug: (json['slug'] as String?) ?? '',
      nameFa: (json['name_fa'] as String?) ?? '',
      nameEn: (json['name_en'] as String?) ?? '',
      isActive: (json['is_active'] as bool?) ?? true,
      sortOrder: (json['sort_order'] as int?) ?? 0,
    );
  }
}

// NOTE: A separate Audiobook class with int id exists in audiobook.dart.
// This version (String id) is used by catalog_service, auth_service, and
// wishlist_service. Prefer audiobook.dart for new code.
class Audiobook {
  final String id;
  final String titleFa;
  final String? titleEn;
  final String? subtitleFa;
  final String? descriptionFa;
  final String narratorId;
  final String? narratorName;
  final int? categoryId;
  final String? categoryName;
  final String? coverStoragePath;
  final String? coverUrl;
  final int priceToman;
  final bool isFree;
  final bool isFeatured;
  final AudiobookStatus status;
  final int totalDurationSeconds;
  final int chapterCount;
  final int playCount;
  final int purchaseCount;
  final double avgRating;
  final int reviewCount;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final String? authorFa;
  final String? authorEn;
  final String? translatorFa;
  final String? translatorEn;

  Audiobook({
    required this.id,
    required this.titleFa,
    this.titleEn,
    this.subtitleFa,
    this.descriptionFa,
    required this.narratorId,
    this.narratorName,
    this.categoryId,
    this.categoryName,
    this.coverStoragePath,
    this.coverUrl,
    required this.priceToman,
    required this.isFree,
    required this.isFeatured,
    required this.status,
    required this.totalDurationSeconds,
    required this.chapterCount,
    required this.playCount,
    required this.purchaseCount,
    required this.avgRating,
    required this.reviewCount,
    this.publishedAt,
    required this.createdAt,
    this.authorFa,
    this.authorEn,
    this.translatorFa,
    this.translatorEn,
  });

  factory Audiobook.fromJson(Map<String, dynamic> json) {
    return Audiobook(
      id: json['id'].toString(),
      titleFa: (json['title_fa'] as String?) ?? '',
      titleEn: json['title_en'] as String?,
      subtitleFa: json['subtitle_fa'] as String?,
      descriptionFa: json['description_fa'] as String?,
      narratorId: json['narrator_id'].toString(),
      // Get narrator/artist from correct metadata table (not profiles which is the uploader account)
      narratorName: (json['is_music'] == true)
          ? ((json['music_metadata'] as Map<String, dynamic>?)?['artist_name'] as String?)
          : ((json['book_metadata'] as Map<String, dynamic>?)?['narrator_name'] as String?) ??
            (json['narrator_name'] as String?),
      categoryId: json['category_id'] as int?,
      categoryName: json['category_name'] as String?,
      coverStoragePath: json['cover_storage_path'] as String?,
      coverUrl: json['cover_url'] as String?,
      priceToman: (json['price_toman'] as int?) ?? 0,
      isFree: (json['is_free'] as bool?) ?? false,
      isFeatured: (json['is_featured'] as bool?) ?? false,
      status: AudiobookStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String?),
        orElse: () => AudiobookStatus.draft,
      ),
      totalDurationSeconds: (json['total_duration_seconds'] as int?) ?? 0,
      chapterCount: (json['chapter_count'] as int?) ?? 0,
      playCount: (json['play_count'] as int?) ?? 0,
      purchaseCount: (json['purchase_count'] as int?) ?? 0,
      avgRating: ((json['avg_rating'] as num?) ?? 0).toDouble(),
      reviewCount: (json['review_count'] as int?) ?? 0,
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      authorFa: json['author_fa'] as String?,
      authorEn: json['author_en'] as String?,
      translatorFa: json['translator_fa'] as String?,
      translatorEn: json['translator_en'] as String?,
    );
  }

  String get formattedDuration {
    final hours = totalDurationSeconds ~/ 3600;
    final minutes = (totalDurationSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${FarsiUtils.toFarsiDigits(hours)} ساعت و ${FarsiUtils.toFarsiDigits(minutes)} دقیقه';
    }
    return '${FarsiUtils.toFarsiDigits(minutes)} دقیقه';
  }

  String get formattedPrice {
    if (isFree) return 'رایگان';
    // Format with thousand separators
    final formatted = priceToman.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return formatted;
  }
}

// NOTE: A separate Chapter class with int id exists in audiobook.dart.
// This version (String id) is used alongside the Audiobook above.
class Chapter {
  final String id;
  final String audiobookId;
  final String titleFa;
  final String? titleEn;
  final int chapterIndex;
  final String? audioStoragePath;
  final int durationSeconds;
  final bool isPreview;
  final DateTime createdAt;

  Chapter({
    required this.id,
    required this.audiobookId,
    required this.titleFa,
    this.titleEn,
    required this.chapterIndex,
    this.audioStoragePath,
    required this.durationSeconds,
    required this.isPreview,
    required this.createdAt,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'].toString(),
      audiobookId: json['audiobook_id'].toString(),
      titleFa: (json['title_fa'] as String?) ?? '',
      titleEn: json['title_en'] as String?,
      chapterIndex: (json['chapter_index'] as int?) ?? 0,
      audioStoragePath: json['audio_storage_path'] as String?,
      durationSeconds: (json['duration_seconds'] as int?) ?? 0,
      isPreview: (json['is_preview'] as bool?) ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}