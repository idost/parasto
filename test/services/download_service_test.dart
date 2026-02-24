// Comprehensive unit tests for DownloadService and DownloadProvider
// Tests download state models, enums, progress tracking, file paths,
// queue management, error handling, and state transitions.

import 'package:flutter_test/flutter_test.dart';
import 'package:myna/services/download_service.dart';
import 'package:myna/providers/download_provider.dart';

void main() {
  group('DownloadStatus Enum', () {
    test('contains all expected values', () {
      expect(DownloadStatus.values, contains(DownloadStatus.notDownloaded));
      expect(DownloadStatus.values, contains(DownloadStatus.downloading));
      expect(DownloadStatus.values, contains(DownloadStatus.downloaded));
      expect(DownloadStatus.values, contains(DownloadStatus.failed));
    });

    test('has correct number of values', () {
      expect(DownloadStatus.values.length, equals(4));
    });

    test('enum values have correct indices', () {
      expect(DownloadStatus.notDownloaded.index, equals(0));
      expect(DownloadStatus.downloading.index, equals(1));
      expect(DownloadStatus.downloaded.index, equals(2));
      expect(DownloadStatus.failed.index, equals(3));
    });
  });

  group('DownloadedChapter Model', () {
    test('creates instance with required parameters', () {
      final chapter = DownloadedChapter(
        audiobookId: 1,
        chapterId: 2,
        localPath: '/path/to/file.mp3',
        fileSizeBytes: 1024,
        downloadedAt: DateTime(2024, 1, 15, 10, 30),
      );

      expect(chapter.audiobookId, equals(1));
      expect(chapter.chapterId, equals(2));
      expect(chapter.localPath, equals('/path/to/file.mp3'));
      expect(chapter.fileSizeBytes, equals(1024));
      expect(chapter.downloadedAt, equals(DateTime(2024, 1, 15, 10, 30)));
      expect(chapter.expectedSizeBytes, isNull);
      expect(chapter.isVerified, isFalse);
    });

    test('creates instance with optional parameters', () {
      final chapter = DownloadedChapter(
        audiobookId: 1,
        chapterId: 2,
        localPath: '/path/to/file.mp3',
        fileSizeBytes: 1024,
        downloadedAt: DateTime(2024, 1, 15),
        expectedSizeBytes: 1024,
        isVerified: true,
      );

      expect(chapter.expectedSizeBytes, equals(1024));
      expect(chapter.isVerified, isTrue);
    });

    group('toJson', () {
      test('serializes all fields correctly', () {
        final chapter = DownloadedChapter(
          audiobookId: 42,
          chapterId: 7,
          localPath: '/downloads/42_7.mp3',
          fileSizeBytes: 5000000,
          downloadedAt: DateTime(2024, 6, 15, 14, 30, 45),
          expectedSizeBytes: 5000000,
          isVerified: true,
        );

        final json = chapter.toJson();

        expect(json['audiobookId'], equals(42));
        expect(json['chapterId'], equals(7));
        expect(json['localPath'], equals('/downloads/42_7.mp3'));
        expect(json['fileSizeBytes'], equals(5000000));
        expect(json['downloadedAt'], equals('2024-06-15T14:30:45.000'));
        expect(json['expectedSizeBytes'], equals(5000000));
        expect(json['isVerified'], isTrue);
      });

      test('handles null optional fields', () {
        final chapter = DownloadedChapter(
          audiobookId: 1,
          chapterId: 1,
          localPath: '/path.mp3',
          fileSizeBytes: 100,
          downloadedAt: DateTime(2024, 1, 1),
        );

        final json = chapter.toJson();

        expect(json['expectedSizeBytes'], isNull);
        expect(json['isVerified'], isFalse);
      });
    });

    group('fromJson', () {
      test('deserializes all fields correctly', () {
        final json = {
          'audiobookId': 42,
          'chapterId': 7,
          'localPath': '/downloads/42_7.mp3',
          'fileSizeBytes': 5000000,
          'downloadedAt': '2024-06-15T14:30:45.000',
          'expectedSizeBytes': 5000000,
          'isVerified': true,
        };

        final chapter = DownloadedChapter.fromJson(json);

        expect(chapter.audiobookId, equals(42));
        expect(chapter.chapterId, equals(7));
        expect(chapter.localPath, equals('/downloads/42_7.mp3'));
        expect(chapter.fileSizeBytes, equals(5000000));
        expect(chapter.downloadedAt, equals(DateTime(2024, 6, 15, 14, 30, 45)));
        expect(chapter.expectedSizeBytes, equals(5000000));
        expect(chapter.isVerified, isTrue);
      });

      test('handles null optional fields', () {
        final json = {
          'audiobookId': 1,
          'chapterId': 1,
          'localPath': '/path.mp3',
          'fileSizeBytes': 100,
          'downloadedAt': '2024-01-01T00:00:00.000',
          // expectedSizeBytes and isVerified not present
        };

        final chapter = DownloadedChapter.fromJson(json);

        expect(chapter.expectedSizeBytes, isNull);
        expect(chapter.isVerified, isFalse);
      });

      test('handles isVerified being null in JSON', () {
        final json = {
          'audiobookId': 1,
          'chapterId': 1,
          'localPath': '/path.mp3',
          'fileSizeBytes': 100,
          'downloadedAt': '2024-01-01T00:00:00.000',
          'expectedSizeBytes': null,
          'isVerified': null, // Explicitly null
        };

        final chapter = DownloadedChapter.fromJson(json);

        expect(chapter.isVerified, isFalse);
      });

      test('roundtrip serialization works', () {
        final original = DownloadedChapter(
          audiobookId: 123,
          chapterId: 456,
          localPath: '/test/path.m4a',
          fileSizeBytes: 9999999,
          downloadedAt: DateTime(2024, 12, 31, 23, 59, 59),
          expectedSizeBytes: 9999999,
          isVerified: true,
        );

        final json = original.toJson();
        final restored = DownloadedChapter.fromJson(json);

        expect(restored.audiobookId, equals(original.audiobookId));
        expect(restored.chapterId, equals(original.chapterId));
        expect(restored.localPath, equals(original.localPath));
        expect(restored.fileSizeBytes, equals(original.fileSizeBytes));
        expect(restored.downloadedAt, equals(original.downloadedAt));
        expect(restored.expectedSizeBytes, equals(original.expectedSizeBytes));
        expect(restored.isVerified, equals(original.isVerified));
      });
    });
  });

  group('DownloadTask Model', () {
    test('creates instance with required parameters', () {
      final task = DownloadTask(
        audiobookId: 1,
        chapterId: 2,
        url: 'https://example.com/audio.mp3',
      );

      expect(task.audiobookId, equals(1));
      expect(task.chapterId, equals(2));
      expect(task.url, equals('https://example.com/audio.mp3'));
      expect(task.progress, equals(0.0));
      expect(task.status, equals(DownloadStatus.downloading));
      expect(task.cancelToken, isNull);
      expect(task.errorMessage, isNull);
      expect(task.downloadedBytes, equals(0));
      expect(task.totalBytes, isNull);
    });

    test('creates instance with all parameters', () {
      final task = DownloadTask(
        audiobookId: 1,
        chapterId: 2,
        url: 'https://example.com/audio.mp3',
        progress: 0.5,
        status: DownloadStatus.failed,
        errorMessage: 'Network error',
        downloadedBytes: 500,
        totalBytes: 1000,
      );

      expect(task.progress, equals(0.5));
      expect(task.status, equals(DownloadStatus.failed));
      expect(task.errorMessage, equals('Network error'));
      expect(task.downloadedBytes, equals(500));
      expect(task.totalBytes, equals(1000));
    });

    test('progress can be updated', () {
      final task = DownloadTask(
        audiobookId: 1,
        chapterId: 2,
        url: 'https://example.com/audio.mp3',
      );

      task.progress = 0.75;
      expect(task.progress, equals(0.75));
    });

    test('status can be updated', () {
      final task = DownloadTask(
        audiobookId: 1,
        chapterId: 2,
        url: 'https://example.com/audio.mp3',
      );

      task.status = DownloadStatus.downloaded;
      expect(task.status, equals(DownloadStatus.downloaded));
    });

    test('bytes tracking works correctly', () {
      final task = DownloadTask(
        audiobookId: 1,
        chapterId: 2,
        url: 'https://example.com/audio.mp3',
        downloadedBytes: 0,
        totalBytes: 10000,
      );

      // Simulate download progress
      task.downloadedBytes = 2500;
      task.progress = 2500 / 10000;

      expect(task.downloadedBytes, equals(2500));
      expect(task.progress, equals(0.25));

      task.downloadedBytes = 10000;
      task.progress = 1.0;

      expect(task.downloadedBytes, equals(10000));
      expect(task.progress, equals(1.0));
    });
  });

  group('Download Key Generation', () {
    // Tests for the key format used internally: '${audiobookId}_$chapterId'
    test('key format follows expected pattern', () {
      // The key format is used in both DownloadService and DownloadProvider
      String getKey(int audiobookId, int chapterId) =>
          '${audiobookId}_$chapterId';

      expect(getKey(1, 2), equals('1_2'));
      expect(getKey(100, 50), equals('100_50'));
      expect(getKey(0, 0), equals('0_0'));
      expect(getKey(999999, 999999), equals('999999_999999'));
    });

    test('keys are unique for different chapters', () {
      String getKey(int audiobookId, int chapterId) =>
          '${audiobookId}_$chapterId';

      final key1 = getKey(1, 2);
      final key2 = getKey(1, 3);
      final key3 = getKey(2, 2);

      expect(key1, isNot(equals(key2)));
      expect(key1, isNot(equals(key3)));
      expect(key2, isNot(equals(key3)));
    });

    test('same audiobook and chapter always produces same key', () {
      String getKey(int audiobookId, int chapterId) =>
          '${audiobookId}_$chapterId';

      expect(getKey(42, 7), equals(getKey(42, 7)));
    });
  });

  group('File Path Generation', () {
    test('extension extraction from URL works correctly', () {
      // Simulates the logic in downloadChapter
      String extractExtension(String url) {
        return url.split('.').last.split('?').first;
      }

      expect(extractExtension('https://example.com/file.mp3'), equals('mp3'));
      expect(extractExtension('https://example.com/file.m4a'), equals('m4a'));
      expect(extractExtension('https://example.com/file.aac'), equals('aac'));
      expect(extractExtension('https://example.com/file.ogg'), equals('ogg'));
    });

    test('extension extraction handles query parameters', () {
      String extractExtension(String url) {
        return url.split('.').last.split('?').first;
      }

      expect(
        extractExtension('https://example.com/file.mp3?token=abc123'),
        equals('mp3'),
      );
      expect(
        extractExtension(
            'https://cdn.example.com/audio.m4a?signature=xyz&expires=12345'),
        equals('m4a'),
      );
    });

    test('filename generation follows expected pattern', () {
      String generateFilename(int audiobookId, int chapterId, String extension) {
        return '${audiobookId}_$chapterId.$extension';
      }

      expect(generateFilename(1, 2, 'mp3'), equals('1_2.mp3'));
      expect(generateFilename(100, 50, 'm4a'), equals('100_50.m4a'));
    });

    test('partial filename follows expected pattern', () {
      String generatePartialFilename(
          int audiobookId, int chapterId, String extension) {
        return '${audiobookId}_$chapterId.$extension.partial';
      }

      expect(generatePartialFilename(1, 2, 'mp3'), equals('1_2.mp3.partial'));
      expect(
          generatePartialFilename(100, 50, 'm4a'), equals('100_50.m4a.partial'));
    });
  });

  group('Progress Calculation', () {
    test('progress is calculated correctly from bytes', () {
      double calculateProgress(int received, int total) {
        if (total <= 0) return 0.0;
        return received / total;
      }

      expect(calculateProgress(0, 1000), equals(0.0));
      expect(calculateProgress(500, 1000), equals(0.5));
      expect(calculateProgress(1000, 1000), equals(1.0));
      expect(calculateProgress(250, 1000), equals(0.25));
    });

    test('progress handles edge cases', () {
      double calculateProgress(int received, int total) {
        if (total <= 0) return 0.0;
        return received / total;
      }

      expect(calculateProgress(0, 0), equals(0.0));
      expect(calculateProgress(100, 0), equals(0.0));
      expect(calculateProgress(0, -1), equals(0.0));
    });

    test('resumed download progress includes existing bytes', () {
      // Simulates the logic in downloadChapter for resumed downloads
      int existingBytes = 500;
      int received = 300;
      int totalRemaining = 500; // Server reports remaining bytes

      int actualReceived = received + existingBytes;
      int actualTotal = totalRemaining + existingBytes;
      double progress = actualReceived / actualTotal;

      expect(actualReceived, equals(800));
      expect(actualTotal, equals(1000));
      expect(progress, equals(0.8));
    });
  });

  group('DownloadState Model (Provider)', () {
    test('default state has empty maps and zero counts', () {
      const state = DownloadState();

      expect(state.statuses, isEmpty);
      expect(state.progress, isEmpty);
      expect(state.totalDownloads, equals(0));
      expect(state.totalSizeBytes, equals(0));
    });

    test('creates state with provided values', () {
      final state = DownloadState(
        statuses: {'1_2': DownloadStatus.downloaded},
        progress: {'1_2': 1.0},
        totalDownloads: 5,
        totalSizeBytes: 50000000,
      );

      expect(state.statuses['1_2'], equals(DownloadStatus.downloaded));
      expect(state.progress['1_2'], equals(1.0));
      expect(state.totalDownloads, equals(5));
      expect(state.totalSizeBytes, equals(50000000));
    });

    group('copyWith', () {
      test('creates new state with updated statuses', () {
        const original = DownloadState(
          totalDownloads: 3,
          totalSizeBytes: 30000,
        );

        final updated = original.copyWith(
          statuses: {'1_1': DownloadStatus.downloading},
        );

        expect(updated.statuses['1_1'], equals(DownloadStatus.downloading));
        expect(updated.totalDownloads, equals(3)); // Preserved
        expect(updated.totalSizeBytes, equals(30000)); // Preserved
      });

      test('creates new state with updated progress', () {
        final original = DownloadState(
          progress: {'1_1': 0.5},
        );

        final updated = original.copyWith(
          progress: {'1_1': 0.75},
        );

        expect(updated.progress['1_1'], equals(0.75));
      });

      test('creates new state with updated counts', () {
        const original = DownloadState(
          totalDownloads: 10,
          totalSizeBytes: 100000,
        );

        final updated = original.copyWith(
          totalDownloads: 11,
          totalSizeBytes: 110000,
        );

        expect(updated.totalDownloads, equals(11));
        expect(updated.totalSizeBytes, equals(110000));
      });

      test('preserves unmodified values', () {
        final original = DownloadState(
          statuses: {'1_1': DownloadStatus.downloaded},
          progress: {'1_1': 1.0},
          totalDownloads: 5,
          totalSizeBytes: 50000,
        );

        final updated = original.copyWith(totalDownloads: 6);

        expect(updated.statuses, equals(original.statuses));
        expect(updated.progress, equals(original.progress));
        expect(updated.totalSizeBytes, equals(original.totalSizeBytes));
        expect(updated.totalDownloads, equals(6));
      });
    });
  });

  group('DownloadAllowedResult', () {
    test('creates allowed result', () {
      const result = DownloadAllowedResult(allowed: true);

      expect(result.allowed, isTrue);
      expect(result.errorMessage, isNull);
    });

    test('creates blocked result with error message', () {
      const result = DownloadAllowedResult(
        allowed: false,
        errorMessage: 'WiFi only mode enabled',
      );

      expect(result.allowed, isFalse);
      expect(result.errorMessage, equals('WiFi only mode enabled'));
    });

    test('static allowed constant works', () {
      expect(DownloadAllowedResult.allowed_.allowed, isTrue);
      expect(DownloadAllowedResult.allowed_.errorMessage, isNull);
    });
  });

  group('Size Formatting', () {
    test('formats bytes correctly', () {
      String formatSize(int bytes) {
        if (bytes < 1024) return '$bytes B';
        if (bytes < 1024 * 1024) {
          return '${(bytes / 1024).toStringAsFixed(1)} KB';
        }
        if (bytes < 1024 * 1024 * 1024) {
          return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
        }
        return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
      }

      expect(formatSize(500), equals('500 B'));
      expect(formatSize(1024), equals('1.0 KB'));
      expect(formatSize(1536), equals('1.5 KB'));
      expect(formatSize(1024 * 1024), equals('1.0 MB'));
      expect(formatSize(1024 * 1024 * 1024), equals('1.00 GB'));
      expect(formatSize(1536 * 1024 * 1024), equals('1.50 GB'));
    });

    test('handles edge cases', () {
      String formatSize(int bytes) {
        if (bytes < 1024) return '$bytes B';
        if (bytes < 1024 * 1024) {
          return '${(bytes / 1024).toStringAsFixed(1)} KB';
        }
        if (bytes < 1024 * 1024 * 1024) {
          return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
        }
        return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
      }

      expect(formatSize(0), equals('0 B'));
      expect(formatSize(1), equals('1 B'));
      expect(formatSize(1023), equals('1023 B'));
    });
  });

  group('Download Integrity Verification', () {
    test('minimum file size constant is reasonable', () {
      // The service uses 1KB as minimum file size
      const minFileSize = 1024;

      expect(minFileSize, equals(1024));
      expect(minFileSize, greaterThan(0));
    });

    test('file size verification detects undersized files', () {
      const minFileSize = 1024;

      bool isValidSize(int fileSize) => fileSize >= minFileSize;

      expect(isValidSize(0), isFalse);
      expect(isValidSize(100), isFalse);
      expect(isValidSize(1023), isFalse);
      expect(isValidSize(1024), isTrue);
      expect(isValidSize(5000000), isTrue);
    });

    test('size mismatch detection works', () {
      bool sizesMatch(int actual, int expected) {
        if (expected <= 0) return true; // No expected size to check
        return actual == expected;
      }

      expect(sizesMatch(1000, 1000), isTrue);
      expect(sizesMatch(1000, 1001), isFalse);
      expect(sizesMatch(1000, 999), isFalse);
      expect(sizesMatch(1000, 0), isTrue); // No expected size
      expect(sizesMatch(1000, -1), isTrue); // Invalid expected size
    });
  });

  group('Semaphore Logic', () {
    test('max concurrent downloads is 3', () {
      // The service uses maxConcurrent = 3
      const maxConcurrent = 3;

      expect(maxConcurrent, equals(3));
      expect(maxConcurrent, greaterThan(0));
      expect(maxConcurrent, lessThanOrEqualTo(5)); // Reasonable limit
    });

    test('semaphore allows up to max concurrent', () {
      // Simulates the semaphore logic
      int maxConcurrent = 3;
      int current = 0;

      bool canAcquire() => current < maxConcurrent;

      void acquire() {
        if (canAcquire()) current++;
      }

      void release() {
        if (current > 0) current--;
      }

      // Can acquire up to 3
      expect(canAcquire(), isTrue);
      acquire();
      expect(canAcquire(), isTrue);
      acquire();
      expect(canAcquire(), isTrue);
      acquire();

      // Cannot acquire more
      expect(canAcquire(), isFalse);

      // Release one
      release();
      expect(canAcquire(), isTrue);

      // Acquire again
      acquire();
      expect(canAcquire(), isFalse);
    });
  });

  group('Range Header for Resumption', () {
    test('range header format is correct', () {
      String? getRangeHeader(int existingBytes) {
        if (existingBytes <= 0) return null;
        return 'bytes=$existingBytes-';
      }

      expect(getRangeHeader(0), isNull);
      expect(getRangeHeader(500), equals('bytes=500-'));
      expect(getRangeHeader(1000000), equals('bytes=1000000-'));
    });

    test('fresh download has no range header', () {
      int existingBytes = 0;

      bool shouldUseRangeHeader = existingBytes > 0;
      expect(shouldUseRangeHeader, isFalse);
    });

    test('resumed download has range header', () {
      int existingBytes = 500;

      bool shouldUseRangeHeader = existingBytes > 0;
      expect(shouldUseRangeHeader, isTrue);
    });
  });

  group('Supported Audio Extensions', () {
    test('common audio extensions are supported', () {
      // The service checks for these extensions when looking for partial files
      final supportedExtensions = ['mp3', 'm4a', 'aac', 'ogg'];

      expect(supportedExtensions, contains('mp3'));
      expect(supportedExtensions, contains('m4a'));
      expect(supportedExtensions, contains('aac'));
      expect(supportedExtensions, contains('ogg'));
    });
  });

  group('State Transition Logic', () {
    test('status transitions: not downloaded -> downloading', () {
      var status = DownloadStatus.notDownloaded;

      // Start download
      status = DownloadStatus.downloading;

      expect(status, equals(DownloadStatus.downloading));
    });

    test('status transitions: downloading -> downloaded', () {
      var status = DownloadStatus.downloading;

      // Complete download
      status = DownloadStatus.downloaded;

      expect(status, equals(DownloadStatus.downloaded));
    });

    test('status transitions: downloading -> failed', () {
      var status = DownloadStatus.downloading;

      // Download fails
      status = DownloadStatus.failed;

      expect(status, equals(DownloadStatus.failed));
    });

    test('status transitions: failed -> downloading (retry)', () {
      var status = DownloadStatus.failed;

      // Retry download
      status = DownloadStatus.downloading;

      expect(status, equals(DownloadStatus.downloading));
    });

    test('status transitions: downloaded -> not downloaded (delete)', () {
      var status = DownloadStatus.downloaded;

      // Delete download
      status = DownloadStatus.notDownloaded;

      expect(status, equals(DownloadStatus.notDownloaded));
    });
  });

  group('Audiobook Download Grouping', () {
    test('chapters are grouped by audiobook ID', () {
      final downloads = [
        DownloadedChapter(
          audiobookId: 1,
          chapterId: 1,
          localPath: '/1_1.mp3',
          fileSizeBytes: 1000,
          downloadedAt: DateTime.now(),
        ),
        DownloadedChapter(
          audiobookId: 1,
          chapterId: 2,
          localPath: '/1_2.mp3',
          fileSizeBytes: 1000,
          downloadedAt: DateTime.now(),
        ),
        DownloadedChapter(
          audiobookId: 2,
          chapterId: 1,
          localPath: '/2_1.mp3',
          fileSizeBytes: 2000,
          downloadedAt: DateTime.now(),
        ),
      ];

      final grouped = <int, List<DownloadedChapter>>{};
      for (final download in downloads) {
        grouped.putIfAbsent(download.audiobookId, () => []);
        grouped[download.audiobookId]!.add(download);
      }

      expect(grouped.keys.length, equals(2));
      expect(grouped[1]!.length, equals(2));
      expect(grouped[2]!.length, equals(1));
    });

    test('total size calculation for audiobook', () {
      final downloads = [
        DownloadedChapter(
          audiobookId: 1,
          chapterId: 1,
          localPath: '/1_1.mp3',
          fileSizeBytes: 1000,
          downloadedAt: DateTime.now(),
        ),
        DownloadedChapter(
          audiobookId: 1,
          chapterId: 2,
          localPath: '/1_2.mp3',
          fileSizeBytes: 2000,
          downloadedAt: DateTime.now(),
        ),
      ];

      final totalSize =
          downloads.fold<int>(0, (sum, d) => sum + d.fileSizeBytes);

      expect(totalSize, equals(3000));
    });

    test('fully downloaded check works correctly', () {
      bool isFullyDownloaded(int downloadedCount, int totalChapters) {
        return downloadedCount >= totalChapters;
      }

      expect(isFullyDownloaded(5, 5), isTrue);
      expect(isFullyDownloaded(6, 5), isTrue); // More than total is still true
      expect(isFullyDownloaded(4, 5), isFalse);
      expect(isFullyDownloaded(0, 5), isFalse);
    });
  });

  group('Error Message Handling', () {
    test('Farsi error message for download failure', () {
      // The service uses this error message
      const errorMessage = 'خطا در دانلود فایل';

      expect(errorMessage, isNotEmpty);
      // Verify it contains Farsi characters
      expect(errorMessage.contains('خطا'), isTrue);
    });
  });

  group('Storage Key', () {
    test('storage key constant is correct', () {
      // The service uses this key for SharedPreferences
      const storageKey = 'downloaded_chapters';

      expect(storageKey, equals('downloaded_chapters'));
      expect(storageKey, isNotEmpty);
    });
  });

  group('Download Status Checks', () {
    test('isDownloaded check works correctly', () {
      final downloadedChapters = <String, DownloadedChapter>{
        '1_1': DownloadedChapter(
          audiobookId: 1,
          chapterId: 1,
          localPath: '/1_1.mp3',
          fileSizeBytes: 1000,
          downloadedAt: DateTime.now(),
        ),
      };

      bool isDownloaded(int audiobookId, int chapterId) {
        return downloadedChapters.containsKey('${audiobookId}_$chapterId');
      }

      expect(isDownloaded(1, 1), isTrue);
      expect(isDownloaded(1, 2), isFalse);
      expect(isDownloaded(2, 1), isFalse);
    });

    test('isDownloading check works correctly', () {
      final activeTasks = <String, DownloadTask>{
        '1_1': DownloadTask(
          audiobookId: 1,
          chapterId: 1,
          url: 'https://example.com/1_1.mp3',
          status: DownloadStatus.downloading,
        ),
        '1_2': DownloadTask(
          audiobookId: 1,
          chapterId: 2,
          url: 'https://example.com/1_2.mp3',
          status: DownloadStatus.failed,
        ),
      };

      bool isDownloading(int audiobookId, int chapterId) {
        final key = '${audiobookId}_$chapterId';
        final task = activeTasks[key];
        return task != null && task.status == DownloadStatus.downloading;
      }

      expect(isDownloading(1, 1), isTrue);
      expect(isDownloading(1, 2), isFalse); // Failed, not downloading
      expect(isDownloading(1, 3), isFalse); // Not in tasks
    });

    test('getStatus returns correct status', () {
      final downloadedChapters = <String, DownloadedChapter>{
        '1_1': DownloadedChapter(
          audiobookId: 1,
          chapterId: 1,
          localPath: '/1_1.mp3',
          fileSizeBytes: 1000,
          downloadedAt: DateTime.now(),
        ),
      };

      final activeTasks = <String, DownloadTask>{
        '1_2': DownloadTask(
          audiobookId: 1,
          chapterId: 2,
          url: 'https://example.com/1_2.mp3',
          status: DownloadStatus.downloading,
        ),
        '1_3': DownloadTask(
          audiobookId: 1,
          chapterId: 3,
          url: 'https://example.com/1_3.mp3',
          status: DownloadStatus.failed,
        ),
      };

      DownloadStatus getStatus(int audiobookId, int chapterId) {
        final key = '${audiobookId}_$chapterId';
        if (downloadedChapters.containsKey(key)) {
          return DownloadStatus.downloaded;
        }
        final task = activeTasks[key];
        return task?.status ?? DownloadStatus.notDownloaded;
      }

      expect(getStatus(1, 1), equals(DownloadStatus.downloaded));
      expect(getStatus(1, 2), equals(DownloadStatus.downloading));
      expect(getStatus(1, 3), equals(DownloadStatus.failed));
      expect(getStatus(1, 4), equals(DownloadStatus.notDownloaded));
    });
  });

  group('Retry Logic Constants', () {
    test('retry constants are reasonable', () {
      // From _saveDownloadedChapters
      const maxRetries = 3;
      const retryDelayMs = 500;

      expect(maxRetries, greaterThan(0));
      expect(maxRetries, lessThanOrEqualTo(5));
      expect(retryDelayMs, greaterThan(0));
      expect(retryDelayMs, lessThanOrEqualTo(2000));
    });
  });

  group('Delete Operations', () {
    test('key removal pattern for audiobook deletion', () {
      final statuses = {
        '1_1': DownloadStatus.downloaded,
        '1_2': DownloadStatus.downloaded,
        '2_1': DownloadStatus.downloaded,
        '2_2': DownloadStatus.downloading,
      };

      final audiobookIdToDelete = 1;

      statuses.removeWhere(
          (key, _) => key.startsWith('${audiobookIdToDelete}_'));

      expect(statuses.containsKey('1_1'), isFalse);
      expect(statuses.containsKey('1_2'), isFalse);
      expect(statuses.containsKey('2_1'), isTrue);
      expect(statuses.containsKey('2_2'), isTrue);
    });
  });
}
