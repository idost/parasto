import 'package:myna/utils/farsi_utils.dart';

/// Enhanced Audiobook model for detail screens with all metadata.
/// This extends the basic Audiobook model with additional fields needed
/// for the detail screen, including nested metadata objects.
class AudiobookDetail {
  final int id;
  final String titleFa;
  final String? titleEn;
  final String? subtitleFa;
  final String? descriptionFa;
  final String narratorId;
  final int? categoryId;
  final String? categoryName;
  final String? coverStoragePath;
  final String? coverUrl;
  final int priceToman;
  final bool isFree;
  final bool isFeatured;
  final String status;
  final int totalDurationSeconds;
  final int chapterCount;
  final int playCount;
  final int purchaseCount;
  final double avgRating;
  final int reviewCount;
  final DateTime? publishedAt;
  final DateTime createdAt;

  // Content type — source of truth
  final String contentType;
  final bool isParastoBrand;

  // Derived from contentType — backward compat getters
  bool get isMusic => contentType == 'music';
  bool get isPodcast => contentType == 'podcast';
  bool get isArticle => contentType == 'article';
  bool get isEbook => contentType == 'ebook';
  bool get isAudiobook => contentType == 'audiobook';

  // Book metadata (for audiobooks)
  final BookMetadata? bookMetadata;

  // Music metadata (for music albums)
  final MusicMetadata? musicMetadata;

  const AudiobookDetail({
    required this.id,
    required this.titleFa,
    this.titleEn,
    this.subtitleFa,
    this.descriptionFa,
    required this.narratorId,
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
    this.contentType = 'audiobook',
    this.isParastoBrand = false,
    this.bookMetadata,
    this.musicMetadata,
  });

  factory AudiobookDetail.fromJson(Map<String, dynamic> json) {
    // Parse nested metadata
    BookMetadata? bookMeta;
    MusicMetadata? musicMeta;

    if (json['book_metadata'] != null) {
      bookMeta = BookMetadata.fromJson(json['book_metadata'] as Map<String, dynamic>);
    }
    if (json['music_metadata'] != null) {
      musicMeta = MusicMetadata.fromJson(json['music_metadata'] as Map<String, dynamic>);
    }

    // Get category name from nested object if available
    String? catName;
    if (json['categories'] != null) {
      catName = (json['categories'] as Map<String, dynamic>)['name_fa'] as String?;
    }

    return AudiobookDetail(
      id: _parseInt(json['id']),
      titleFa: (json['title_fa'] as String?) ?? '',
      titleEn: json['title_en'] as String?,
      subtitleFa: json['subtitle_fa'] as String?,
      descriptionFa: json['description_fa'] as String?,
      narratorId: json['narrator_id']?.toString() ?? '',
      categoryId: json['category_id'] as int?,
      categoryName: catName,
      coverStoragePath: json['cover_storage_path'] as String?,
      coverUrl: json['cover_url'] as String?,
      priceToman: (json['price_toman'] as int?) ?? 0,
      isFree: (json['is_free'] as bool?) ?? false,
      isFeatured: (json['is_featured'] as bool?) ?? false,
      status: (json['status'] as String?) ?? 'draft',
      totalDurationSeconds: (json['total_duration_seconds'] as int?) ?? 0,
      chapterCount: (json['chapter_count'] as int?) ?? 0,
      playCount: (json['play_count'] as int?) ?? 0,
      purchaseCount: (json['purchase_count'] as int?) ?? 0,
      avgRating: ((json['avg_rating'] as num?) ?? 0).toDouble(),
      reviewCount: (json['review_count'] as int?) ?? 0,
      publishedAt: _parseDateTime(json['published_at']),
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      contentType: (json['content_type'] as String?) ?? 'audiobook',
      isParastoBrand: (json['is_parasto_brand'] as bool?) ?? false,
      bookMetadata: bookMeta,
      musicMetadata: musicMeta,
    );
  }

