-- ============================================================================
-- CREATOR PROFILES FEATURE
-- ============================================================================
-- This migration creates tables for creator profiles (authors, translators,
-- narrators, artists, singers, composers, etc.) and links them to audiobooks.
--
-- DESIGN PRINCIPLES:
-- 1. ADDITIVE ONLY: Does not modify existing tables or columns
-- 2. BACKWARDS COMPATIBLE: Existing content without creators works as before
-- 3. FLEXIBLE: Uses text with CHECK constraints instead of rigid ENUMs
-- 4. SAFE RLS: Read access for all authenticated, write only for admins
-- ============================================================================

-- ============================================================================
-- TABLE: creators
-- ============================================================================
-- Stores profile information for content creators (people or entities)
-- ============================================================================

CREATE TABLE IF NOT EXISTS creators (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Display name in Persian (required)
    display_name TEXT NOT NULL,

    -- Display name in Latin/English (optional, for international content)
    display_name_latin TEXT,

    -- Primary type of this creator
    -- Using CHECK constraint for flexibility (easy to add new types)
    creator_type TEXT NOT NULL DEFAULT 'other' CHECK (
        creator_type IN (
            'author',       -- نویسنده
            'translator',   -- مترجم
            'narrator',     -- گوینده
            'artist',       -- هنرمند (general)
            'singer',       -- خواننده
            'composer',     -- آهنگساز
            'lyricist',     -- ترانه‌سرا
            'musician',     -- نوازنده
            'arranger',     -- تنظیم‌کننده
            'publisher',    -- ناشر
            'label',        -- لیبل موسیقی
            'other'         -- سایر
        )
    ),

    -- Optional biography/description
    bio TEXT,

    -- Optional avatar/profile image URL
    avatar_url TEXT,

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for searching by name
CREATE INDEX IF NOT EXISTS idx_creators_display_name
    ON creators USING gin (display_name gin_trgm_ops);

-- Index for filtering by type
CREATE INDEX IF NOT EXISTS idx_creators_type
    ON creators (creator_type);

-- ============================================================================
-- TABLE: audiobook_creators
-- ============================================================================
-- Links audiobooks to creators with specific roles
-- An audiobook can have multiple creators with different roles
-- A creator can be linked to multiple audiobooks
-- ============================================================================

CREATE TABLE IF NOT EXISTS audiobook_creators (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Foreign key to audiobooks
    audiobook_id INTEGER NOT NULL REFERENCES audiobooks(id) ON DELETE CASCADE,

    -- Foreign key to creators
    creator_id UUID NOT NULL REFERENCES creators(id) ON DELETE CASCADE,

    -- Role of this creator for this specific audiobook
    -- (may differ from creator's primary type)
    role TEXT NOT NULL DEFAULT 'other' CHECK (
        role IN (
            'author',       -- نویسنده
            'translator',   -- مترجم
            'narrator',     -- گوینده
            'artist',       -- هنرمند
            'singer',       -- خواننده
            'composer',     -- آهنگساز
            'lyricist',     -- ترانه‌سرا
            'musician',     -- نوازنده
            'arranger',     -- تنظیم‌کننده
            'publisher',    -- ناشر
            'label',        -- لیبل
            'other'         -- سایر
        )
    ),

    -- Sort order for displaying multiple creators of same role
    sort_order SMALLINT NOT NULL DEFAULT 0,

    -- Timestamp
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Prevent duplicate (audiobook, creator, role) combinations
    UNIQUE (audiobook_id, creator_id, role)
);

-- Index for finding all creators of an audiobook
CREATE INDEX IF NOT EXISTS idx_audiobook_creators_audiobook
    ON audiobook_creators (audiobook_id);

-- Index for finding all works by a creator
CREATE INDEX IF NOT EXISTS idx_audiobook_creators_creator
    ON audiobook_creators (creator_id);

-- Index for filtering by role
CREATE INDEX IF NOT EXISTS idx_audiobook_creators_role
    ON audiobook_creators (role);

-- ============================================================================
-- TRIGGER: Update updated_at on creators
-- ============================================================================

CREATE OR REPLACE FUNCTION update_creators_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_creators_updated_at ON creators;
CREATE TRIGGER trigger_creators_updated_at
    BEFORE UPDATE ON creators
    FOR EACH ROW
    EXECUTE FUNCTION update_creators_updated_at();

-- ============================================================================
-- RLS POLICIES: creators
-- ============================================================================
-- Read: All authenticated users
-- Write: Only admins (profiles.role = 'admin')
-- ============================================================================

ALTER TABLE creators ENABLE ROW LEVEL SECURITY;

-- SELECT: All authenticated users can read creators
DROP POLICY IF EXISTS "Authenticated users can view creators" ON creators;
CREATE POLICY "Authenticated users can view creators"
    ON creators FOR SELECT
    TO authenticated
    USING (true);

-- INSERT: Only admins can create creators
DROP POLICY IF EXISTS "Admins can create creators" ON creators;
CREATE POLICY "Admins can create creators"
    ON creators FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role = 'admin'
        )
    );

