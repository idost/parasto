import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/utils/app_logger.dart';

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
/// Persists to Supabase author_follows table (user_id, author_name, followed_at)
class AuthorFollowNotifier extends StateNotifier<AuthorFollowState> {
  AuthorFollowNotifier(Ref ref) : super(const AuthorFollowState(isLoading: true)) {
    _loadFollows();
  }

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<void> _loadFollows() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      state = const AuthorFollowState();
      return;
    }

    try {
      final rows = await _supabase
          .from('author_follows')
          .select('author_name')
          .eq('user_id', user.id);

      final authors = (rows as List)
          .map((r) => ((r['author_name'] as String?) ?? '').toLowerCase().trim())
          .where((name) => name.isNotEmpty)
          .toSet();

      state = AuthorFollowState(followedAuthors: authors);
      AppLogger.d('AUTHOR_FOLLOW: Loaded ${authors.length} followed authors');
    } catch (e) {
      AppLogger.e('Failed to load followed authors', error: e);
      state = const AuthorFollowState();
    }
  }

  /// Follow an author — optimistic UI update + Supabase insert
  Future<void> follow(String authorName) async {
    if (authorName.isEmpty) return;
    final normalized = authorName.toLowerCase().trim();
    if (state.followedAuthors.contains(normalized)) return;

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Optimistic UI update
    state = state.copyWith(
      followedAuthors: {...state.followedAuthors, normalized},
    );
    AppLogger.d('AUTHOR_FOLLOW: Now following "$authorName"');

    try {
      await _supabase.from('author_follows').insert({
        'user_id': user.id,
        'author_name': normalized,
        'followed_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      AppLogger.e('Failed to follow author', error: e);
      // Rollback optimistic update on failure
      final rollback = Set<String>.from(state.followedAuthors)..remove(normalized);
      state = state.copyWith(followedAuthors: rollback);
    }
  }

  /// Unfollow an author — optimistic UI update + Supabase delete
  Future<void> unfollow(String authorName) async {
    if (authorName.isEmpty) return;
    final normalized = authorName.toLowerCase().trim();
    if (!state.followedAuthors.contains(normalized)) return;

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Optimistic UI update
    final newSet = Set<String>.from(state.followedAuthors)..remove(normalized);
    state = state.copyWith(followedAuthors: newSet);
    AppLogger.d('AUTHOR_FOLLOW: Unfollowed "$authorName"');

    try {
      await _supabase
          .from('author_follows')
          .delete()
          .eq('user_id', user.id)
          .eq('author_name', normalized);
    } catch (e) {
      AppLogger.e('Failed to unfollow author', error: e);
      // Rollback optimistic update on failure
      state = state.copyWith(
        followedAuthors: {...state.followedAuthors, normalized},
      );
    }
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
  return AuthorFollowNotifier(ref);
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
        .select('id, title_fa, title_en, cover_url, author_fa, avg_rating, play_count, created_at, content_type, status')
        .eq('status', 'approved')
        .eq('content_type', 'audiobook')
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
