import 'package:get_storage/get_storage.dart';
import '../Model/highlight_model.dart';

/// Callback type for sync operations
typedef SyncCallback = Future<void> Function(HighlightModel highlight, SyncOperation operation);

/// Sync operation types
enum SyncOperation { add, update, delete }

/// Manages highlights and notes storage for EPUB reader
/// Uses GetStorage for local persistence with optional Supabase sync
class HighlightsManager {
  static final HighlightsManager _instance = HighlightsManager._internal();
  factory HighlightsManager() => _instance;
  HighlightsManager._internal();

  final GetStorage _storage = GetStorage();

  /// Optional sync callback - set this to enable cloud sync
  SyncCallback? onSyncRequired;

  /// Storage key prefix for highlights
  String _getStorageKey(String bookId) => 'highlights_$bookId';

  /// Get all highlights for a book
  List<HighlightModel> getHighlights(String bookId) {
    final key = _getStorageKey(bookId);
    final data = _storage.read<List<dynamic>>(key);
    if (data == null) return [];

    try {
      return data
          .map((item) => HighlightModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      print('COSMOS_EPUB: Error parsing highlights: $e');
      return [];
    }
  }

  /// Get highlights for a specific chapter
  List<HighlightModel> getHighlightsForChapter(String bookId, int chapterIndex) {
    return getHighlights(bookId)
        .where((h) => h.chapterIndex == chapterIndex)
        .toList();
  }

  /// Get all highlights that have notes
  List<HighlightModel> getHighlightsWithNotes(String bookId) {
    return getHighlights(bookId).where((h) => h.hasNote).toList();
  }

  /// Add a new highlight
  Future<void> addHighlight(HighlightModel highlight) async {
    final highlights = getHighlights(highlight.bookId);
    // Mark as pending sync if sync is enabled
    final toAdd = onSyncRequired != null ? highlight.markPendingSync() : highlight;
    highlights.add(toAdd);
    await _saveHighlights(highlight.bookId, highlights);

    // Trigger sync callback
    onSyncRequired?.call(toAdd, SyncOperation.add);
  }

  /// Update an existing highlight (e.g., add/edit note)
  Future<void> updateHighlight(HighlightModel highlight) async {
    final highlights = getHighlights(highlight.bookId);
    final index = highlights.indexWhere((h) => h.id == highlight.id);
    if (index != -1) {
      // Mark as pending sync if sync is enabled
      final toUpdate = onSyncRequired != null ? highlight.markPendingSync() : highlight;
      highlights[index] = toUpdate;
      await _saveHighlights(highlight.bookId, highlights);

      // Trigger sync callback
      onSyncRequired?.call(toUpdate, SyncOperation.update);
    }
  }

  /// Remove a highlight
  Future<void> removeHighlight(String bookId, String highlightId) async {
    final highlights = getHighlights(bookId);
    final toRemove = highlights.firstWhere(
      (h) => h.id == highlightId,
      orElse: () => throw StateError('Highlight not found'),
    );
    highlights.removeWhere((h) => h.id == highlightId);
    await _saveHighlights(bookId, highlights);

    // Trigger sync callback
    onSyncRequired?.call(toRemove, SyncOperation.delete);
  }

  /// Save highlights to storage
  Future<void> _saveHighlights(String bookId, List<HighlightModel> highlights) async {
    final key = _getStorageKey(bookId);
    final data = highlights.map((h) => h.toJson()).toList();
    await _storage.write(key, data);
  }

  /// Clear all highlights for a book
  Future<void> clearHighlights(String bookId) async {
    final key = _getStorageKey(bookId);
    await _storage.remove(key);
  }

  /// Find highlight by position in chapter
  /// Returns the first highlight that contains the given offset
  HighlightModel? findHighlightAtPosition(
    String bookId,
    int chapterIndex,
    int offset,
  ) {
    final highlights = getHighlightsForChapter(bookId, chapterIndex);
    for (final h in highlights) {
      if (offset >= h.startOffset && offset < h.endOffset) {
        return h;
      }
    }
    return null;
  }

  /// Check if a range overlaps with existing highlights
  bool hasOverlappingHighlight(
    String bookId,
    int chapterIndex,
    int startOffset,
    int endOffset,
  ) {
    final highlights = getHighlightsForChapter(bookId, chapterIndex);
    for (final h in highlights) {
      // Check for any overlap
      if (startOffset < h.endOffset && endOffset > h.startOffset) {
        return true;
      }
    }
    return false;
  }

  /// Generate anchor text from surrounding content
  /// Takes ~20 chars before and after for context
  static String generateAnchorText(String fullText, int start, int end) {
    final anchorStart = (start - 20).clamp(0, fullText.length);
    final anchorEnd = (end + 20).clamp(0, fullText.length);
    return fullText.substring(anchorStart, anchorEnd);
  }

  /// Try to find highlight position using anchor text (for pagination changes)
  /// Returns (startOffset, endOffset) or null if not found
  (int, int)? findByAnchorText(String chapterText, HighlightModel highlight) {
    // First try exact match
    final exactIndex = chapterText.indexOf(highlight.highlightedText);
    if (exactIndex != -1) {
      return (exactIndex, exactIndex + highlight.highlightedText.length);
    }

    // Try using anchor text context
    final anchorIndex = chapterText.indexOf(highlight.anchorText);
    if (anchorIndex != -1) {
      // Find the highlighted text within the anchor
      final relativeIndex = highlight.anchorText.indexOf(highlight.highlightedText);
      if (relativeIndex != -1) {
        final newStart = anchorIndex + relativeIndex;
        return (newStart, newStart + highlight.highlightedText.length);
      }
    }

    return null;
  }

  // ============================================================================
  // SYNC SUPPORT METHODS
  // ============================================================================

  /// Get all highlights that need to be synced
  List<HighlightModel> getPendingSyncHighlights(String bookId) {
    return getHighlights(bookId).where((h) => h.isPendingSync).toList();
  }

  /// Replace all highlights for a book (used after sync merge)
  Future<void> replaceAllHighlights(String bookId, List<HighlightModel> highlights) async {
    await _saveHighlights(bookId, highlights);
  }

  /// Mark a highlight as synced
  Future<void> markHighlightSynced(String bookId, String highlightId) async {
    final highlights = getHighlights(bookId);
    final index = highlights.indexWhere((h) => h.id == highlightId);
    if (index != -1) {
      highlights[index] = highlights[index].markSynced();
      await _saveHighlights(bookId, highlights);
    }
  }

  /// Mark all highlights as synced
  Future<void> markAllSynced(String bookId) async {
    final highlights = getHighlights(bookId);
    final synced = highlights.map((h) => h.markSynced()).toList();
    await _saveHighlights(bookId, synced);
  }
}
