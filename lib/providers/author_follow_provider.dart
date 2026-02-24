import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:myna/utils/app_logger.dart';

/// Represents a followed author
class FollowedAuthor {
  final String authorName;
  final DateTime followedAt;

  const FollowedAuthor({
    required this.authorName,
    required this.followedAt,
  });

  Map<String, dynamic> toJson() => {
        'authorName': authorName,
        'followedAt': followedAt.toIso8601String(),
      };

  factory FollowedAuthor.fromJson(Map<String, dynamic> json) => FollowedAuthor(
        authorName: json['authorName'] as String,
        followedAt: DateTime.parse(json['followedAt'] as String),
      );
}

/// State for author following
class AuthorFollowState {
  final Set<String> followedAuthors;
  final bool isLoading;

  const AuthorFollowState({
    this.followedAuthors = const {},
    this.isLoading = false,
  });

  bool isFollowing(String authorName) {
    if (authorName.isEmpty) return false;
    return followedAuthors.contains(authorName.toLowerCase().trim());
  }

  AuthorFollowState copyWith({
    Set<String>? followedAuthors,
    bool? isLoading,
  }) {
    return AuthorFollowState(
      followedAuthors: followedAuthors ?? this.followedAuthors,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Notifier for managing author follows
/// Stores follows locally (SharedPreferences) for simplicity
/// Could be extended to sync with Supabase if needed
class AuthorFollowNotifier extends StateNotifier<AuthorFollowState> {
  AuthorFollowNotifier() : super(const AuthorFollowState(isLoading: true)) {
    _loadFollows();
  }

  static const _storageKey = 'followed_authors';

  Future<void> _loadFollows() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);

      if (jsonString != null) {
        final jsonList = json.decode(jsonString) as List<dynamic>;
        final authors = jsonList
            .map((j) => FollowedAuthor.fromJson(j as Map<String, dynamic>))
            .map((a) => a.authorName.toLowerCase().trim())
            .toSet();
        state = AuthorFollowState(followedAuthors: authors);
      } else {
        state = const AuthorFollowState();
      }
      AppLogger.d('AUTHOR_FOLLOW: Loaded ${state.followedAuthors.length} followed authors');
    } catch (e) {
      AppLogger.e('Failed to load followed authors', error: e);
      state = const AuthorFollowState();
    }
  }

  Future<void> _saveFollows() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final followsList = state.followedAuthors
          .map((name) => FollowedAuthor(
                authorName: name,
                followedAt: DateTime.now(),
              ).toJson())
          .toList();
      await prefs.setString(_storageKey, json.encode(followsList));
    } catch (e) {
      AppLogger.e('Failed to save followed authors', error: e);
    }
  }

  /// Follow an author
  void follow(String authorName) {
    if (authorName.isEmpty) return;
    final normalized = authorName.toLowerCase().trim();
    if (state.followedAuthors.contains(normalized)) return;

    state = state.copyWith(
      followedAuthors: {...state.followedAuthors, normalized},
    );
    _saveFollows();
    AppLogger.d('AUTHOR_FOLLOW: Now following "$authorName"');
  }

  /// Unfollow an author
  void unfollow(String authorName) {
    if (authorName.isEmpty) return;
    final normalized = authorName.toLowerCase().trim();
    if (!state.followedAuthors.contains(normalized)) return;

    final newSet = Set<String>.from(state.followedAuthors)..remove(normalized);
    state = state.copyWith(followedAuthors: newSet);
    _saveFollows();
    AppLogger.d('AUTHOR_FOLLOW: Unfollowed "$authorName"');
  }

  /// Toggle follow status
  void toggle(String authorName) {
    if (state.isFollowing(authorName)) {
      unfollow(authorName);
    } else {
      follow(authorName);
    }
  }
}

/// Provider for author follow state
final authorFollowProvider =
    StateNotifierProvider<AuthorFollowNotifier, AuthorFollowState>((ref) {
  return AuthorFollowNotifier();
});

/// Provider for "New from Authors You Follow" section
/// Fetches recent audiobooks from followed authors
final newFromFollowedAuthorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final followState = ref.watch(authorFollowProvider);

  if (followState.followedAuthors.isEmpty) return [];

  final user = Supabase.instance.client.auth.currentUser;

  try {
    // Get user's owned audiobook IDs to filter them out
    Set<int> ownedIds = {};
    if (user != null) {
      final entitlements = await Supabase.instance.client
          .from('entitlements')
          .select('audiobook_id')
          .eq('user_id', user.id);
      ownedIds = (entitlements as List)
          .map((e) => e['audiobook_id'] as int)
          .toSet();
    }

    // Fetch recent audiobooks from followed authors
    // Note: Supabase doesn't support case-insensitive IN filter easily,
    // so we'll fetch more and filter client-side
    final response = await Supabase.instance.client
        .from('audiobooks')
        .select('id, title_fa, title_en, cover_url, author_fa, avg_rating, play_count, created_at, is_music, status')
        .eq('status', 'approved')
        .eq('is_music', false)
        .order('created_at', ascending: false)
        .limit(50); // Fetch more to find matches

    final books = (response as List)
        .map((b) => Map<String, dynamic>.from(b as Map))
        .where((b) {
          final author = (b['author_fa'] as String?)?.toLowerCase().trim() ?? '';
          return followState.followedAuthors.contains(author);
        })
        .where((b) => !ownedIds.contains(b['id'] as int))
        .take(10)
        .toList();

    AppLogger.d('NEW_FROM_FOLLOWED: Found ${books.length} books from followed authors');
    return books;
  } catch (e) {
    AppLogger.e('Error fetching new from followed authors', error: e);
    return [];
  }
});