  /// Convert back to Map for compatibility with existing code
  Map<String, dynamic> toJson() => {
    'id': id,
    'title_fa': titleFa,
    'title_en': titleEn,
    'subtitle_fa': subtitleFa,
    'description_fa': descriptionFa,
    'narrator_id': narratorId,
    'category_id': categoryId,
    'cover_storage_path': coverStoragePath,
    'cover_url': coverUrl,
    'price_toman': priceToman,
    'is_free': isFree,
    'is_featured': isFeatured,
    'status': status,
    'total_duration_seconds': totalDurationSeconds,
    'chapter_count': chapterCount,
    'play_count': playCount,
    'purchase_count': purchaseCount,
    'avg_rating': avgRating,
    'review_count': reviewCount,
    'published_at': publishedAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'content_type': contentType,
    'is_music': isMusic,       // backward compat — derived from contentType
    'is_podcast': isPodcast,   // backward compat — derived from contentType
    'is_parasto_brand': isParastoBrand,
    if (bookMetadata != null) 'book_metadata': bookMetadata!.toJson(),
    if (musicMetadata != null) 'music_metadata': musicMetadata!.toJson(),
  };

  // Computed properties
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
    return FarsiUtils.formatPriceFarsi(priceToman);
  }

  /// Get the narrator/artist name based on content type
  String? get creatorName {
    if (isMusic) {
      return musicMetadata?.artistName;
    }
    return bookMetadata?.narratorName;
  }

  /// Get the author name (for books)
  String? get authorName => bookMetadata?.authorFa;

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

/// Book-specific metadata (narrator, author, translator, etc.)
class BookMetadata {
  final int? id;
  final int? audiobookId;
  final String? narratorName;
  final String? authorFa;
  final String? authorEn;
  final String? translatorFa;
  final String? translatorEn;
  final String? publisherFa;
  final int? publicationYear;
  final String? isbn;
  final String? language;

  const BookMetadata({
    this.id,
    this.audiobookId,
    this.narratorName,
    this.authorFa,
    this.authorEn,
    this.translatorFa,
    this.translatorEn,
    this.publisherFa,
    this.publicationYear,
    this.isbn,
    this.language,
  });

