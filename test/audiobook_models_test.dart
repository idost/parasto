// Unit tests for audiobook models.
// Tests type safety, JSON parsing, and computed properties.

import 'package:flutter_test/flutter_test.dart';
import 'package:myna/models/audiobook.dart';

void main() {
  group('Audiobook', () {
    test('fromJson parses complete audiobook data', () {
      final json = {
        'id': 123,
        'title_fa': 'کتاب صوتی تست',
        'title_en': 'Test Audiobook',
        'author_fa': 'نویسنده تست',
        'cover_url': 'https://example.com/cover.jpg',
        'price_toman': 50000,
        'is_free': false,
        'is_featured': true,
        'is_music': false,
        'is_podcast': false,
        'status': 'published',
        'total_duration_seconds': 7200,
        'chapter_count': 10,
        'play_count': 500,
        'avg_rating': 4.5,
        'review_count': 25,
        'created_at': '2024-01-01T00:00:00Z',
        'categories': {'id': 1, 'name_fa': 'داستان'},
      };

      final audiobook = Audiobook.fromJson(json);

      expect(audiobook.id, equals(123));
      expect(audiobook.titleFa, equals('کتاب صوتی تست'));
      expect(audiobook.titleEn, equals('Test Audiobook'));
      expect(audiobook.authorFa, equals('نویسنده تست'));
      expect(audiobook.priceToman, equals(50000));
      expect(audiobook.isFree, isFalse);
      expect(audiobook.isFeatured, isTrue);
      expect(audiobook.isMusic, isFalse);
      expect(audiobook.status, equals('published'));
      expect(audiobook.totalDurationSeconds, equals(7200));
      expect(audiobook.chapterCount, equals(10));
      expect(audiobook.avgRating, equals(4.5));
      expect(audiobook.categoryName, equals('داستان'));
      expect(audiobook.categoryId, equals(1));
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 1,
        'title_fa': 'Minimal Book',
        'price_toman': 0,
        'is_free': true,
        'is_featured': false,
        'status': 'draft',
        'total_duration_seconds': 0,
        'chapter_count': 0,
        'play_count': 0,
        'avg_rating': 0,
        'review_count': 0,
        'created_at': '2024-01-01T00:00:00Z',
      };

      final audiobook = Audiobook.fromJson(json);

      expect(audiobook.id, equals(1));
      expect(audiobook.titleEn, isNull);
      expect(audiobook.authorFa, isNull);
      expect(audiobook.coverUrl, isNull);
      expect(audiobook.categoryName, isNull);
    });

    test('contentType returns correct type for audiobook', () {
      final audiobook = Audiobook.fromJson({
        'id': 1,
        'title_fa': 'Test',
        'price_toman': 0,
        'is_free': true,
        'is_featured': false,
        'is_music': false,
        'is_podcast': false,
        'status': 'published',
        'total_duration_seconds': 0,
        'chapter_count': 0,
        'play_count': 0,
        'avg_rating': 0,
        'review_count': 0,
        'created_at': '2024-01-01T00:00:00Z',
      });

      expect(audiobook.contentType, equals('audiobook'));
    });

    test('contentType returns correct type for music', () {
      final music = Audiobook.fromJson({
        'id': 1,
        'title_fa': 'Test Music',
        'price_toman': 0,
        'is_free': true,
        'is_featured': false,
        'content_type': 'music',
        'status': 'published',
        'total_duration_seconds': 0,
        'chapter_count': 0,
        'play_count': 0,
        'avg_rating': 0,
        'review_count': 0,
        'created_at': '2024-01-01T00:00:00Z',
      });

      expect(music.contentType, equals('music'));
    });

    test('contentType returns correct type for podcast', () {
      final podcast = Audiobook.fromJson({
        'id': 1,
        'title_fa': 'Test Podcast',
        'price_toman': 0,
        'is_free': true,
        'is_featured': false,
        'content_type': 'podcast',
        'status': 'published',
        'total_duration_seconds': 0,
        'chapter_count': 0,
        'play_count': 0,
        'avg_rating': 0,
        'review_count': 0,
        'created_at': '2024-01-01T00:00:00Z',
      });

      expect(podcast.contentType, equals('podcast'));
    });

    test('formattedPrice returns رایگان for free content', () {
      final audiobook = Audiobook.fromJson({
        'id': 1,
        'title_fa': 'Free Book',
        'price_toman': 0,
        'is_free': true,
        'is_featured': false,
        'status': 'published',
        'total_duration_seconds': 0,
        'chapter_count': 0,
        'play_count': 0,
        'avg_rating': 0,
        'review_count': 0,
        'created_at': '2024-01-01T00:00:00Z',
      });

      expect(audiobook.formattedPrice, equals('رایگان'));
    });

    test('isPublished returns true for published status', () {
      final published = Audiobook.fromJson({
        'id': 1,
        'title_fa': 'Published',
        'price_toman': 0,
        'is_free': true,
        'is_featured': false,
        'status': 'published',
        'total_duration_seconds': 0,
        'chapter_count': 0,
        'play_count': 0,
        'avg_rating': 0,
        'review_count': 0,
        'created_at': '2024-01-01T00:00:00Z',
      });

      final draft = Audiobook.fromJson({
        'id': 2,
        'title_fa': 'Draft',
        'price_toman': 0,
        'is_free': true,
        'is_featured': false,
        'status': 'draft',
        'total_duration_seconds': 0,
        'chapter_count': 0,
        'play_count': 0,
        'avg_rating': 0,
        'review_count': 0,
        'created_at': '2024-01-01T00:00:00Z',
      });

      expect(published.isPublished, isTrue);
      expect(draft.isPublished, isFalse);
    });

    test('toJson produces valid JSON', () {
      final audiobook = Audiobook.fromJson({
        'id': 100,
        'title_fa': 'Test',
        'title_en': 'Test EN',
        'price_toman': 10000,
        'is_free': false,
        'is_featured': true,
        'status': 'published',
        'total_duration_seconds': 3600,
        'chapter_count': 5,
        'play_count': 100,
        'avg_rating': 4.0,
        'review_count': 10,
        'created_at': '2024-01-01T00:00:00Z',
      });

      final json = audiobook.toJson();

      expect(json['id'], equals(100));
      expect(json['title_fa'], equals('Test'));
      expect(json['title_en'], equals('Test EN'));
      expect(json['is_featured'], isTrue);
    });
  });

  group('Chapter', () {
    test('fromJson parses chapter data', () {
      final json = {
        'id': 1,
        'audiobook_id': 100,
        'title_fa': 'فصل اول',
        'title_en': 'Chapter One',
        'chapter_index': 0,
        'audio_storage_path': 'audio/ch1.mp3',
        'audio_url': 'https://example.com/ch1.mp3',
        'duration_seconds': 1800,
        'is_preview': true,
        'created_at': '2024-01-01T00:00:00Z',
      };

      final chapter = Chapter.fromJson(json);

      expect(chapter.id, equals(1));
      expect(chapter.audiobookId, equals(100));
      expect(chapter.titleFa, equals('فصل اول'));
      expect(chapter.chapterIndex, equals(0));
      expect(chapter.durationSeconds, equals(1800));
      expect(chapter.isPreview, isTrue);
    });

    test('duration returns correct Duration', () {
      final chapter = Chapter.fromJson({
        'id': 1,
        'audiobook_id': 1,
        'title_fa': 'Test',
        'chapter_index': 0,
        'duration_seconds': 3661,
        'is_preview': false,
        'created_at': '2024-01-01T00:00:00Z',
      });

      expect(chapter.duration, equals(const Duration(seconds: 3661)));
      expect(chapter.duration.inMinutes, equals(61));
    });
  });

  group('AudiobookProgress', () {
    test('fromJson parses progress data', () {
      final json = {
        'user_id': 'user_123',
        'audiobook_id': 456,
        'current_chapter_index': 3,
        'position_seconds': 1200,
        'completion_percentage': 45,
        'is_completed': false,
        'last_played_at': '2024-01-15T10:30:00Z',
      };

      final progress = AudiobookProgress.fromJson(json);

      expect(progress.odId, equals('user_123'));
      expect(progress.audiobookId, equals(456));
      expect(progress.currentChapterIndex, equals(3));
      expect(progress.positionSeconds, equals(1200));
      expect(progress.completionPercentage, equals(45));
      expect(progress.isCompleted, isFalse);
      expect(progress.lastPlayedAt, isNotNull);
    });

    test('position returns correct Duration', () {
      final progress = AudiobookProgress.fromJson({
        'user_id': 'user_1',
        'audiobook_id': 1,
        'current_chapter_index': 0,
        'position_seconds': 300,
        'completion_percentage': 10,
        'is_completed': false,
      });

      expect(progress.position, equals(const Duration(seconds: 300)));
      expect(progress.position.inMinutes, equals(5));
    });
  });

  group('ChapterProgress', () {
    test('fromJson parses chapter progress', () {
      final json = {
        'user_id': 'user_abc',
        'chapter_id': 789,
        'position_seconds': 600,
        'is_completed': true,
        'updated_at': '2024-01-20T15:00:00Z',
      };

      final progress = ChapterProgress.fromJson(json);

      expect(progress.odId, equals('user_abc'));
      expect(progress.chapterId, equals(789));
      expect(progress.positionSeconds, equals(600));
      expect(progress.isCompleted, isTrue);
      expect(progress.updatedAt, isNotNull);
    });

    test('toJson produces valid JSON', () {
      final progress = ChapterProgress(
        odId: 'user_1',
        chapterId: 100,
        positionSeconds: 450,
        isCompleted: false,
      );

      final json = progress.toJson();

      expect(json['user_id'], equals('user_1'));
      expect(json['chapter_id'], equals(100));
      expect(json['position_seconds'], equals(450));
      expect(json['is_completed'], isFalse);
    });
  });
}
