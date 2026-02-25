import 'package:myna/utils/farsi_utils.dart';

/// Status of an ebook in the system
enum EbookStatus { draft, submitted, underReview, approved, rejected }

/// Represents an ebook in the Parasto marketplace
class Ebook {
  final int id;
  final String titleFa;
  final String? titleEn;
  final String? subtitleFa;
  final String? descriptionFa;
  final String? authorFa;
  final String? authorEn;
  final String? translatorFa;
  final String? translatorEn;
  final String? publisherFa;
  final String uploaderId;
  final int? categoryId;
  final String? categoryName;
  final String? coverStoragePath;
  final String? coverUrl;
  final String? epubStoragePath;
  final int priceToman;
  final bool isFree;
  final bool isFeatured;
  final EbookStatus status;
  final int pageCount;
  final int readCount;
  final int purchaseCount;
  final double avgRating;
  final int reviewCount;
  final String? isbn;
  final int? publicationYear;
  final DateTime? publishedAt;
  final DateTime createdAt;

  Ebook({
    required this.id,
    required this.titleFa,
    this.titleEn,
    this.subtitleFa,
    this.descriptionFa,
    this.authorFa,
    this.authorEn,
    this.translatorFa,
    this.translatorEn,
    this.publisherFa,
    required this.uploaderId,
    this.categoryId,
    this.categoryName,
    this.coverStoragePath,
    this.coverUrl,
    this.epubStoragePath,
    required this.priceToman,
    required this.isFree,
    required this.isFeatured,
    required this.status,
    required this.pageCount,
    required this.readCount,
    required this.purchaseCount,
    required this.avgRating,
    required this.reviewCount,
    this.isbn,
    this.publicationYear,
    this.publishedAt,
    required this.createdAt,
  });

  factory Ebook.fromJson(Map<String, dynamic> json) {
    return Ebook(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      titleFa: (json['title_fa'] as String?) ?? '',
      titleEn: json['title_en'] as String?,
      subtitleFa: json['subtitle_fa'] as String?,
      descriptionFa: json['description_fa'] as String?,
      authorFa: json['author_fa'] as String?,
      authorEn: json['author_en'] as String?,
      translatorFa: json['translator_fa'] as String?,
      translatorEn: json['translator_en'] as String?,
      publisherFa: json['publisher_fa'] as String?,
      uploaderId: json['uploader_id'].toString(),
      categoryId: json['category_id'] as int?,
      categoryName: (json['categories'] as Map<String, dynamic>?)?['name_fa'] as String?,
      coverStoragePath: json['cover_storage_path'] as String?,
      coverUrl: json['cover_url'] as String?,
      epubStoragePath: json['epub_storage_path'] as String?,
      priceToman: (json['price_toman'] as int?) ?? 0,
      isFree: (json['is_free'] as bool?) ?? false,
      isFeatured: (json['is_featured'] as bool?) ?? false,
      status: EbookStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String?)?.replaceAll('_', ''),
        orElse: () => EbookStatus.draft,
      ),
      pageCount: (json['page_count'] as int?) ?? 0,
      readCount: (json['play_count'] as int?) ?? (json['read_count'] as int?) ?? 0,
      purchaseCount: (json['purchase_count'] as int?) ?? 0,
      avgRating: ((json['avg_rating'] as num?) ?? 0).toDouble(),
      reviewCount: (json['review_count'] as int?) ?? 0,
      isbn: json['isbn'] as String?,
      publicationYear: json['publication_year'] as int?,
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title_fa': titleFa,
    'title_en': titleEn,
    'subtitle_fa': subtitleFa,
    'description_fa': descriptionFa,
    'author_fa': authorFa,
    'author_en': authorEn,
    'translator_fa': translatorFa,
    'translator_en': translatorEn,
    'publisher_fa': publisherFa,
    'uploader_id': uploaderId,
    'category_id': categoryId,
    'cover_storage_path': coverStoragePath,
    'cover_url': coverUrl,
    'epub_storage_path': epubStoragePath,
    'price_toman': priceToman,
    'is_free': isFree,
    'is_featured': isFeatured,
    'status': status.name,
    'page_count': pageCount,
    'play_count': readCount,
    'purchase_count': purchaseCount,
    'avg_rating': avgRating,
    'review_count': reviewCount,
    'isbn': isbn,
    'publication_year': publicationYear,
    'published_at': publishedAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };

  String get formattedPrice {
    if (isFree) return 'رایگان';
    final formatted = priceToman.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return formatted;
  }

  String get formattedPageCount {
    return '${FarsiUtils.toFarsiDigits(pageCount)} صفحه';
  }
}

