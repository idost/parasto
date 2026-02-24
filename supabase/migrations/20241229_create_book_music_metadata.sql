-- Migration: Create separate metadata tables for books and music
-- Purpose: Provide distinct, semantic metadata fields for books vs music content
-- Date: 2024-12-29
--
-- This migration creates:
-- 1. book_metadata table - for audiobooks (is_music = false)
-- 2. music_metadata table - for music (is_music = true)
-- 3. RLS policies for both tables
-- 4. Backfill data from existing audiobooks table
--
-- IMPORTANT: This is a non-destructive migration:
-- - Existing columns (author_fa, author_en, translator_fa, translator_en) are NOT removed
-- - They remain for backwards compatibility until full migration is verified
--
-- TODO [Future Cleanup]: After verifying all apps use the new metadata tables,
-- consider removing the legacy columns from audiobooks table.

-- ==============================================
-- 1. Create book_metadata table
-- ==============================================
-- Stores metadata specific to audiobooks (کتاب صوتی)
-- Has a 1:1 relationship with audiobooks table

CREATE TABLE IF NOT EXISTS public.book_metadata (
    audiobook_id integer PRIMARY KEY REFERENCES public.audiobooks(id) ON DELETE CASCADE,

    -- نویسنده - Author info
    author_name text,               -- Main author name (Farsi)
    author_name_en text,            -- Author name in English
    co_authors text,                -- Additional authors (comma-separated, optional)

    -- مترجم - Translator info
    translator text,                -- Translator name (Farsi)
    translator_en text,             -- Translator name in English

    -- گوینده - Narrator info (distinct from profiles.display_name)
    narrator_name text,             -- Narrator display name (Farsi)
    narrator_name_en text,          -- Narrator name in English

    -- ناشر - Publisher info
    publisher text,                 -- Publisher name (Farsi)
    publisher_en text,              -- Publisher name in English

    -- سایر اطلاعات - Additional info
    publication_year integer,       -- Year of publication
    isbn text,                      -- ISBN (optional)

    -- Timestamps
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Add comments for documentation
COMMENT ON TABLE public.book_metadata IS 'Extended metadata for audiobooks (is_music = false). 1:1 relationship with audiobooks table.';
COMMENT ON COLUMN public.book_metadata.author_name IS 'Main author name in Farsi (نویسنده)';
COMMENT ON COLUMN public.book_metadata.co_authors IS 'Additional co-authors, comma-separated (optional)';
COMMENT ON COLUMN public.book_metadata.translator IS 'Translator name in Farsi (مترجم)';
COMMENT ON COLUMN public.book_metadata.narrator_name IS 'Narrator/voice actor name in Farsi (گوینده)';
COMMENT ON COLUMN public.book_metadata.publisher IS 'Publisher name in Farsi (ناشر)';
COMMENT ON COLUMN public.book_metadata.publication_year IS 'Original publication year (سال نشر)';
COMMENT ON COLUMN public.book_metadata.isbn IS 'International Standard Book Number (optional)';

-- ==============================================
-- 2. Create music_metadata table
-- ==============================================
-- Stores metadata specific to music (موسیقی)
-- Has a 1:1 relationship with audiobooks table

CREATE TABLE IF NOT EXISTS public.music_metadata (
    audiobook_id integer PRIMARY KEY REFERENCES public.audiobooks(id) ON DELETE CASCADE,

    -- هنرمند - Artist info
    artist_name text,               -- Main artist/singer name (Farsi)
    artist_name_en text,            -- Artist name in English
    featured_artists text,          -- Featured artists (comma-separated, optional)

    -- آهنگساز - Composer info
    composer text,                  -- Composer name (Farsi)
    composer_en text,               -- Composer name in English

    -- شاعر / ترانه‌سرا - Lyricist info
    lyricist text,                  -- Lyricist/poet name (Farsi)
    lyricist_en text,               -- Lyricist name in English

    -- آلبوم - Album info
    album_title text,               -- Album/collection title (Farsi)
    album_title_en text,            -- Album title in English

    -- ناشر / استودیو - Label info
    label text,                     -- Record label/studio (Farsi)
    label_en text,                  -- Label in English

    -- سبک - Genre (primary genre, detailed genres in audiobook_music_categories)
    genre text,                     -- Primary genre description (Farsi)
    genre_en text,                  -- Genre in English

    -- سایر اطلاعات - Additional info
    release_year integer,           -- Year of release (سال انتشار)

    -- Timestamps
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Add comments for documentation
COMMENT ON TABLE public.music_metadata IS 'Extended metadata for music content (is_music = true). 1:1 relationship with audiobooks table.';
COMMENT ON COLUMN public.music_metadata.artist_name IS 'Main artist/singer name in Farsi (هنرمند / خواننده)';
COMMENT ON COLUMN public.music_metadata.featured_artists IS 'Featured/guest artists, comma-separated (optional)';
COMMENT ON COLUMN public.music_metadata.composer IS 'Composer name in Farsi (آهنگساز)';
COMMENT ON COLUMN public.music_metadata.lyricist IS 'Lyricist/poet name in Farsi (شاعر / ترانه‌سرا)';
COMMENT ON COLUMN public.music_metadata.album_title IS 'Album or collection title in Farsi (آلبوم / مجموعه)';
COMMENT ON COLUMN public.music_metadata.label IS 'Record label or studio in Farsi (ناشر / استودیو)';
COMMENT ON COLUMN public.music_metadata.genre IS 'Primary genre description in Farsi (سبک موسیقی)';
COMMENT ON COLUMN public.music_metadata.release_year IS 'Year of release (سال انتشار)';

-- ==============================================
-- 3. Enable RLS and create policies
-- ==============================================

-- Enable RLS on book_metadata
ALTER TABLE public.book_metadata ENABLE ROW LEVEL SECURITY;

-- Everyone can read book_metadata for visible audiobooks
CREATE POLICY "Anyone can view book_metadata for visible audiobooks"
ON public.book_metadata
FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.audiobooks
        WHERE audiobooks.id = book_metadata.audiobook_id
        AND audiobooks.status = 'approved'
    )
);