-- UPDATE: Only admins can update creators
DROP POLICY IF EXISTS "Admins can update creators" ON creators;
CREATE POLICY "Admins can update creators"
    ON creators FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role = 'admin'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role = 'admin'
        )
    );

-- DELETE: Only admins can delete creators
DROP POLICY IF EXISTS "Admins can delete creators" ON creators;
CREATE POLICY "Admins can delete creators"
    ON creators FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role = 'admin'
        )
    );

-- ============================================================================
-- RLS POLICIES: audiobook_creators
-- ============================================================================
-- Read: All authenticated users
-- Write: Only admins
-- ============================================================================

ALTER TABLE audiobook_creators ENABLE ROW LEVEL SECURITY;

-- SELECT: All authenticated users can view audiobook-creator links
DROP POLICY IF EXISTS "Authenticated users can view audiobook_creators" ON audiobook_creators;
CREATE POLICY "Authenticated users can view audiobook_creators"
    ON audiobook_creators FOR SELECT
    TO authenticated
    USING (true);

-- INSERT: Only admins can link creators to audiobooks
DROP POLICY IF EXISTS "Admins can create audiobook_creators" ON audiobook_creators;
CREATE POLICY "Admins can create audiobook_creators"
    ON audiobook_creators FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role = 'admin'
        )
    );

-- UPDATE: Only admins can update links
DROP POLICY IF EXISTS "Admins can update audiobook_creators" ON audiobook_creators;
CREATE POLICY "Admins can update audiobook_creators"
    ON audiobook_creators FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role = 'admin'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role = 'admin'
        )
    );

-- DELETE: Only admins can remove links
DROP POLICY IF EXISTS "Admins can delete audiobook_creators" ON audiobook_creators;
CREATE POLICY "Admins can delete audiobook_creators"
    ON audiobook_creators FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role = 'admin'
        )
    );

-- ============================================================================
-- COMMENTS (for documentation)
-- ============================================================================

COMMENT ON TABLE creators IS 'Profiles for content creators (authors, narrators, artists, etc.)';
COMMENT ON TABLE audiobook_creators IS 'Links audiobooks to their creators with specific roles';

COMMENT ON COLUMN creators.creator_type IS 'Primary type: author, translator, narrator, singer, composer, lyricist, publisher, label, other';
COMMENT ON COLUMN audiobook_creators.role IS 'Role for this specific audiobook (may differ from creator primary type)';
COMMENT ON COLUMN audiobook_creators.sort_order IS 'Display order when multiple creators have the same role';

-- ============================================================================
-- HOW TO ENABLE CREATOR PROFILES IN PRODUCTION
-- ============================================================================
--
-- PREREQUISITES:
--   1. Run this migration: supabase db push
--   2. Ensure pg_trgm extension is enabled (for trigram search index)
--      If migration fails on idx_creators_display_name, run:
--      CREATE EXTENSION IF NOT EXISTS pg_trgm;
--
-- USAGE STEPS:
--   1. Admin Dashboard → "دسترسی سریع" → "مدیریت سازندگان"
--      - Create creator profiles (authors, narrators, artists, etc.)
--      - Each creator has: display_name (Persian), display_name_latin (optional),
--        creator_type, bio, avatar_url
--
--   2. Admin → Audiobooks → Edit any audiobook → "مدیریت سازندگان" button
--      - Opens bottom sheet to link/unlink creators to that audiobook
--      - Select a role (author, translator, narrator, singer, composer, etc.)
--      - Link as many creators as needed with different roles
--
--   3. Listener Side (automatic):
--      - On audiobook/music detail screen, linked creator names appear underlined
--      - Tapping a name opens CreatorProfileScreen showing:
--        - Creator's profile (name, type, bio, avatar)
--        - All their works (books and music separately)
--
-- NOTES:
--   - Legacy text fields (author_fa, narrator, etc.) still work as fallback
--   - Only linked creators are tappable; legacy-only names remain static text
--   - RLS: All authenticated users can read; only admins can write
-- ============================================================================
