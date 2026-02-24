/// Model for text highlights and notes in EPUB reader
/// Designed for RTL (Persian/Arabic) text compatibility
/// Includes Supabase sync preparation fields

class HighlightModel {
  final String id;
  final String bookId;
  final int chapterIndex;
  final int startOffset; // Start position in chapter plain text
  final int endOffset; // End position in chapter plain text
  final String highlightedText; // The actual highlighted text
  final String anchorText; // Surrounding context for re-locating
  final String colorHex; // Highlight color as hex string
  final String? noteText; // Optional attached note
  final DateTime createdAt;
  final DateTime? updatedAt; // For sync conflict resolution
  final String? userId; // Supabase user ID for sync
  final DateTime? syncedAt; // Last sync timestamp
  final bool isPendingSync; // Local change not yet synced

  HighlightModel({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.startOffset,
    required this.endOffset,
    required this.highlightedText,
    required this.anchorText,
    required this.colorHex,
    this.noteText,
    required this.createdAt,
    this.updatedAt,
    this.userId,
    this.syncedAt,
    this.isPendingSync = false,
  });

  /// Create a copy with updated fields
  HighlightModel copyWith({
    String? id,
    String? bookId,
    int? chapterIndex,
    int? startOffset,
    int? endOffset,
    String? highlightedText,
    String? anchorText,
    String? colorHex,
    String? noteText,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
    DateTime? syncedAt,
    bool? isPendingSync,
    bool clearNote = false,
  }) {
    return HighlightModel(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      highlightedText: highlightedText ?? this.highlightedText,
      anchorText: anchorText ?? this.anchorText,
      colorHex: colorHex ?? this.colorHex,
      noteText: clearNote ? null : (noteText ?? this.noteText),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      syncedAt: syncedAt ?? this.syncedAt,
      isPendingSync: isPendingSync ?? this.isPendingSync,
    );
  }

  /// Mark as pending sync (local change made)
  HighlightModel markPendingSync() {
    return copyWith(
      updatedAt: DateTime.now(),
      isPendingSync: true,
    );
  }

  /// Mark as synced
  HighlightModel markSynced() {
    return copyWith(
      syncedAt: DateTime.now(),
      isPendingSync: false,
    );
  }

  /// Convert to JSON for local storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookId': bookId,
      'chapterIndex': chapterIndex,
      'startOffset': startOffset,
      'endOffset': endOffset,
      'highlightedText': highlightedText,
      'anchorText': anchorText,
      'colorHex': colorHex,
      'noteText': noteText,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'userId': userId,
      'syncedAt': syncedAt?.toIso8601String(),
      'isPendingSync': isPendingSync,
    };
  }

  /// Convert to Supabase format (snake_case)
  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'book_id': bookId,
      'chapter_index': chapterIndex,
      'start_offset': startOffset,
      'end_offset': endOffset,
      'highlighted_text': highlightedText,
      'anchor_text': anchorText,
      'color_hex': colorHex,
      'note_text': noteText,
      'created_at': createdAt.toIso8601String(),
      'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  /// Create from JSON (local storage)
  factory HighlightModel.fromJson(Map<String, dynamic> json) {
    return HighlightModel(
      id: json['id'] as String,
      bookId: json['bookId'] as String,
      chapterIndex: json['chapterIndex'] as int,
      startOffset: json['startOffset'] as int,
      endOffset: json['endOffset'] as int,
      highlightedText: json['highlightedText'] as String,
      anchorText: json['anchorText'] as String,
      colorHex: json['colorHex'] as String,
      noteText: json['noteText'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      userId: json['userId'] as String?,
      syncedAt: json['syncedAt'] != null
          ? DateTime.parse(json['syncedAt'] as String)
          : null,
      isPendingSync: json['isPendingSync'] as bool? ?? false,
    );
  }

  /// Create from Supabase response (snake_case)
  factory HighlightModel.fromSupabase(Map<String, dynamic> json) {
    return HighlightModel(
      id: json['id'] as String,
      bookId: json['book_id'] as String,
      chapterIndex: json['chapter_index'] as int,
      startOffset: json['start_offset'] as int,
      endOffset: json['end_offset'] as int,
      highlightedText: json['highlighted_text'] as String,
      anchorText: json['anchor_text'] as String,
      colorHex: json['color_hex'] as String,
      noteText: json['note_text'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      userId: json['user_id'] as String?,
      syncedAt: DateTime.now(),
      isPendingSync: false,
    );
  }

  /// Check if this highlight contains a note
  bool get hasNote => noteText != null && noteText!.isNotEmpty;

  /// Generate a unique ID (UUID-like for Supabase compatibility)
  static String generateId() {
    final now = DateTime.now();
    final random = now.microsecondsSinceEpoch.toRadixString(16);
    return '${now.millisecondsSinceEpoch.toRadixString(16)}-$random-${_randomHex(4)}-${_randomHex(4)}-${_randomHex(12)}';
  }

  static String _randomHex(int length) {
    final chars = '0123456789abcdef';
    final buffer = StringBuffer();
    final random = DateTime.now().microsecondsSinceEpoch;
    for (var i = 0; i < length; i++) {
      buffer.write(chars[(random + i * 7) % chars.length]);
    }
    return buffer.toString();
  }

  @override
  String toString() {
    return 'HighlightModel(id: $id, chapter: $chapterIndex, text: "${highlightedText.length > 20 ? '${highlightedText.substring(0, 20)}...' : highlightedText}", hasNote: $hasNote, pendingSync: $isPendingSync)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HighlightModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Predefined highlight colors (Apple Books-inspired)
class HighlightColors {
  static const String yellow = 'FFF9E066'; // Default yellow
  static const String green = 'FF90EE90'; // Light green
  static const String blue = 'FF87CEEB'; // Sky blue
  static const String pink = 'FFFFB6C1'; // Light pink
  static const String orange = 'FFFFA500'; // Orange
  static const String red = 'FFFF6B6B'; // Red
  static const String purple = 'FFB39DDB'; // Purple

  static List<String> get all => [yellow, green, blue, pink, orange, red, purple];

  /// Get human-readable color name (Farsi)
  static String getNameFa(String hex) {
    switch (hex) {
      case yellow:
        return 'زرد';
      case green:
        return 'سبز';
      case blue:
        return 'آبی';
      case pink:
        return 'صورتی';
      case orange:
        return 'نارنجی';
      default:
        return 'زرد';
    }
  }

  /// Get Color value from hex string
  static int parseHex(String hex) {
    return int.parse(hex, radix: 16);
  }
}
