// Unit tests for AudioState class in audio_provider.dart
// Tests pure logic: chapter access control, state transitions, computed properties.
// No mocking needed - these are deterministic, fast tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:myna/providers/audio_provider.dart';

void main() {
  group('AudioState', () {
    group('canPlayChapter', () {
      test('returns true for preview chapters when not owned', () {
        // GIVEN: User doesn't own the audiobook, chapter 0 is preview
        final state = AudioState(
          audiobook: {'id': 1, 'title_fa': 'Test Book', 'is_free': false},
          chapters: [
            {'id': 1, 'title_fa': 'فصل ۱', 'is_preview': true},
            {'id': 2, 'title_fa': 'فصل ۲', 'is_preview': false},
            {'id': 3, 'title_fa': 'فصل ۳', 'is_preview': false},
          ],
          isOwned: false,
        );

        // WHEN/THEN: Only preview chapter is playable
        expect(state.canPlayChapter(0), isTrue, reason: 'Preview chapter should be playable');
        expect(state.canPlayChapter(1), isFalse, reason: 'Non-preview chapter should be locked');
        expect(state.canPlayChapter(2), isFalse, reason: 'Non-preview chapter should be locked');
      });

      test('returns true for all chapters when owned', () {
        // GIVEN: User owns the audiobook
        final state = AudioState(
          audiobook: {'id': 1, 'title_fa': 'Test Book', 'is_free': false},
          chapters: [
            {'id': 1, 'title_fa': 'فصل ۱', 'is_preview': true},
            {'id': 2, 'title_fa': 'فصل ۲', 'is_preview': false},
            {'id': 3, 'title_fa': 'فصل ۳', 'is_preview': false},
          ],
          isOwned: true,
        );

        // WHEN/THEN: All chapters are playable
        expect(state.canPlayChapter(0), isTrue);
        expect(state.canPlayChapter(1), isTrue);
        expect(state.canPlayChapter(2), isTrue);
      });

      test('returns true for all chapters when audiobook is free and user has subscription', () {
        // GIVEN: Audiobook is free (is_free=true), user doesn't own it but has active subscription
        // Free audiobooks require an active subscription (AccessGateService policy)
        final state = AudioState(
          audiobook: {'id': 1, 'title_fa': 'Free Book', 'is_free': true},
          chapters: [
            {'id': 1, 'title_fa': 'فصل ۱', 'is_preview': false},
            {'id': 2, 'title_fa': 'فصل ۲', 'is_preview': false},
            {'id': 3, 'title_fa': 'فصل ۳', 'is_preview': false},
          ],
          isOwned: false,
          isSubscriptionActive: true,
        );

        expect(state.canPlayChapter(0), isTrue, reason: 'Free book + active subscription should be playable');
        expect(state.canPlayChapter(1), isTrue, reason: 'Free book + active subscription should be playable');
        expect(state.canPlayChapter(2), isTrue, reason: 'Free book + active subscription should be playable');
      });

      test('returns false for free book chapters without subscription', () {
        // Free audiobooks require subscription — no subscription means locked
        final state = AudioState(
          audiobook: {'id': 1, 'title_fa': 'Free Book', 'is_free': true},
          chapters: [
            {'id': 1, 'title_fa': 'فصل ۱', 'is_preview': false},
          ],
          isOwned: false,
          isSubscriptionActive: false,
        );

        expect(state.canPlayChapter(0), isFalse, reason: 'Free book without subscription should be locked');
      });

      test('returns false for invalid chapter indices', () {
        final state = AudioState(
          audiobook: {'id': 1, 'title_fa': 'Test Book'},
          chapters: [
            {'id': 1, 'title_fa': 'فصل ۱', 'is_preview': true},
          ],
          isOwned: false,
        );

        // Negative index
        expect(state.canPlayChapter(-1), isFalse);
        // Index out of bounds
        expect(state.canPlayChapter(1), isFalse);
        expect(state.canPlayChapter(100), isFalse);
      });

      test('returns true when owned even with out-of-bounds index', () {
        // NOTE: When isOwned=true, canPlayChapter returns true immediately
        // without checking the index. This is the current behavior.
        // The bounds check only happens for non-owned audiobooks.
        final state = AudioState(
          audiobook: {'id': 1, 'title_fa': 'Empty Book'},
          chapters: [],
          isOwned: true,
        );

        // Owned = always true (bounds check skipped)
        expect(state.canPlayChapter(0), isTrue);
        expect(state.canPlayChapter(100), isTrue);
      });

      test('returns false for out-of-bounds index when not owned', () {
        final state = AudioState(
          audiobook: {'id': 1, 'title_fa': 'Empty Book', 'is_free': false},
          chapters: [],
          isOwned: false,
        );

        // Not owned + empty chapters = false
        expect(state.canPlayChapter(0), isFalse);
      });
    });

    group('hasNextPlayableChapter', () {
      test('returns true when next chapter is preview and not owned', () {
        final state = AudioState(
          audiobook: {'id': 1, 'is_free': false},
          chapters: [
            {'id': 1, 'is_preview': true},
            {'id': 2, 'is_preview': true}, // Next is also preview
          ],
          currentChapterIndex: 0,
          isOwned: false,
        );

        expect(state.hasNextPlayableChapter, isTrue);
      });

      test('returns false when next chapter is locked', () {
        final state = AudioState(
          audiobook: {'id': 1, 'is_free': false},
          chapters: [
            {'id': 1, 'is_preview': true},
            {'id': 2, 'is_preview': false}, // Next is locked
          ],
          currentChapterIndex: 0,
          isOwned: false,
        );

        expect(state.hasNextPlayableChapter, isFalse);
      });

      test('returns true when owned regardless of preview status', () {
        final state = AudioState(
          audiobook: {'id': 1, 'is_free': false},
          chapters: [
            {'id': 1, 'is_preview': true},
            {'id': 2, 'is_preview': false},
          ],
          currentChapterIndex: 0,
          isOwned: true,
        );

        expect(state.hasNextPlayableChapter, isTrue);
      });

      test('returns false when on last chapter', () {
        final state = AudioState(
          audiobook: {'id': 1},
          chapters: [
            {'id': 1, 'is_preview': true},
            {'id': 2, 'is_preview': true},
          ],
          currentChapterIndex: 1, // Last chapter
          isOwned: true,
        );

        expect(state.hasNextPlayableChapter, isFalse);
      });
    });

    group('hasPreviousPlayableChapter', () {
      test('returns true when previous chapter exists and is playable', () {
        final state = AudioState(
          audiobook: {'id': 1, 'is_free': false},
          chapters: [
            {'id': 1, 'is_preview': true},
            {'id': 2, 'is_preview': true},
          ],
          currentChapterIndex: 1,
          isOwned: false,
        );

        expect(state.hasPreviousPlayableChapter, isTrue);
      });

      test('returns false when on first chapter', () {
        final state = AudioState(
          audiobook: {'id': 1},
          chapters: [
            {'id': 1, 'is_preview': true},
            {'id': 2, 'is_preview': true},
          ],
          currentChapterIndex: 0,
          isOwned: true,
        );

        expect(state.hasPreviousPlayableChapter, isFalse);
      });

      test('returns false when previous chapter is locked', () {
        // Edge case: somehow user is on chapter 1, but chapter 0 is locked
        // (could happen with direct deep links)
        final state = AudioState(
          audiobook: {'id': 1, 'is_free': false},
          chapters: [
            {'id': 1, 'is_preview': false}, // Locked
            {'id': 2, 'is_preview': true},
          ],
          currentChapterIndex: 1,
          isOwned: false,
        );

        expect(state.hasPreviousPlayableChapter, isFalse);
      });
    });

    group('computed properties', () {
      test('hasAudio returns true when audiobook is set', () {
        final stateWithAudio = AudioState(
          audiobook: {'id': 1, 'title_fa': 'Test'},
        );
        final stateWithoutAudio = const AudioState();

        expect(stateWithAudio.hasAudio, isTrue);
        expect(stateWithoutAudio.hasAudio, isFalse);
      });

      test('hasError returns true when errorType is not none', () {
        final stateWithError = const AudioState(
          errorType: AudioErrorType.unauthorized,
          errorMessage: 'Test error',
        );
        final stateWithoutError = const AudioState();

        expect(stateWithError.hasError, isTrue);
        expect(stateWithoutError.hasError, isFalse);
      });

      test('hasSleepTimer returns true when sleepTimerMode is not off', () {
        final timedTimer = const AudioState(
          sleepTimerMode: SleepTimerMode.timed,
          sleepTimerRemaining: Duration(minutes: 30),
        );
        final endOfChapterTimer = const AudioState(
          sleepTimerMode: SleepTimerMode.endOfChapter,
        );
        final noTimer = const AudioState(
          sleepTimerMode: SleepTimerMode.off,
        );

        expect(timedTimer.hasSleepTimer, isTrue);
        expect(endOfChapterTimer.hasSleepTimer, isTrue);
        expect(noTimer.hasSleepTimer, isFalse);
      });
    });

    group('copyWith', () {
      test('creates new state with updated values', () {
        const original = AudioState(
          isPlaying: false,
          playbackSpeed: 1.0,
          currentChapterIndex: 0,
        );

        final updated = original.copyWith(
          isPlaying: true,
          playbackSpeed: 1.5,
          currentChapterIndex: 2,
        );

        // Original unchanged
        expect(original.isPlaying, isFalse);
        expect(original.playbackSpeed, 1.0);
        expect(original.currentChapterIndex, 0);

        // Updated has new values
        expect(updated.isPlaying, isTrue);
        expect(updated.playbackSpeed, 1.5);
        expect(updated.currentChapterIndex, 2);
      });

      test('preserves unset values', () {
        final original = AudioState(
          audiobook: {'id': 1, 'title_fa': 'Test'},
          isPlaying: true,
          playbackSpeed: 1.5,
        );

        final updated = original.copyWith(isPlaying: false);

        expect(updated.audiobook, original.audiobook);
        expect(updated.playbackSpeed, 1.5);
        expect(updated.isPlaying, isFalse);
      });

    });

    group('clearError', () {
      test('resets error state while preserving other values', () {
        final withError = AudioState(
          audiobook: {'id': 1, 'title_fa': 'Test'},
          isPlaying: true,
          errorType: AudioErrorType.unauthorized,
          errorMessage: 'فصل قفل است',
        );

        final cleared = withError.clearError();

        expect(cleared.errorType, AudioErrorType.none);
        expect(cleared.errorMessage, isNull);
        // Other state preserved
        expect(cleared.audiobook, withError.audiobook);
        expect(cleared.isPlaying, isTrue);
      });
    });
  });

  group('SleepTimerMode', () {
    test('enum values exist', () {
      expect(SleepTimerMode.values, contains(SleepTimerMode.off));
      expect(SleepTimerMode.values, contains(SleepTimerMode.timed));
      expect(SleepTimerMode.values, contains(SleepTimerMode.endOfChapter));
    });
  });

  group('AudioErrorType', () {
    test('enum values exist', () {
      expect(AudioErrorType.values, contains(AudioErrorType.none));
      expect(AudioErrorType.values, contains(AudioErrorType.networkError));
      expect(AudioErrorType.values, contains(AudioErrorType.audioNotFound));
      expect(AudioErrorType.values, contains(AudioErrorType.playbackFailed));
      expect(AudioErrorType.values, contains(AudioErrorType.unauthorized));
    });
  });
}
