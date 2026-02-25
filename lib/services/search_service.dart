import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/models/search_result.dart';
import 'package:myna/utils/app_logger.dart';

/// Service for global admin search functionality
class SearchService {
  static final _supabase = Supabase.instance.client;

  // ============================================================================
  // ADVANCED CONTENT SEARCH (Full-Text Search)
  // ============================================================================

  /// Advanced content search using PostgreSQL full-text search
  /// Searches titles, authors, narrators, chapters, and descriptions
  /// Returns results with relevance ranking and match location info
  ///
  /// Can be used with:
  /// - Text query only (searches all content)
  /// - Filters only (contentType, categoryId, freeOnly)
  /// - Text query + filters combined
  static Future<List<Map<String, dynamic>>> searchContent({
    required String query,
    String? contentType, // 'book', 'music', 'article', or null for all
    int? categoryId,
    bool freeOnly = false,
    int limit = 50,
    int offset = 0,
  }) async {
    final trimmedQuery = query.trim();
    final hasFilters = contentType != null || categoryId != null || freeOnly;

    // Need either a valid query (2+ chars) or at least one filter
    if (trimmedQuery.length < 2 && !hasFilters) return [];

    try {
      // Try the advanced RPC search first
      final response = await _supabase.rpc<List<dynamic>>(
        'search_content',
        params: {
          'query_text': trimmedQuery,
          'content_type': contentType,
          'category_filter': categoryId,
          'free_only': freeOnly,
          'result_limit': limit,
          'result_offset': offset,
        },
      );

      return response
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (e) {
      AppLogger.e('RPC search_content failed, falling back to direct query: $e');
      // Fall back to direct query search
      return _fallbackSearch(
        query: trimmedQuery,
        contentType: contentType,
        categoryId: categoryId,
        freeOnly: freeOnly,
        limit: limit,
        offset: offset,
      );
    }
  }

  /// Fallback search using direct table queries when RPC is unavailable
  static Future<List<Map<String, dynamic>>> _fallbackSearch({
    required String query,
    String? contentType,
    int? categoryId,
    bool freeOnly = false,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var queryBuilder = _supabase
          .from('audiobooks')
          .select('''
            id,
            title_fa,
            title_en,
            description_fa,
            cover_url,
            content_type,
            is_free,
            category_id,
            play_count,
            avg_rating,
            created_at,
            total_duration_seconds,
            author_fa,
            categories!inner(name_fa)
          ''')
          .eq('status', 'approved');

      // Apply content type filter
      if (contentType == 'book') {
        queryBuilder = queryBuilder.eq('content_type', 'audiobook');
      } else if (contentType == 'music') {
        queryBuilder = queryBuilder.eq('content_type', 'music');
      } else if (contentType == 'article') {
        queryBuilder = queryBuilder.eq('content_type', 'article');
      }

      // Apply category filter
      if (categoryId != null) {
        queryBuilder = queryBuilder.eq('category_id', categoryId);
      }

      // Apply free only filter
      if (freeOnly) {
        queryBuilder = queryBuilder.eq('is_free', true);
      }

      // Apply text search if query provided
      if (query.isNotEmpty) {
        queryBuilder = queryBuilder.or('title_fa.ilike.%$query%,title_en.ilike.%$query%,author_fa.ilike.%$query%');
      }

      final response = await queryBuilder
          .order('play_count', ascending: false)
          .range(offset, offset + limit - 1);

      // Transform to match RPC output format
      return response.map((row) {
        final categoryData = row['categories'] as Map<String, dynamic>?;
        return {
          'id': row['id'],
          'title_fa': row['title_fa'],
          'title_en': row['title_en'],
          'description_fa': row['description_fa'],
          'cover_url': row['cover_url'],
          'content_type': row['content_type'],
          'is_free': row['is_free'],
          'category_id': row['category_id'],
          'category_name': categoryData?['name_fa'],
          'play_count': row['play_count'],
          'avg_rating': row['avg_rating'],
          'created_at': row['created_at'],
          'total_duration_seconds': row['total_duration_seconds'],
          'author_display': row['author_fa'] ?? '',
          'narrator_display': '',
          'rank': 0.0,
          'matched_in': 'content',
        };
      }).toList();
    } catch (e) {
      AppLogger.e('Fallback search also failed', error: e);
      rethrow;
    }
  }

  /// Search ebooks table (separate from audiobooks)
  /// Returns results matching the query by title or author
  static Future<List<Map<String, dynamic>>> searchEbooks({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    if (query.trim().length < 2) return [];

    try {
      final response = await _supabase
          .from('audiobooks')
          .select('''
            id, title_fa, title_en, cover_url, cover_storage_path, is_free,
            author_fa, page_count, play_count, status
          ''')
          .eq('content_type', 'ebook')
          .eq('status', 'approved')
          .or('title_fa.ilike.%${query.trim()}%,title_en.ilike.%${query.trim()}%,author_fa.ilike.%${query.trim()}%')
          .order('play_count', ascending: false)
          .range(offset, offset + limit - 1);

      // Mark results as ebooks so callers can distinguish
      return (response as List).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        map['_is_ebook'] = true;
        return map;
      }).toList();
    } catch (e) {
      AppLogger.e('Error searching ebooks', error: e);
      return [];
    }
  }

  /// Refresh the content search index
  /// Call this after bulk content changes
  static Future<void> refreshSearchIndex() async {
    try {
      await _supabase.rpc<void>('refresh_content_search_index');
    } catch (e) {
      AppLogger.e('Error refreshing search index', error: e);
    }
  }

  // ============================================================================
  // ADMIN GLOBAL SEARCH (Users, Creators, Tickets, Audiobooks)
  // ============================================================================

