// Audiobook models for type-safe data handling.
//
// This provides typed versions of audiobook data that's commonly
// passed around as Map<String, dynamic>.
//
// NOTE: lib/models/models.dart also defines Audiobook/Chapter classes with
// String id, used by catalog_service, auth_service, and wishlist_service.
// Prefer this file for new code.

/// Lightweight audiobook model for lists and cards.
/// Use AudiobookDetail for the full detail screen.
class Audiobook {
  final int id;
  final String titleFa;
  final String? titleEn;
  final String? authorFa;
  final String? authorEn;
  final String? coverUrl;
  final String? coverStoragePath;
  final int priceToman;
  final bool isFree;
  final bool isFeatured;
  final bool isMusic;
  final bool isPodcast;
  final bool isArticle;
  final bool isParastoBrand;
  final String status;
  final int totalDurationSeconds;
  final int chapterCount;
  final int playCount;
  final double avgRating;
  final int reviewCount;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final String? categoryName;
  final int? categoryId;

  const Audiobook({
    required this.id,
    required this.titleFa,
    this.titleEn,
    this.authorFa,
    this.authorEn,
    this.coverUrl,
    this.coverStoragePath,
    required this.priceToman,
    required this.isFree,
    required this.isFeatured,
    this.isMusic = false,
    this.isPodcast = false,
    this.isArticle = false,
    this.isParastoBrand = false,
    required this.status,
    required this.totalDurationSeconds,
    required this.chapterCount,
    required this.playCount,
    required this.avgRating,
    required this.reviewCount,
    this.publishedAt,
    required this.createdAt,
    this.categoryName,
    this.categoryId,
  });

  factory Audiobook.fromJson(Map<String, dynamic> json) {
    // Get category name from nested object if available
    String? catName;
    int? catId;
    if (json['categories'] != null) {
      final cat = json['categories'] as Map<String, dynamic>;
      catName = cat['name_fa'] as String?;
      catId = cat['id'] as int?;
    }

    return Audiobook(
      id: _parseInt(json['id']),
      titleFa: (json['title_fa'] as String?) ?? '',
      titleEn: json['title_en'] as String?,
      authorFa: json['author_fa'] as String?,
      authorEn: json['author_en'] as String?,
      coverUrl: json['cover_url'] as String?,
      coverStoragePath: json['cover_storage_path'] as String?,
      priceToman: (json['price_toman'] as int?) ?? 0,
      isFree: (json['is_free'] as bool?) ?? false,
      isFeatured: (json['is_featured'] as bool?) ?? false,
      isMusic: (json['is_music'] as bool?) ?? false,
      isPodcast: (json['is_podcast'] as bool?) ?? false,
      isArticle: (json['is_article'] as bool?) ?? false,
      isParastoBrand: (json['is_parasto_brand'] as bool?) ?? false,
      status: (json['status'] as String?) ?? 'draft',
      totalDurationSeconds: (json['total_duration_seconds'] as int?) ?? 0,
      chapterCount: (json['chapter_count'] as int?) ?? 0,
      playCount: (json['play_count'] as int?) ?? 0,
      avgRating: ((json['avg_rating'] as num?) ?? 0).toDouble(),
      reviewCount: (json['review_count'] as int?) ?? 0,
      publishedAt: _parseDateTime(json['published_at']),
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      categoryName: catName,
      categoryId: catId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title_fa': titleFa,
    'title_en': titleEn,
    'author_fa': authorFa,
    'author_en': authorEn,
    'cover_url': coverUrl,
    'cover_storage_path': coverStoragePath,
    'price_toman': priceToman,
    'is_free': isFree,
    'is_featured': isFeatured,
    'is_music': isMusic,
    'is_podcast': isPodcast,
    'is_article': isArticle,
    'is_parasto_brand': isParastoBrand,
    'status': status,
    'total_duration_seconds': totalDurationSeconds,
    'chapter_count': chapterCount,
    'play_count': playCount,
    'avg_rating': avgRating,
    'review_count': reviewCount,
    'published_at': publishedAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    if (categoryName != null) 'categories': {'name_fa': categoryName, 'id': categoryId},
  };

  /// Content type for display.
  String get contentType {
    if (isMusic) return 'music';
    if (isPodcast) return 'podcast';
    if (isArticle) return 'article';
    return 'audiobook';
  }

  /// Formatted price string.
  String get formattedPrice {
    if (isFree) return 'رایگان';
    return '${_formatNumber(priceToman)} تومان';
  }

  /// Whether content is published and available.
  bool get isPublished => status == 'published';

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}٬',
    );
  }
}

