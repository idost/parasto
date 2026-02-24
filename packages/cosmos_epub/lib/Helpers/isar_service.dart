import 'package:cosmos_epub/Helpers/progress_singleton.dart';
import 'package:get_storage/get_storage.dart';

/// Storage service using GetStorage (replaces Isar for iOS compatibility)
class IsarService {
  IsarService._create();

  static Future<BookProgressSingleton> buildIsarService() async {
    await GetStorage.init();
    return BookProgressSingleton();
  }

  /// No-op for GetStorage (doesn't need file lock management)
  static Future<void> closeDatabase() async {
    // GetStorage doesn't require explicit close
  }

  /// No-op for GetStorage (doesn't need reopen)
  static Future<BookProgressSingleton?> reopenDatabase() async {
    return BookProgressSingleton();
  }
}
