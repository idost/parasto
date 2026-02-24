import 'package:cosmos_epub/Model/book_progress_model.dart';
import 'package:get_storage/get_storage.dart';

/// Book progress storage using GetStorage (replaces Isar for iOS compatibility)
class BookProgressSingleton {
  static const String _storageKey = 'book_progress_';
  final GetStorage _storage;

  BookProgressSingleton() : _storage = GetStorage();

  Future<bool> setCurrentChapterIndex(String bookId, int chapterIndex) async {
    try {
      final progress = getBookProgress(bookId);
      progress.currentChapterIndex = chapterIndex;
      await _storage.write('$_storageKey$bookId', progress.toJson());
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> setCurrentPageIndex(String bookId, int pageIndex) async {
    try {
      final progress = getBookProgress(bookId);
      progress.currentPageIndex = pageIndex;
      await _storage.write('$_storageKey$bookId', progress.toJson());
      return true;
    } catch (e) {
      return false;
    }
  }

  BookProgressModel getBookProgress(String bookId) {
    try {
      final data = _storage.read<Map<String, dynamic>>('$_storageKey$bookId');
      if (data != null) {
        return BookProgressModel.fromJson(data);
      }
    } catch (e) {
      // Return default on error
    }
    return BookProgressModel(
      bookId: bookId,
      currentPageIndex: 0,
      currentChapterIndex: 0,
    );
  }

  Future<bool> deleteBookProgress(String bookId) async {
    try {
      await _storage.remove('$_storageKey$bookId');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteAllBooksProgress() async {
    try {
      await _storage.erase();
      return true;
    } catch (e) {
      return false;
    }
  }
}
