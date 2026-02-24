/// Types of searchable entities
enum SearchResultType {
  audiobook,
  user,
  creator,
  ticket,
}

/// Represents a search result from the global admin search
class SearchResult {
  final SearchResultType type;
  final String itemId;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const SearchResult({
    required this.type,
    required this.itemId,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.metadata = const {},
    required this.createdAt,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      type: _parseType(json['type'] as String),
      itemId: json['item_id'] as String,
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      imageUrl: json['image_url'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static SearchResultType _parseType(String type) {
    switch (type) {
      case 'audiobook':
        return SearchResultType.audiobook;
      case 'user':
        return SearchResultType.user;
      case 'creator':
        return SearchResultType.creator;
      case 'ticket':
        return SearchResultType.ticket;
      default:
        return SearchResultType.audiobook;
    }
  }

  /// Navigation route for this result
  String get route {
    switch (type) {
      case SearchResultType.audiobook:
        return '/admin/audiobooks/$itemId';
      case SearchResultType.user:
        return '/admin/users/$itemId';
      case SearchResultType.creator:
        return '/admin/creators/$itemId';
      case SearchResultType.ticket:
        return '/admin/support/$itemId';
    }
  }

  /// Label for the result type (in Persian)
  String get typeLabel {
    switch (type) {
      case SearchResultType.audiobook:
        final isMusic = metadata['is_music'] as bool? ?? false;
        return isMusic ? 'موسیقی' : 'کتاب صوتی';
      case SearchResultType.user:
        return 'کاربر';
      case SearchResultType.creator:
        return 'سازنده';
      case SearchResultType.ticket:
        return 'تیکت';
    }
  }

  /// Status badge (if applicable)
  String? get statusLabel {
    final status = metadata['status'] as String?;
    if (status == null) return null;

    switch (status) {
      case 'pending':
        return 'در انتظار';
      case 'approved':
        return 'تأیید شده';
      case 'rejected':
        return 'رد شده';
      case 'open':
        return 'باز';
      case 'closed':
        return 'بسته';
      default:
        return status;
    }
  }

}

/// Search history item
class SearchHistoryItem {
  final String id;
  final String query;
  final SearchResultType? resultType;
  final String? resultId;
  final DateTime createdAt;

  const SearchHistoryItem({
    required this.id,
    required this.query,
    this.resultType,
    this.resultId,
    required this.createdAt,
  });

  factory SearchHistoryItem.fromJson(Map<String, dynamic> json) {
    return SearchHistoryItem(
      id: json['id'] as String,
      query: json['query'] as String,
      resultType: json['result_type'] != null
          ? SearchResult._parseType(json['result_type'] as String)
          : null,
      resultId: json['result_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'query': query,
      'result_type': resultType?.name,
      'result_id': resultId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Saved filter preset
class SavedFilter {
  final String id;
  final String adminId;
  final String name;
  final String screen;
  final Map<String, dynamic> filters;
  final bool isDefault;
  final DateTime createdAt;

  const SavedFilter({
    required this.id,
    required this.adminId,
    required this.name,
    required this.screen,
    required this.filters,
    this.isDefault = false,
    required this.createdAt,
  });

  factory SavedFilter.fromJson(Map<String, dynamic> json) {
    return SavedFilter(
      id: json['id'] as String,
      adminId: json['admin_id'] as String,
      name: json['name'] as String,
      screen: json['screen'] as String,
      filters: json['filters'] as Map<String, dynamic>? ?? {},
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'admin_id': adminId,
      'name': name,
      'screen': screen,
      'filters': filters,
      'is_default': isDefault,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
