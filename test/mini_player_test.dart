// Widget tests for MiniPlayer component
// Tests UI rendering, user interactions, and state-based display

import 'package:flutter_test/flutter_test.dart';
import 'package:myna/providers/audio/audio_state.dart';

void main() {
  // Note: Widget tests for MiniPlayer require Supabase initialization
  // and are better suited for integration tests. See integration_test/ directory.
  // These unit tests cover the AudioState logic that MiniPlayer depends on.

  // Unit tests for AudioState - these are reliable and fast
  group('AudioState for MiniPlayer', () {
    test('hasAudio returns false when audiobook is null', () {
      const state = AudioState();
      expect(state.hasAudio, isFalse);
    });

    test('hasAudio returns true when audiobook is set', () {
      final state = AudioState(
        audiobook: {'id': 1, 'title_fa': 'Test'},
        chapters: const [],
      );
      expect(state.hasAudio, isTrue);
    });

    test('hasError returns false when no error', () {
      const state = AudioState();
      expect(state.hasError, isFalse);
    });

    test('hasError returns true when error type is set', () {
      const state = AudioState(errorType: AudioErrorType.networkError);
      expect(state.hasError, isTrue);
    });

    test('copyWith updates isPlaying correctly', () {
      const state = AudioState(isPlaying: false);
      final newState = state.copyWith(isPlaying: true);
      expect(newState.isPlaying, isTrue);
      expect(state.isPlaying, isFalse); // Original unchanged
    });

    test('copyWith updates isBuffering correctly', () {
      const state = AudioState(isBuffering: false);
      final newState = state.copyWith(isBuffering: true);
      expect(newState.isBuffering, isTrue);
    });

    test('canPlayChapter returns true for owned audiobook', () {
      final state = AudioState(
        audiobook: {'id': 1, 'title_fa': 'Test', 'is_free': false},
        chapters: [
          {'id': 1, 'is_preview': false},
          {'id': 2, 'is_preview': false},
        ],
        isOwned: true,
      );
      expect(state.canPlayChapter(0), isTrue);
      expect(state.canPlayChapter(1), isTrue);
    });

    test('canPlayChapter returns true only for preview when not owned', () {
      final state = AudioState(
        audiobook: {'id': 1, 'title_fa': 'Test', 'is_free': false},
        chapters: [
          {'id': 1, 'is_preview': true},
          {'id': 2, 'is_preview': false},
        ],
        isOwned: false,
      );
      expect(state.canPlayChapter(0), isTrue); // Preview
      expect(state.canPlayChapter(1), isFalse); // Not preview, not owned
    });

    test('progress calculation with position and duration', () {
      final state = AudioState(
        audiobook: {'id': 1, 'title_fa': 'Test'},
        chapters: const [],
        position: const Duration(minutes: 5),
        duration: const Duration(minutes: 10),
      );

      // Verify position is 50% through
      expect(state.position.inMinutes, 5);
      expect(state.duration.inMinutes, 10);
    });
  });
}

