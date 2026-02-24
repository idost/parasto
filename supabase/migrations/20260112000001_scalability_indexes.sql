-- Migration: Scalability Indexes
-- Purpose: Add missing indexes for performance at scale (100K+ audiobooks, 1M+ users)
-- Date: 2026-01-12
-- Note: Using regular CREATE INDEX (not CONCURRENTLY) because migrations run in transactions

-- ============================================================================
-- AUDIOBOOK INDEXES
-- ============================================================================

-- Composite index for the most common query pattern:
-- WHERE status = 'approved' AND is_music = false ORDER BY created_at DESC
-- Used by: home_providers.dart, category_screen.dart, search
CREATE INDEX IF NOT EXISTS idx_audiobooks_status_music_created
ON audiobooks(status, is_music, created_at DESC);

-- Index for popular content sorting (play_count DESC)
-- Used by: home_providers.dart (popular books), admin analytics
CREATE INDEX IF NOT EXISTS idx_audiobooks_play_count
ON audiobooks(play_count DESC NULLS LAST)
WHERE status = 'approved';

-- Index for category browsing (category + status + sort)
-- Used by: category_screen.dart
CREATE INDEX IF NOT EXISTS idx_audiobooks_category_status
ON audiobooks(category_id, status, created_at DESC);

-- Partial index for approved-only queries (smaller, faster)
-- Used by: Most user-facing screens
CREATE INDEX IF NOT EXISTS idx_audiobooks_approved_created
ON audiobooks(created_at DESC)
WHERE status = 'approved';

-- Index for narrator/admin content management
-- Used by: narrator screens, admin audiobooks screen
CREATE INDEX IF NOT EXISTS idx_audiobooks_narrator
ON audiobooks(narrator_id, status, created_at DESC);

-- ============================================================================
-- USER PROGRESS INDEXES
-- ============================================================================

-- Index for listening progress queries
-- Used by: library_screen.dart, continue listening, progress sync
CREATE INDEX IF NOT EXISTS idx_listening_progress_user_updated
ON listening_progress(user_id, updated_at DESC);

-- Index for specific audiobook progress lookup
-- Used by: player_screen.dart (resume position)
CREATE INDEX IF NOT EXISTS idx_listening_progress_user_audiobook
ON listening_progress(user_id, audiobook_id);

-- ============================================================================
-- ENTITLEMENT INDEXES
-- ============================================================================

-- Index for entitlement lookups (ownership check)
-- Used by: audio_provider.dart (isOwned check), library_screen.dart
CREATE INDEX IF NOT EXISTS idx_entitlements_user_audiobook
ON entitlements(user_id, audiobook_id);

-- ============================================================================
-- CHAPTER INDEXES
-- ============================================================================

-- Index for chapter queries by audiobook
-- Used by: player_screen.dart, chapter management
CREATE INDEX IF NOT EXISTS idx_chapters_audiobook_index
ON chapters(audiobook_id, chapter_index);

-- ============================================================================
-- LISTENING SESSIONS INDEXES
-- ============================================================================

-- Index for user listening history
-- Used by: profile stats, admin analytics
CREATE INDEX IF NOT EXISTS idx_listening_sessions_user_date
ON listening_sessions(user_id, session_date DESC);

-- Index for analytics by audiobook
-- Used by: admin dashboard, narrator stats
CREATE INDEX IF NOT EXISTS idx_listening_sessions_audiobook_date
ON listening_sessions(audiobook_id, session_date DESC);

-- ============================================================================
-- PURCHASE INDEXES
-- ============================================================================

-- Index for purchase history
-- Used by: admin revenue analytics, user purchase history
CREATE INDEX IF NOT EXISTS idx_purchases_created
ON purchases(created_at DESC);

-- Index for user purchase lookup
-- Used by: library screen, entitlement verification
CREATE INDEX IF NOT EXISTS idx_purchases_user
ON purchases(user_id, created_at DESC);

-- ============================================================================
-- PROFILE INDEXES
-- ============================================================================

-- Index for user role filtering
-- Used by: admin users screen (filter by role)
CREATE INDEX IF NOT EXISTS idx_profiles_role_created
ON profiles(role, created_at DESC);

-- ============================================================================
-- PLAYLIST INDEXES
-- ============================================================================

-- Index for user playlists
-- Used by: library_screen.dart playlists tab
CREATE INDEX IF NOT EXISTS idx_playlists_user
ON playlists(user_id, created_at DESC);

-- Index for playlist items ordering
-- Used by: playlist_service.dart
CREATE INDEX IF NOT EXISTS idx_playlist_items_position
ON playlist_items(playlist_id, position);

-- ============================================================================
-- SEARCH RELATED INDEXES
-- ============================================================================

-- Enable trigram extension for fuzzy/typo-tolerant search
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Trigram index for Farsi title fuzzy matching
-- Used by: search when exact FTS doesn't match
CREATE INDEX IF NOT EXISTS idx_audiobooks_title_fa_trgm
ON audiobooks USING gin(title_fa gin_trgm_ops);

-- Trigram index for English title fuzzy matching
CREATE INDEX IF NOT EXISTS idx_audiobooks_title_en_trgm
ON audiobooks USING gin(title_en gin_trgm_ops)
WHERE title_en IS NOT NULL;

-- ============================================================================
-- ANALYTICS INDEXES
-- ============================================================================

-- Note: DATE() expression indexes are not needed since we already have
-- created_at indexes which PostgreSQL can use for date-based filtering.
-- The materialized views handle daily aggregation efficiently.

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON INDEX idx_audiobooks_status_music_created IS
'Primary composite index for browsing approved content. Covers WHERE status AND is_music ORDER BY created_at.';

COMMENT ON INDEX idx_audiobooks_play_count IS
'Partial index for popular content. Only indexes approved books for efficiency.';

COMMENT ON INDEX idx_listening_progress_user_updated IS
'Supports continue listening queries. User + updated_at for recent progress.';

COMMENT ON INDEX idx_entitlements_user_audiobook IS
'Fast ownership lookup. Critical for playback authorization.';
