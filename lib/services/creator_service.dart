import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myna/utils/app_logger.dart';

/// Service for accessing creator profiles and their works.
///
/// This service provides read-only access to:
/// - Creator profiles (authors, narrators, artists, etc.)
/// - Links between creators and audiobooks
/// - Works (audiobooks/music) by a specific creator
///
/// All methods handle errors defensively and return empty results on failure,
/// ensuring the UI never crashes due to creator data issues.
class CreatorService {
  final SupabaseClient _client;

  CreatorService([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  // ===========================================================================
  // ROLE/TYPE MAPPINGS (Farsi labels)
  // ===========================================================================

  /// Maps creator types to Farsi display labels
  static const Map<String, String> creatorTypeLabels = {
    'author': 'نویسنده',
    'translator': 'مترجم',
    'narrator': 'گوینده',
    'artist': 'هنرمند',
    'singer': 'خواننده',
    'composer': 'آهنگساز',
    'lyricist': 'ترانه‌سرا',
    'musician': 'نوازنده',
    'arranger': 'تنظیم‌کننده',
    'publisher': 'ناشر',
    'label': 'لیبل',
    'other': 'سایر',
  };

  /// Maps role values to Farsi display labels (same as creator types)
  static const Map<String, String> roleLabels = creatorTypeLabels;

  /// Get Farsi label for a creator type
  static String getCreatorTypeLabel(String? type) {
    if (type == null) return 'سایر';
    return creatorTypeLabels[type] ?? 'سایر';
  }

  /// Get Farsi label for a role
  static String getRoleLabel(String? role) {
    if (role == null) return 'سایر';
    return roleLabels[role] ?? 'سایر';
  }

  // ===========================================================================
  // QUERIES
  // ===========================================================================

  /// Get all creators linked to an audiobook, with their roles.
  ///
  /// Returns a list of maps containing:
  /// - All creator fields (id, display_name, display_name_latin, creator_type, bio, avatar_url)
  /// - role: The creator's role for this specific audiobook
  /// - sort_order: Display order for creators with the same role
  ///
  /// Returns empty list on error (never throws).
  Future<List<Map<String, dynamic>>> getCreatorsForAudiobook(
    int audiobookId,
  ) async {
    try {
      AppLogger.d('CreatorService: Fetching creators for audiobook $audiobookId');

      final response = await _client
          .from('audiobook_creators')
          .select('''
            role,
            sort_order,
            is_primary,
            creator:creators (
              id,
              display_name,
              display_name_latin,
              creator_type,
              bio,
              avatar_url,
              collection_label
            )
          ''')
          .eq('audiobook_id', audiobookId)
          .order('role')
          .order('sort_order');

      // Flatten the response: merge creator fields with role/sort_order/is_primary
      final List<Map<String, dynamic>> result = [];
      for (final row in response as List) {
        final creator = row['creator'] as Map<String, dynamic>?;
        if (creator != null) {
          result.add({
            ...creator,
            'role': row['role'],
            'sort_order': row['sort_order'],
            'is_primary': row['is_primary'] ?? false,
          });
        }
      }

      AppLogger.d('CreatorService: Found ${result.length} creators for audiobook $audiobookId');
      return result;
    } catch (e, st) {
      AppLogger.e('CreatorService: Error fetching creators for audiobook $audiobookId',
          error: e, stackTrace: st);
      return [];
    }
  }

  /// Get a single creator by ID.
  ///
  /// Returns null if not found or on error (never throws).
  Future<Map<String, dynamic>?> getCreatorById(String creatorId) async {
    try {
      AppLogger.d('CreatorService: Fetching creator $creatorId');

      final response = await _client
          .from('creators')
          .select('*')
          .eq('id', creatorId)
          .maybeSingle();

      if (response == null) {
        AppLogger.d('CreatorService: Creator $creatorId not found');
        return null;
      }

      AppLogger.d('CreatorService: Found creator "${response['display_name']}"');
      return response;
    } catch (e, st) {
      AppLogger.e('CreatorService: Error fetching creator $creatorId',
          error: e, stackTrace: st);
      return null;
    }
  }

  /// Get all works (audiobooks and music) for a creator.
  ///
  /// Returns a list of audiobooks where this creator has a role, including:
  /// - Basic audiobook fields for display (id, title_fa, title_en, cover_url, is_music, is_free)
  /// - role: The creator's role for each work
  ///
  /// Results are grouped by is_music (books first, then music).
  /// Returns empty list on error (never throws).
  Future<List<Map<String, dynamic>>> getWorksForCreator(
    String creatorId,
  ) async {
    try {
      AppLogger.d('CreatorService: Fetching works for creator $creatorId');

      final response = await _client
          .from('audiobook_creators')
          .select('''
            role,
            audiobook:audiobooks (
              id,
              title_fa,
              title_en,
              cover_url,
              is_music,
              is_free,
              status,
              total_duration_seconds,
              chapter_count
            )
          ''')
          .eq('creator_id', creatorId)
          .order('created_at', ascending: false);

      // Flatten and filter: only include approved audiobooks
      final List<Map<String, dynamic>> result = [];
      for (final row in response as List) {
        final audiobook = row['audiobook'] as Map<String, dynamic>?;
        if (audiobook != null && audiobook['status'] == 'approved') {
          result.add({
            ...audiobook,
            'role': row['role'],
          });
        }
      }

      // Sort: books first (is_music = false), then music (is_music = true)
      result.sort((a, b) {
        final aIsMusic = a['is_music'] == true ? 1 : 0;
        final bIsMusic = b['is_music'] == true ? 1 : 0;
        return aIsMusic.compareTo(bIsMusic);
      });

      AppLogger.d('CreatorService: Found ${result.length} works for creator $creatorId');
      return result;
    } catch (e, st) {
      AppLogger.e('CreatorService: Error fetching works for creator $creatorId',
          error: e, stackTrace: st);
      return [];
    }
  }

  /// Search creators by name (partial match).
  ///
  /// If query is empty, returns all creators (up to 50) for browsing.
  /// Useful for admin UI when linking creators to audiobooks.
  /// Returns empty list on error (never throws).
  Future<List<Map<String, dynamic>>> searchCreators(String query) async {
    try {
      final trimmedQuery = query.trim();

      if (trimmedQuery.isEmpty) {
        // Return all creators for browsing (limited to 50)
        AppLogger.d('CreatorService: Fetching all creators');
        final response = await _client
            .from('creators')
            .select('*')
            .order('display_name')
            .limit(50);
        AppLogger.d('CreatorService: Found ${(response as List).length} creators');
        return List<Map<String, dynamic>>.from(response);
      }

      AppLogger.d('CreatorService: Searching creators for "$trimmedQuery"');

      // Use ilike for case-insensitive partial match
      final response = await _client
          .from('creators')
          .select('*')
          .or('display_name.ilike.%$trimmedQuery%,display_name_latin.ilike.%$trimmedQuery%')
          .order('display_name')
          .limit(20);

      AppLogger.d('CreatorService: Found ${(response as List).length} creators matching "$trimmedQuery"');
      return List<Map<String, dynamic>>.from(response);
    } catch (e, st) {
      AppLogger.e('CreatorService: Error searching creators for "$query"',
          error: e, stackTrace: st);
      return [];
    }
  }

  // ===========================================================================
  // AUTO-SYNC HELPERS
  // ===========================================================================

  /// Normalize a name for matching: trim, collapse multiple spaces to single space
  static String normalizeName(String name) {
    return name.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Find or create a creator by name and type.
  ///
  /// Matching is case-insensitive and uses normalized names.
  /// If a creator with the same display_name and creator_type exists, returns its ID.
  /// Otherwise, creates a new creator and returns its ID.
  ///
  /// Returns the creator's UUID, or null on error.
  Future<String?> upsertCreatorByName({
    required String displayName,
    required String creatorType,
    String? displayNameLatin,
  }) async {
    final normalized = normalizeName(displayName);
    if (normalized.isEmpty) return null;

    try {
      AppLogger.d('CreatorService: upsertCreatorByName "$normalized" as $creatorType');

      // Try to find existing creator with same name + type (case-insensitive)
      final existing = await _client
          .from('creators')
          .select('id')
          .ilike('display_name', normalized)
          .eq('creator_type', creatorType)
          .limit(1)
          .maybeSingle();

      if (existing != null) {
        final existingId = existing['id'] as String;
        AppLogger.d('CreatorService: Found existing creator $existingId');
        return existingId;
      }

      // Create new creator
      final created = await _client.from('creators').insert({
        'display_name': normalized,
        'display_name_latin': displayNameLatin?.trim(),
        'creator_type': creatorType,
      }).select('id').maybeSingle();

      if (created == null) {
        AppLogger.e('CreatorService: Insert returned null for "$normalized"');
        return null;
      }
      final newId = created['id'] as String;
      AppLogger.d('CreatorService: Created new creator $newId');
      return newId;
    } catch (e, st) {
      AppLogger.e('CreatorService: Error upserting creator "$normalized"',
          error: e, stackTrace: st);
      return null;
    }
  }

  /// Sync all creators for an audiobook from metadata fields.
  ///
  /// This method:
  /// 1. Removes all existing creator links for this audiobook
  /// 2. For each non-empty name field, upserts a creator
  /// 3. Links the creator to the audiobook with the appropriate role
  ///
  /// Designed to be called after saving audiobook metadata.
  /// Safe to call multiple times (idempotent).
  ///
  /// Returns true on success, false on error.
  Future<bool> syncCreatorsForAudiobook({
    required int audiobookId,
    required bool isMusic,
    // Book metadata fields
    String? authorName,
    String? authorNameEn,
    String? translatorName,
    String? translatorNameEn,
    String? narratorName,
    String? narratorNameEn,
    String? publisherName,
    String? publisherNameEn,
    // Music metadata fields
    String? artistName,
    String? artistNameEn,
    String? composerName,
    String? composerNameEn,
    String? lyricistName,
    String? lyricistNameEn,
    String? labelName,
    String? labelNameEn,
  }) async {
    try {
      AppLogger.d('CreatorService: syncCreatorsForAudiobook $audiobookId (isMusic: $isMusic)');

      // Step 1: Delete all existing creator links for this audiobook
      await _client
          .from('audiobook_creators')
          .delete()
          .eq('audiobook_id', audiobookId);

      AppLogger.d('CreatorService: Cleared existing creator links');

      // Step 2: Build list of (name, nameEn, role) to process
      final List<_CreatorEntry> entries = [];

      if (isMusic) {
        // Music: singer, composer, lyricist, label
        if (artistName != null && normalizeName(artistName).isNotEmpty) {
          entries.add(_CreatorEntry(artistName, artistNameEn, 'singer'));
        }
        if (composerName != null && normalizeName(composerName).isNotEmpty) {
          entries.add(_CreatorEntry(composerName, composerNameEn, 'composer'));
        }
        if (lyricistName != null && normalizeName(lyricistName).isNotEmpty) {
          entries.add(_CreatorEntry(lyricistName, lyricistNameEn, 'lyricist'));
        }
        if (labelName != null && normalizeName(labelName).isNotEmpty) {
          entries.add(_CreatorEntry(labelName, labelNameEn, 'label'));
        }
      } else {
        // Book: author, translator, narrator, publisher
        if (authorName != null && normalizeName(authorName).isNotEmpty) {
          entries.add(_CreatorEntry(authorName, authorNameEn, 'author'));
        }
        if (translatorName != null && normalizeName(translatorName).isNotEmpty) {
          entries.add(_CreatorEntry(translatorName, translatorNameEn, 'translator'));
        }
        if (narratorName != null && normalizeName(narratorName).isNotEmpty) {
          entries.add(_CreatorEntry(narratorName, narratorNameEn, 'narrator'));
        }
        if (publisherName != null && normalizeName(publisherName).isNotEmpty) {
          entries.add(_CreatorEntry(publisherName, publisherNameEn, 'publisher'));
        }
      }

      AppLogger.d('CreatorService: Processing ${entries.length} creator entries');

      // Step 3: For each entry, upsert creator and link
      int sortOrder = 0;
      for (final entry in entries) {
        final creatorId = await upsertCreatorByName(
          displayName: entry.name,
          creatorType: entry.role, // creator_type matches role
          displayNameLatin: entry.nameEn,
        );

        if (creatorId != null) {
          final linked = await linkCreatorToAudiobook(
            audiobookId: audiobookId,
            creatorId: creatorId,
            role: entry.role,
            sortOrder: sortOrder,
          );
          if (linked) {
            sortOrder++;
          }
        }
      }

      AppLogger.d('CreatorService: Sync complete - linked $sortOrder creators');
      return true;
    } catch (e, st) {
      AppLogger.e('CreatorService: Error syncing creators for audiobook $audiobookId',
          error: e, stackTrace: st);
      return false;
    }
  }

  // ===========================================================================
  // ADMIN METHODS (for Phase 5)
  // ===========================================================================

  /// Create a new creator profile.
  ///
  /// Returns the created creator record, or null on error.
  /// Only admins can call this (enforced by RLS).
  Future<Map<String, dynamic>?> createCreator({
    required String displayName,
    String? displayNameLatin,
    String creatorType = 'other',
    String? bio,
    String? avatarUrl,
    String? collectionLabel,
  }) async {
    try {
      AppLogger.d('CreatorService: Creating creator "$displayName"');

      final response = await _client.from('creators').insert({
        'display_name': displayName,
        'display_name_latin': displayNameLatin,
        'creator_type': creatorType,
        'bio': bio,
        'avatar_url': avatarUrl,
        'collection_label': collectionLabel,
      }).select().maybeSingle();

      if (response == null) {
        AppLogger.e('CreatorService: Insert returned null for "$displayName"');
        return null;
      }
      AppLogger.d('CreatorService: Created creator ${response['id']}');
      return response;
    } catch (e, st) {
      AppLogger.e('CreatorService: Error creating creator "$displayName"',
          error: e, stackTrace: st);
      return null;
    }
  }

  /// Update an existing creator profile.
  ///
  /// Returns the updated creator record, or null on error.
  /// Only admins can call this (enforced by RLS).
  Future<Map<String, dynamic>?> updateCreator({
    required String creatorId,
    required String displayName,
    String? displayNameLatin,
    String creatorType = 'other',
    String? bio,
    String? avatarUrl,
    String? collectionLabel,
  }) async {
    try {
      AppLogger.d('CreatorService: Updating creator $creatorId');

      final response = await _client
          .from('creators')
          .update({
            'display_name': displayName,
            'display_name_latin': displayNameLatin,
            'creator_type': creatorType,
            'bio': bio,
            'avatar_url': avatarUrl,
            'collection_label': collectionLabel,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', creatorId)
          .select()
          .maybeSingle();

      if (response == null) {
        AppLogger.e('CreatorService: Update returned null for $creatorId');
        return null;
      }
      AppLogger.d('CreatorService: Updated creator $creatorId');
      return response;
    } catch (e, st) {
      AppLogger.e('CreatorService: Error updating creator $creatorId',
          error: e, stackTrace: st);
      return null;
    }
  }

  /// Link a creator to an audiobook with a specific role.
  ///
  /// Returns true on success, false on error.
  /// Only admins can call this (enforced by RLS).
  Future<bool> linkCreatorToAudiobook({
    required int audiobookId,
    required String creatorId,
    required String role,
    int sortOrder = 0,
  }) async {
    try {
      AppLogger.d('CreatorService: Linking creator $creatorId to audiobook $audiobookId as $role');

      await _client.from('audiobook_creators').upsert({
        'audiobook_id': audiobookId,
        'creator_id': creatorId,
        'role': role,
        'sort_order': sortOrder,
      }, onConflict: 'audiobook_id,creator_id,role');

      AppLogger.d('CreatorService: Successfully linked creator to audiobook');
      return true;
    } catch (e, st) {
      AppLogger.e('CreatorService: Error linking creator $creatorId to audiobook $audiobookId',
          error: e, stackTrace: st);
      return false;
    }
  }

  /// Remove a creator link from an audiobook.
  ///
  /// Returns true on success, false on error.
  /// Only admins can call this (enforced by RLS).
  Future<bool> unlinkCreatorFromAudiobook({
    required int audiobookId,
    required String creatorId,
    required String role,
  }) async {
    try {
      AppLogger.d('CreatorService: Unlinking creator $creatorId from audiobook $audiobookId (role: $role)');

      await _client
          .from('audiobook_creators')
          .delete()
          .eq('audiobook_id', audiobookId)
          .eq('creator_id', creatorId)
          .eq('role', role);

      AppLogger.d('CreatorService: Successfully unlinked creator from audiobook');
      return true;
    } catch (e, st) {
      AppLogger.e('CreatorService: Error unlinking creator $creatorId from audiobook $audiobookId',
          error: e, stackTrace: st);
      return false;
    }
  }

  /// Check if a creator has any linked works (audiobooks or music).
  ///
  /// Returns true if the creator has at least one link in audiobook_creators.
  /// Returns false if no links exist or on error.
  Future<bool> hasWorks(String creatorId) async {
    try {
      AppLogger.d('CreatorService: Checking if creator $creatorId has works');

      final response = await _client
          .from('audiobook_creators')
          .select('id')
          .eq('creator_id', creatorId)
          .limit(1);

      final hasLinks = (response as List).isNotEmpty;
      AppLogger.d('CreatorService: Creator $creatorId has works: $hasLinks');
      return hasLinks;
    } catch (e, st) {
      AppLogger.e('CreatorService: Error checking works for creator $creatorId',
          error: e, stackTrace: st);
      return false; // Assume no works on error (safer to allow delete check to proceed)
    }
  }

  /// Delete a creator profile.
  ///
  /// SAFE DELETE: First checks if creator has linked works.
  /// - If creator has works → returns DeleteResult.hasWorks (blocks deletion)
  /// - If creator has no works → deletes and returns DeleteResult.success
  /// - On error → returns DeleteResult.error
  ///
  /// Only admins can call this (enforced by RLS).
  Future<DeleteResult> deleteCreator(String creatorId) async {
    try {
      AppLogger.d('CreatorService: Attempting to delete creator $creatorId');

      // Step 1: Check if creator has any linked works
      final hasLinkedWorks = await hasWorks(creatorId);
      if (hasLinkedWorks) {
        AppLogger.w('CreatorService: Cannot delete creator $creatorId - has linked works');
        return DeleteResult.hasWorks;
      }

      // Step 2: Safe to delete - no linked works
      await _client
          .from('creators')
          .delete()
          .eq('id', creatorId);

      AppLogger.d('CreatorService: Successfully deleted creator $creatorId');
      return DeleteResult.success;
    } catch (e, st) {
      AppLogger.e('CreatorService: Error deleting creator $creatorId',
          error: e, stackTrace: st);
      return DeleteResult.error;
    }
  }
}

/// Result of a delete operation
enum DeleteResult {
  /// Deletion was successful
  success,
  /// Cannot delete because creator has linked works
  hasWorks,
  /// An error occurred during deletion
  error,
}

/// Helper class for creator sync entries
class _CreatorEntry {
  final String name;
  final String? nameEn;
  final String role;

  _CreatorEntry(this.name, this.nameEn, this.role);
}