  /// Search across all entities (audiobooks, users, creators, tickets)
  static Future<List<SearchResult>> search({
    required String query,
    Set<SearchResultType>? types,
    int limit = 20,
  }) async {
    if (query.trim().length < 2) return [];

    try {
      final results = <SearchResult>[];
      final searchQuery = query.trim().toLowerCase();

      // Search audiobooks
      if (types == null || types.contains(SearchResultType.audiobook)) {
        final audiobooks = await _searchAudiobooks(searchQuery, limit);
        results.addAll(audiobooks);
      }

      // Search users
      if (types == null || types.contains(SearchResultType.user)) {
        final users = await _searchUsers(searchQuery, limit);
        results.addAll(users);
      }

      // Search creators
      if (types == null || types.contains(SearchResultType.creator)) {
        final creators = await _searchCreators(searchQuery, limit);
        results.addAll(creators);
      }

      // Search tickets (if table exists)
      if (types == null || types.contains(SearchResultType.ticket)) {
        final tickets = await _searchTickets(searchQuery, limit);
        results.addAll(tickets);
      }

      // Sort by relevance (title match first) then by date
      results.sort((a, b) {
        final aMatch = a.title.toLowerCase().startsWith(searchQuery) ? 0 : 1;
        final bMatch = b.title.toLowerCase().startsWith(searchQuery) ? 0 : 1;
        if (aMatch != bMatch) return aMatch.compareTo(bMatch);
        return b.createdAt.compareTo(a.createdAt);
      });

      return results.take(limit).toList();
    } catch (e) {
      AppLogger.e('Error in global search', error: e);
      return [];
    }
  }

  /// Search audiobooks
  static Future<List<SearchResult>> _searchAudiobooks(
      String query, int limit) async {
    try {
      final response = await _supabase
          .from('audiobooks')
          .select('id, title_fa, title_en, cover_url, content_type, status, created_at')
          .or('title_fa.ilike.%$query%,title_en.ilike.%$query%')
          .order('created_at', ascending: false)
          .limit(limit);

      return response.map((row) {
        return SearchResult(
          type: SearchResultType.audiobook,
          itemId: row['id'].toString(),
          title: row['title_fa'] as String? ?? row['title_en'] as String? ?? '',
          subtitle: row['title_en'] as String?,
          imageUrl: row['cover_url'] as String?,
          metadata: {
            'content_type': row['content_type'] as String? ?? 'audiobook',
            'status': row['status'] as String?,
          },
          createdAt: DateTime.parse(row['created_at'] as String),
        );
      }).toList();
    } catch (e) {
      AppLogger.e('Error searching audiobooks', error: e);
      return [];
    }
  }

  /// Search users (profiles)
  static Future<List<SearchResult>> _searchUsers(String query, int limit) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, display_name, full_name, email, avatar_url, role, is_disabled, created_at')
          .or('display_name.ilike.%$query%,full_name.ilike.%$query%,email.ilike.%$query%')
          .order('created_at', ascending: false)
          .limit(limit);

      return response.map((row) {
        final displayName = row['display_name'] as String? ??
            row['full_name'] as String? ??
            'کاربر';
        return SearchResult(
          type: SearchResultType.user,
          itemId: row['id'] as String,
          title: displayName,
          subtitle: row['email'] as String?,
          imageUrl: row['avatar_url'] as String?,
          metadata: {
            'role': row['role'] as String? ?? 'listener',
            'is_disabled': row['is_disabled'] as bool? ?? false,
          },
          createdAt: DateTime.parse(row['created_at'] as String),
        );
      }).toList();
    } catch (e) {
      AppLogger.e('Error searching users', error: e);
      return [];
    }
  }

  /// Search creators
  static Future<List<SearchResult>> _searchCreators(
      String query, int limit) async {
    try {
      final response = await _supabase
          .from('creators')
          .select('id, display_name, display_name_latin, avatar_url, creator_type, created_at')
          .or('display_name.ilike.%$query%,display_name_latin.ilike.%$query%')
          .order('created_at', ascending: false)
          .limit(limit);

      return response.map((row) {
        return SearchResult(
          type: SearchResultType.creator,
          itemId: row['id'].toString(),
          title: row['display_name'] as String? ?? '',
          subtitle: row['display_name_latin'] as String?,
          imageUrl: row['avatar_url'] as String?,
          metadata: {
            'type': row['creator_type'] as String?,
          },
          createdAt: DateTime.parse(row['created_at'] as String),
        );
      }).toList();
    } catch (e) {
      AppLogger.e('Error searching creators', error: e);
      return [];
    }
  }

  /// Search support tickets (if table exists)
  static Future<List<SearchResult>> _searchTickets(
      String query, int limit) async {
    try {
      // Check if table exists first
      final tableCheck = await _supabase
          .from('information_schema.tables')
          .select('table_name')
          .eq('table_name', 'support_tickets')
          .maybeSingle();

      if (tableCheck == null) return [];

      final response = await _supabase
          .from('support_tickets')
          .select('id, subject, status, priority, created_at')
          .or('subject.ilike.%$query%')
          .order('created_at', ascending: false)
          .limit(limit);

      return response.map((row) {
        return SearchResult(
          type: SearchResultType.ticket,
          itemId: row['id'].toString(),
          title: row['subject'] as String? ?? 'تیکت پشتیبانی',
          subtitle: null,
          imageUrl: null,
          metadata: {
            'status': row['status'] as String?,
            'priority': row['priority'] as String?,
          },
          createdAt: DateTime.parse(row['created_at'] as String),
        );
      }).toList();
    } catch (e) {
      // Table might not exist, which is fine
      return [];
    }
  }

}