/// Reading progress for an ebook
class ReadingProgress {
  final String oduserId;
  final int ebookId;
  final int currentChapterIndex;
  final String? cfiPosition;
  final double scrollPercentage;
  final double completionPercentage;
  final int totalReadTimeSeconds;
  final DateTime? lastReadAt;

  ReadingProgress({
    required this.oduserId,
    required this.ebookId,
    required this.currentChapterIndex,
    this.cfiPosition,
    required this.scrollPercentage,
    required this.completionPercentage,
    required this.totalReadTimeSeconds,
    this.lastReadAt,
  });

  factory ReadingProgress.fromJson(Map<String, dynamic> json) {
    return ReadingProgress(
      oduserId: json['user_id'] as String,
      ebookId: (json['audiobook_id'] as int?) ?? (json['ebook_id'] as int? ?? 0),
      currentChapterIndex: (json['current_chapter_index'] as int?) ?? 0,
      cfiPosition: json['cfi_position'] as String?,
      scrollPercentage: ((json['scroll_percentage'] as num?) ?? 0).toDouble(),
      completionPercentage: ((json['completion_percentage'] as num?) ?? 0).toDouble(),
      totalReadTimeSeconds: (json['total_read_time_seconds'] as int?) ?? 0,
      lastReadAt: json['last_read_at'] != null
          ? DateTime.parse(json['last_read_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': oduserId,
    'audiobook_id': ebookId,
    'current_chapter_index': currentChapterIndex,
    'cfi_position': cfiPosition,
    'scroll_percentage': scrollPercentage,
    'completion_percentage': completionPercentage,
    'total_read_time_seconds': totalReadTimeSeconds,
    'last_read_at': lastReadAt?.toIso8601String(),
  };

  String get formattedReadTime {
    final hours = totalReadTimeSeconds ~/ 3600;
    final minutes = (totalReadTimeSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${FarsiUtils.toFarsiDigits(hours)} ساعت و ${FarsiUtils.toFarsiDigits(minutes)} دقیقه';
    }
    return '${FarsiUtils.toFarsiDigits(minutes)} دقیقه';
  }
}

/// Ebook bookmark (text highlight or position marker)
class EbookBookmark {
  final String id;
  final String oduserId;
  final int ebookId;
  final int chapterIndex;
  final String? cfiPosition;
  final String? highlightedText;
  final String? note;
  final String? color;
  final DateTime createdAt;

  EbookBookmark({
    required this.id,
    required this.oduserId,
    required this.ebookId,
    required this.chapterIndex,
    this.cfiPosition,
    this.highlightedText,
    this.note,
    this.color,
    required this.createdAt,
  });

  factory EbookBookmark.fromJson(Map<String, dynamic> json) {
    return EbookBookmark(
      id: json['id'] as String,
      oduserId: json['user_id'] as String,
      ebookId: (json['audiobook_id'] as int?) ?? (json['ebook_id'] as int? ?? 0),
      chapterIndex: (json['chapter_index'] as int?) ?? 0,
      cfiPosition: json['cfi_position'] as String?,
      highlightedText: json['highlighted_text'] as String?,
      note: json['note'] as String?,
      color: json['color'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'audiobook_id': ebookId,
    'chapter_index': chapterIndex,
    'cfi_position': cfiPosition,
    'highlighted_text': highlightedText,
    'note': note,
    'color': color,
  };
}
