import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myna/utils/app_logger.dart';

/// Content types available in the app
enum ContentType {
  audiobook,
  podcast,
  ebook,
  music,
}

/// User's content type preferences for filtering the home feed
/// Stored locally using SharedPreferences
class ContentPreferences {
  final bool showAudiobooks;
  final bool showPodcasts;
  final bool showEbooks;
  final bool showMusic;

  const ContentPreferences({
    this.showAudiobooks = true,
    this.showPodcasts = true,
    this.showEbooks = true,
    this.showMusic = true,
  });

  /// Check if a content type should be shown
  bool shouldShow(ContentType type) {
    switch (type) {
      case ContentType.audiobook:
        return showAudiobooks;
      case ContentType.podcast:
        return showPodcasts;
      case ContentType.ebook:
        return showEbooks;
      case ContentType.music:
        return showMusic;
    }
  }

  /// Check if a content type string should be shown
  bool shouldShowString(String? type) {
    switch (type) {
      case 'audiobook':
        return showAudiobooks;
      case 'podcast':
        return showPodcasts;
      case 'ebook':
        return showEbooks;
      case 'music':
        return showMusic;
      default:
        return showAudiobooks; // Default to audiobook behavior
    }
  }

  /// Returns true if all content types are enabled (no filtering needed)
  bool get showAll => showAudiobooks && showPodcasts && showEbooks && showMusic;

  /// Returns true if at least one content type is enabled
  bool get hasAnyEnabled => showAudiobooks || showPodcasts || showEbooks || showMusic;

  /// Returns list of enabled content types for database queries
  List<String> get enabledTypes {
    final types = <String>[];
    if (showAudiobooks) types.add('audiobook');
    if (showPodcasts) types.add('podcast');
    if (showEbooks) types.add('ebook');
    if (showMusic) types.add('music');
    return types;
  }

  ContentPreferences copyWith({
    bool? showAudiobooks,
    bool? showPodcasts,
    bool? showEbooks,
    bool? showMusic,
  }) {
    return ContentPreferences(
      showAudiobooks: showAudiobooks ?? this.showAudiobooks,
      showPodcasts: showPodcasts ?? this.showPodcasts,
      showEbooks: showEbooks ?? this.showEbooks,
      showMusic: showMusic ?? this.showMusic,
    );
  }

  @override
  String toString() {
    return 'ContentPreferences(audiobooks: $showAudiobooks, podcasts: $showPodcasts, ebooks: $showEbooks, music: $showMusic)';
  }
}

/// Notifier for managing content preferences
class ContentPreferenceNotifier extends StateNotifier<ContentPreferences> {
  ContentPreferenceNotifier() : super(const ContentPreferences()) {
    _loadPreferences();
  }

  static const _keyAudiobooks = 'pref_show_audiobooks';
  static const _keyPodcasts = 'pref_show_podcasts';
  static const _keyEbooks = 'pref_show_ebooks';
  static const _keyMusic = 'pref_show_music';

  /// Load preferences from SharedPreferences
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = ContentPreferences(
        showAudiobooks: prefs.getBool(_keyAudiobooks) ?? true,
        showPodcasts: prefs.getBool(_keyPodcasts) ?? true,
        showEbooks: prefs.getBool(_keyEbooks) ?? true,
        showMusic: prefs.getBool(_keyMusic) ?? true,
      );
      AppLogger.d('Content preferences loaded: $state');
    } catch (e) {
      AppLogger.e('Failed to load content preferences', error: e);
    }
  }

  /// Save preferences to SharedPreferences
  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAudiobooks, state.showAudiobooks);
      await prefs.setBool(_keyPodcasts, state.showPodcasts);
      await prefs.setBool(_keyEbooks, state.showEbooks);
      await prefs.setBool(_keyMusic, state.showMusic);
      AppLogger.d('Content preferences saved: $state');
    } catch (e) {
      AppLogger.e('Failed to save content preferences', error: e);
    }
  }

  /// Toggle a specific content type
  void toggle(ContentType type) {
    switch (type) {
      case ContentType.audiobook:
        state = state.copyWith(showAudiobooks: !state.showAudiobooks);
        break;
      case ContentType.podcast:
        state = state.copyWith(showPodcasts: !state.showPodcasts);
        break;
      case ContentType.ebook:
        state = state.copyWith(showEbooks: !state.showEbooks);
        break;
      case ContentType.music:
        state = state.copyWith(showMusic: !state.showMusic);
        break;
    }
    _savePreferences();
  }

  /// Set a specific content type preference
  void setPreference(ContentType type, bool value) {
    switch (type) {
      case ContentType.audiobook:
        state = state.copyWith(showAudiobooks: value);
        break;
      case ContentType.podcast:
        state = state.copyWith(showPodcasts: value);
        break;
      case ContentType.ebook:
        state = state.copyWith(showEbooks: value);
        break;
      case ContentType.music:
        state = state.copyWith(showMusic: value);
        break;
    }
    _savePreferences();
  }

  /// Reset to default (show all)
  void resetToDefault() {
    state = const ContentPreferences();
    _savePreferences();
  }

  /// Set all preferences at once
  void setAll({
    required bool audiobooks,
    required bool podcasts,
    required bool ebooks,
    required bool music,
  }) {
    state = ContentPreferences(
      showAudiobooks: audiobooks,
      showPodcasts: podcasts,
      showEbooks: ebooks,
      showMusic: music,
    );
    _savePreferences();
  }
}

/// Provider for content type preferences
final contentPreferenceProvider =
    StateNotifierProvider<ContentPreferenceNotifier, ContentPreferences>((ref) {
  return ContentPreferenceNotifier();
});
