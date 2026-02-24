-- ============================================================================
-- PLAYLISTS FEATURE
-- ============================================================================
-- This migration creates tables for user playlists (book playlists and music
-- playlists), allowing listeners to organize their content.
--
-- DESIGN PRINCIPLES:
-- 1. ADDITIVE ONLY: Does not modify existing tables
-- 2. TYPE SEPARATION: Book playlists (is_music=false) vs Music playlists (is_music=true)
-- 3. FUTURE-PROOF: visibility column for future sharing features
-- 4. SAFE RLS: Users can only access their own playlists
-- ============================================================================

-- ============================================================================
-- TABLE: playlists
-- ============================================================================
-- Stores user-created playlists for organizing audiobooks and music
-- ============================================================================

CREATE TABLE IF NOT EXISTS playlists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Owner of the playlist
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Playlist title (required)
    title TEXT NOT NULL,

    -- Type of playlist: false = book playlist, true = music playlist
    -- Items in this playlist must match this type
    is_music BOOLEAN NOT NULL DEFAULT false,

    -- Whether this is a default/system playlist (e.g., "Favorites")
    -- Default playlists cannot be deleted by the user
    is_default BOOLEAN NOT NULL DEFAULT false,

    -- Visibility for future sharing features
    -- 'private' = only owner can see
    -- 'public' = anyone can see (future)
    -- 'shared' = specific users can see (future)
    visibility TEXT NOT NULL DEFAULT 'private' CHECK (
        visibility IN ('private', 'public', 'shared')
    ),

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for finding playlists by user
CREATE INDEX IF NOT EXISTS idx_playlists_user_id
    ON playlists (user_id);

-- Index for filtering by type
CREATE INDEX IF NOT EXISTS idx_playlists_is_music
    ON playlists (is_music);

-- ============================================================================
-- TABLE: playlist_items
-- ============================================================================
-- Links audiobooks/music to playlists with ordering support
-- ============================================================================

CREATE TABLE IF NOT EXISTS playlist_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Parent playlist
    playlist_id UUID NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,

    -- The audiobook or music track
    audiobook_id INTEGER NOT NULL REFERENCES audiobooks(id) ON DELETE CASCADE,

    -- Optional: specific chapter index for chapter-level playlist support (future)
    -- NULL means the entire audiobook/track
    chapter_index INTEGER,

    -- Position in the playlist for ordering (0-based)
    position INTEGER NOT NULL DEFAULT 0,

    -- Timestamp
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Prevent duplicate items in the same playlist
    -- (same audiobook can be in multiple playlists, but not twice in the same playlist)
    UNIQUE (playlist_id, audiobook_id)
);

-- Index for finding items in a playlist
CREATE INDEX IF NOT EXISTS idx_playlist_items_playlist_id
    ON playlist_items (playlist_id);

-- Index for finding which playlists contain an audiobook
CREATE INDEX IF NOT EXISTS idx_playlist_items_audiobook_id
    ON playlist_items (audiobook_id);

-- Index for ordering items
CREATE INDEX IF NOT EXISTS idx_playlist_items_position
    ON playlist_items (playlist_id, position);

-- ============================================================================
-- TRIGGER: Update updated_at on playlists
-- ============================================================================

CREATE OR REPLACE FUNCTION update_playlists_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_playlists_updated_at ON playlists;
CREATE TRIGGER trigger_playlists_updated_at
    BEFORE UPDATE ON playlists
    FOR EACH ROW
    EXECUTE FUNCTION update_playlists_updated_at();

-- ============================================================================
-- RLS POLICIES: playlists
-- ============================================================================
-- Users can only access their own playlists
-- ============================================================================

ALTER TABLE playlists ENABLE ROW LEVEL SECURITY;

-- SELECT: Users can view their own playlists
DROP POLICY IF EXISTS "Users can view own playlists" ON playlists;
CREATE POLICY "Users can view own playlists"
    ON playlists FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

-- INSERT: Users can create playlists for themselves
DROP POLICY IF EXISTS "Users can create own playlists" ON playlists;
CREATE POLICY "Users can create own playlists"
    ON playlists FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

-- UPDATE: Users can update their own playlists
DROP POLICY IF EXISTS "Users can update own playlists" ON playlists;
CREATE POLICY "Users can update own playlists"
    ON playlists FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- DELETE: Users can delete their own playlists (except default ones)
DROP POLICY IF EXISTS "Users can delete own playlists" ON playlists;
CREATE POLICY "Users can delete own playlists"
    ON playlists FOR DELETE
    TO authenticated
    USING (user_id = auth.uid() AND is_default = false);

-- ============================================================================
-- RLS POLICIES: playlist_items
-- ============================================================================
-- Users can only access items in their own playlists
-- ============================================================================

ALTER TABLE playlist_items ENABLE ROW LEVEL SECURITY;

-- SELECT: Users can view items in their own playlists
DROP POLICY IF EXISTS "Users can view own playlist items" ON playlist_items;
CREATE POLICY "Users can view own playlist items"
    ON playlist_items FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM playlists
            WHERE playlists.id = playlist_items.playlist_id
            AND playlists.user_id = auth.uid()
        )
    );

-- INSERT: Users can add items to their own playlists
DROP POLICY IF EXISTS "Users can add items to own playlists" ON playlist_items;
CREATE POLICY "Users can add items to own playlists"
    ON playlist_items FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM playlists
            WHERE playlists.id = playlist_items.playlist_id
            AND playlists.user_id = auth.uid()
        )
    );

-- UPDATE: Users can update items in their own playlists
DROP POLICY IF EXISTS "Users can update own playlist items" ON playlist_items;
CREATE POLICY "Users can update own playlist items"
    ON playlist_items FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM playlists
            WHERE playlists.id = playlist_items.playlist_id
            AND playlists.user_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM playlists
            WHERE playlists.id = playlist_items.playlist_id
            AND playlists.user_id = auth.uid()
        )
    );

-- DELETE: Users can remove items from their own playlists
DROP POLICY IF EXISTS "Users can delete own playlist items" ON playlist_items;
CREATE POLICY "Users can delete own playlist items"
    ON playlist_items FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM playlists
            WHERE playlists.id = playlist_items.playlist_id
            AND playlists.user_id = auth.uid()
        )
    );

-- ============================================================================
-- COMMENTS (for documentation)
-- ============================================================================

COMMENT ON TABLE playlists IS 'User-created playlists for organizing audiobooks and music';
COMMENT ON TABLE playlist_items IS 'Items (audiobooks/music) in user playlists';

COMMENT ON COLUMN playlists.is_music IS 'Playlist type: false = book playlist, true = music playlist';
COMMENT ON COLUMN playlists.is_default IS 'System-created default playlist that cannot be deleted';
COMMENT ON COLUMN playlists.visibility IS 'Visibility level: private, public, shared (future feature)';
COMMENT ON COLUMN playlist_items.chapter_index IS 'Optional chapter index for chapter-level playlists (future feature)';
COMMENT ON COLUMN playlist_items.position IS 'Sort order within the playlist (0-based)';

-- ============================================================================
-- USAGE NOTES
-- ============================================================================
--
-- To apply this migration:
--   supabase db push
--
-- IMPORTANT RULES:
-- 1. Book playlists (is_music = false) should only contain audiobooks where is_music = false
-- 2. Music playlists (is_music = true) should only contain audiobooks where is_music = true
-- 3. This constraint is enforced at the application level, not in the database
-- 4. Entitlements are NOT bypassed - playback still goes through existing entitlement checks
--
-- ============================================================================