/// Chapter model with progress information.
class Chapter {
  final int id;
  final int audiobookId;
  final String titleFa;
  final String? titleEn;
  final int chapterIndex;
  final String? audioStoragePath;
  final String? audioUrl;
  final int durationSeconds;
  final bool isPreview;
  final DateTime createdAt;

  const Chapter({
    required this.id,
    required this.audiobookId,
    required this.titleFa,
    this.titleEn,
    required this.chapterIndex,
    this.audioStoragePath,
    this.audioUrl,
    required this.durationSeconds,
    required this.isPreview,
    required this.createdAt,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: _parseInt(json['id']),
      audiobookId: _parseInt(json['audiobook_id']),
      titleFa: (json['title_fa'] as String?) ?? '',
      titleEn: json['title_en'] as String?,
      chapterIndex: (json['chapter_index'] as int?) ?? 0,
      audioStoragePath: json['audio_storage_path'] as String?,
      audioUrl: json['audio_url'] as String?,
      durationSeconds: (json['duration_seconds'] as int?) ?? 0,
      isPreview: (json['is_preview'] as bool?) ?? false,
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'audiobook_id': audiobookId,
    'title_fa': titleFa,
    'title_en': titleEn,
    'chapter_index': chapterIndex,
    'audio_storage_path': audioStoragePath,
    'audio_url': audioUrl,
    'duration_seconds': durationSeconds,
    'is_preview': isPreview,
    'created_at': createdAt.toIso8601String(),
  };

  Duration get duration => Duration(seconds: durationSeconds);

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

/// User's progress on an audiobook.
class AudiobookProgress {
  final String odId;
  final int audiobookId;
  final int currentChapterIndex;
  final int positionSeconds;
  final int completionPercentage;
  final bool isCompleted;
  final DateTime? lastPlayedAt;
  final DateTime? updatedAt;

  const AudiobookProgress({
    required this.odId,
    required this.audiobookId,
    required this.currentChapterIndex,
    required this.positionSeconds,
    required this.completionPercentage,
    required this.isCompleted,
    this.lastPlayedAt,
    this.updatedAt,
  });

  factory AudiobookProgress.fromJson(Map<String, dynamic> json) {
    return AudiobookProgress(
      odId: json['user_id']?.toString() ?? '',
      audiobookId: _parseInt(json['audiobook_id']),
      currentChapterIndex: (json['current_chapter_index'] as int?) ?? 0,
      positionSeconds: (json['position_seconds'] as int?) ?? 0,
      completionPercentage: ((json['completion_percentage'] as num?) ?? 0).toInt(),
      isCompleted: (json['is_completed'] as bool?) ?? false,
      lastPlayedAt: _parseDateTime(json['last_played_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': odId,
    'audiobook_id': audiobookId,
    'current_chapter_index': currentChapterIndex,
    'position_seconds': positionSeconds,
    'completion_percentage': completionPercentage,
    'is_completed': isCompleted,
    if (lastPlayedAt != null) 'last_played_at': lastPlayedAt!.toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
  };

  Duration get position => Duration(seconds: positionSeconds);

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

/// User's progress on a specific chapter.
class ChapterProgress {
  final String odId;
  final int chapterId;
  final int positionSeconds;
  final bool isCompleted;
  final DateTime? updatedAt;

  const ChapterProgress({
    required this.odId,
    required this.chapterId,
    required this.positionSeconds,
    required this.isCompleted,
    this.updatedAt,
  });

  factory ChapterProgress.fromJson(Map<String, dynamic> json) {
    return ChapterProgress(
      odId: json['user_id']?.toString() ?? '',
      chapterId: _parseInt(json['chapter_id']),
      positionSeconds: (json['position_seconds'] as int?) ?? 0,
      isCompleted: (json['is_completed'] as bool?) ?? false,
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': odId,
    'chapter_id': chapterId,
    'position_seconds': positionSeconds,
    'is_completed': isCompleted,
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
  };

  Duration get position => Duration(seconds: positionSeconds);

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
