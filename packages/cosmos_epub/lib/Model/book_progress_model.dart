/// Book progress model - stores reading progress for EPUB books
/// Using GetStorage instead of Isar for iOS compatibility
class BookProgressModel {
  String? bookId;
  int? currentChapterIndex;
  int? currentPageIndex;

  BookProgressModel({this.currentChapterIndex, this.currentPageIndex, this.bookId});

  /// Create from JSON map
  factory BookProgressModel.fromJson(Map<String, dynamic> json) {
    return BookProgressModel(
      bookId: json['bookId'] as String?,
      currentChapterIndex: json['currentChapterIndex'] as int?,
      currentPageIndex: json['currentPageIndex'] as int?,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'bookId': bookId,
      'currentChapterIndex': currentChapterIndex,
      'currentPageIndex': currentPageIndex,
    };
  }
}