  factory BookMetadata.fromJson(Map<String, dynamic> json) {
    return BookMetadata(
      id: json['id'] as int?,
      audiobookId: json['audiobook_id'] as int?,
      narratorName: json['narrator_name'] as String?,
      authorFa: json['author_fa'] as String?,
      authorEn: json['author_en'] as String?,
      translatorFa: json['translator_fa'] as String?,
      translatorEn: json['translator_en'] as String?,
      publisherFa: json['publisher_fa'] as String?,
      publicationYear: json['publication_year'] as int?,
      isbn: json['isbn'] as String?,
      language: json['language'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'audiobook_id': audiobookId,
    'narrator_name': narratorName,
    'author_fa': authorFa,
    'author_en': authorEn,
    'translator_fa': translatorFa,
    'translator_en': translatorEn,
    'publisher_fa': publisherFa,
    'publication_year': publicationYear,
    'isbn': isbn,
    'language': language,
  };
}

/// Music-specific metadata (artist, genre, featured artists, etc.)
class MusicMetadata {
  final int? id;
  final int? audiobookId;
  final String? artistName;
  final String? albumName;
  final String? genre;
  final String? featuredArtists;
  final int? releaseYear;
  final String? recordLabel;

  const MusicMetadata({
    this.id,
    this.audiobookId,
    this.artistName,
    this.albumName,
    this.genre,
    this.featuredArtists,
    this.releaseYear,
    this.recordLabel,
  });

  factory MusicMetadata.fromJson(Map<String, dynamic> json) {
    return MusicMetadata(
      id: json['id'] as int?,
      audiobookId: json['audiobook_id'] as int?,
      artistName: json['artist_name'] as String?,
      albumName: json['album_name'] as String?,
      genre: json['genre'] as String?,
      featuredArtists: json['featured_artists'] as String?,
      releaseYear: json['release_year'] as int?,
      recordLabel: json['record_label'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'audiobook_id': audiobookId,
    'artist_name': artistName,
    'album_name': albumName,
    'genre': genre,
    'featured_artists': featuredArtists,
    'release_year': releaseYear,
    'record_label': recordLabel,
  };
}

/// Chapter with progress information
class ChapterDetail {
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

  // Optional progress data
  final Duration? savedPosition;
  final double? completionPercentage;

  const ChapterDetail({
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
    this.savedPosition,
    this.completionPercentage,
  });

  factory ChapterDetail.fromJson(Map<String, dynamic> json, {Map<String, dynamic>? progress}) {
    Duration? savedPos;
    double? completion;

    if (progress != null) {
      final positionMs = progress['position_ms'] as int?;
      if (positionMs != null) {
        savedPos = Duration(milliseconds: positionMs);
      }
      completion = (progress['completion_percentage'] as num?)?.toDouble();
    }

    return ChapterDetail(
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
      savedPosition: savedPos,
      completionPercentage: completion,
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

  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${FarsiUtils.toFarsiDigits(minutes)}:${seconds.toString().padLeft(2, '0')}';
  }

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

/// Review with user profile information
class ReviewDetail {
  final int id;
  final int audiobookId;
  final String userId;
  final int rating;
  final String? reviewText;
  final bool isApproved;
  final DateTime createdAt;

  // User profile info
  final String? userDisplayName;
  final String? userAvatarUrl;

  const ReviewDetail({
    required this.id,
    required this.audiobookId,
    required this.userId,
    required this.rating,
    this.reviewText,
    required this.isApproved,
    required this.createdAt,
    this.userDisplayName,
    this.userAvatarUrl,
  });

  factory ReviewDetail.fromJson(Map<String, dynamic> json) {
    // Extract profile info from nested object
    String? displayName;
    String? avatarUrl;
    if (json['profiles'] != null) {
      final profile = json['profiles'] as Map<String, dynamic>;
      displayName = profile['display_name'] as String?;
      avatarUrl = profile['avatar_url'] as String?;
    }

    return ReviewDetail(
      id: _parseInt(json['id']),
      audiobookId: _parseInt(json['audiobook_id']),
      userId: json['user_id']?.toString() ?? '',
      rating: (json['rating'] as int?) ?? 0,
      reviewText: json['review_text'] as String?,
      isApproved: (json['is_approved'] as bool?) ?? false,
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      userDisplayName: displayName,
      userAvatarUrl: avatarUrl,
    );
  }

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

/// Extension for safe access to Map fields with type conversion
/// Use this during gradual migration from Map<String, dynamic> to typed models
extension SafeMapAccess on Map<String, dynamic> {
  /// Get string value or empty string
  String getString(String key) => (this[key] as String?) ?? '';

  /// Get nullable string
  String? getStringOrNull(String key) => this[key] as String?;

  /// Get int value or 0
  int getInt(String key) {
    final value = this[key];
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is num) return value.toInt();
    return 0;
  }

  /// Get nullable int
  int? getIntOrNull(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is num) return value.toInt();
    return null;
  }

  /// Get double value or 0.0
  double getDouble(String key) {
    final value = this[key];
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    if (value is num) return value.toDouble();
    return 0.0;
  }

  /// Get bool value or false
  bool getBool(String key) => (this[key] as bool?) ?? false;

  /// Get DateTime or null
  DateTime? getDateTime(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Get nested map or empty map
  Map<String, dynamic> getMap(String key) =>
      (this[key] as Map<String, dynamic>?) ?? {};

  /// Get list or empty list
  List<Map<String, dynamic>> getList(String key) {
    final value = this[key];
    if (value is List) {
      return value.cast<Map<String, dynamic>>();
    }
    return [];
  }
}