-- Admins can manage all book_metadata
CREATE POLICY "Admins can manage all book_metadata"
ON public.book_metadata
FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid()
        AND role = 'admin'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid()
        AND role = 'admin'
    )
);

-- Narrators can manage book_metadata for their own audiobooks
CREATE POLICY "Narrators can manage their book_metadata"
ON public.book_metadata
FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM public.audiobooks
        WHERE audiobooks.id = book_metadata.audiobook_id
        AND audiobooks.narrator_id = auth.uid()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.audiobooks
        WHERE audiobooks.id = book_metadata.audiobook_id
        AND audiobooks.narrator_id = auth.uid()
    )
);

-- Enable RLS on music_metadata
ALTER TABLE public.music_metadata ENABLE ROW LEVEL SECURITY;

-- Everyone can read music_metadata for visible audiobooks
CREATE POLICY "Anyone can view music_metadata for visible audiobooks"
ON public.music_metadata
FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.audiobooks
        WHERE audiobooks.id = music_metadata.audiobook_id
        AND audiobooks.status = 'approved'
    )
);

-- Admins can manage all music_metadata
CREATE POLICY "Admins can manage all music_metadata"
ON public.music_metadata
FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid()
        AND role = 'admin'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid()
        AND role = 'admin'
    )
);

-- Note: Narrators cannot manage music_metadata because they can only upload books, not music

-- ==============================================
-- 4. Create updated_at triggers
-- ==============================================

CREATE OR REPLACE FUNCTION update_book_metadata_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS book_metadata_updated_at ON public.book_metadata;
CREATE TRIGGER book_metadata_updated_at
    BEFORE UPDATE ON public.book_metadata
    FOR EACH ROW
    EXECUTE FUNCTION update_book_metadata_updated_at();

CREATE OR REPLACE FUNCTION update_music_metadata_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS music_metadata_updated_at ON public.music_metadata;
CREATE TRIGGER music_metadata_updated_at
    BEFORE UPDATE ON public.music_metadata
    FOR EACH ROW
    EXECUTE FUNCTION update_music_metadata_updated_at();

-- ==============================================
-- 5. Backfill existing data
-- ==============================================

-- Backfill book_metadata from existing audiobooks where is_music = false
-- Map existing fields to new structure:
-- - author_fa -> author_name
-- - author_en -> author_name_en
-- - translator_fa -> translator
-- - translator_en -> translator_en
-- - narrator info comes from joined profiles table, but we copy it here for denormalization

INSERT INTO public.book_metadata (
    audiobook_id,
    author_name,
    author_name_en,
    translator,
    translator_en,
    narrator_name,
    created_at,
    updated_at
)
SELECT
    a.id,
    a.author_fa,
    a.author_en,
    a.translator_fa,
    a.translator_en,
    COALESCE(p.display_name, p.full_name),  -- Get narrator name from profiles
    a.created_at,
    now()
FROM public.audiobooks a
LEFT JOIN public.profiles p ON a.narrator_id = p.id
WHERE a.is_music = false
ON CONFLICT (audiobook_id) DO NOTHING;  -- Don't overwrite if already exists

-- Backfill music_metadata from existing audiobooks where is_music = true
-- Map existing fields (even though semantically wrong, preserves data):
-- - author_fa -> artist_name (best guess for now)
-- - author_en -> artist_name_en

INSERT INTO public.music_metadata (
    audiobook_id,
    artist_name,
    artist_name_en,
    created_at,
    updated_at
)
SELECT
    a.id,
    a.author_fa,   -- Using author as artist (temporary migration)
    a.author_en,
    a.created_at,
    now()
FROM public.audiobooks a
WHERE a.is_music = true
ON CONFLICT (audiobook_id) DO NOTHING;  -- Don't overwrite if already exists

-- ==============================================
-- 6. Create indexes for performance
-- ==============================================

-- No additional indexes needed - primary key on audiobook_id is sufficient
-- since we always query by audiobook_id (1:1 relationship)

-- ==============================================
-- Done!
-- ==============================================
--
-- The legacy columns (author_fa, author_en, translator_fa, translator_en)
-- remain in the audiobooks table for backwards compatibility.
--
-- TODO [Future]: Once all Flutter code is updated to use the new metadata
-- tables, we can consider removing the legacy columns with a cleanup migration.
