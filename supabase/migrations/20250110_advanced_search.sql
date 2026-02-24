-- ============================================
-- ADVANCED SEARCH SYSTEM (Safe Implementation)
-- Migration: 20250110_advanced_search.sql
-- Purpose: Create full-text search with chapter, author, narrator, artist support
-- Uses SECURITY DEFINER to avoid RLS circular dependencies
-- ============================================

-- 1. Create materialized view combining all searchable content
-- This view pre-computes search vectors for fast full-text search
CREATE MATERIALIZED VIEW IF NOT EXISTS public.content_search_index AS
SELECT
    a.id,
    a.title_fa,
    a.title_en,
    a.description_fa,
    a.cover_url,
    a.is_music,
    a.is_free,
    a.status,
    a.category_id,
    a.play_count,
    a.avg_rating,
    a.created_at,
    a.total_duration_seconds,

    -- Author/Artist (from various sources)
    COALESCE(a.author_fa, bm.author_name, mm.artist_name, '') AS author_display,

    -- Narrator (books only)
    COALESCE(bm.narrator_name, '') AS narrator_display,

    -- Composer/Lyricist (music only)
    COALESCE(mm.composer, '') AS composer_display,
    COALESCE(mm.lyricist, '') AS lyricist_display,

    -- All chapter titles concatenated for search
    COALESCE(
        (SELECT string_agg(ch.title_fa, ' ') FROM public.chapters ch WHERE ch.audiobook_id = a.id),
        ''
    ) AS chapters_text,

    -- Category name for display
    cat.name_fa AS category_name,

    -- Full-text search vector with weights:
    -- A = title (highest priority)
    -- B = author/artist
    -- C = narrator/composer/lyricist
    -- D = chapters/description (lowest priority)
    setweight(to_tsvector('simple', COALESCE(a.title_fa, '')), 'A') ||
    setweight(to_tsvector('simple', COALESCE(a.title_en, '')), 'A') ||
    setweight(to_tsvector('simple', COALESCE(a.author_fa, '')), 'B') ||
    setweight(to_tsvector('simple', COALESCE(bm.author_name, '')), 'B') ||
    setweight(to_tsvector('simple', COALESCE(mm.artist_name, '')), 'B') ||
    setweight(to_tsvector('simple', COALESCE(bm.narrator_name, '')), 'C') ||
    setweight(to_tsvector('simple', COALESCE(mm.composer, '')), 'C') ||
    setweight(to_tsvector('simple', COALESCE(mm.lyricist, '')), 'C') ||
    setweight(to_tsvector('simple', COALESCE(
        (SELECT string_agg(ch.title_fa, ' ') FROM public.chapters ch WHERE ch.audiobook_id = a.id),
        ''
    )), 'D') ||
    setweight(to_tsvector('simple', COALESCE(a.description_fa, '')), 'D')
    AS search_vector

FROM public.audiobooks a
LEFT JOIN public.book_metadata bm ON a.id = bm.audiobook_id
LEFT JOIN public.music_metadata mm ON a.id = mm.audiobook_id
LEFT JOIN public.categories cat ON a.category_id = cat.id
WHERE a.status = 'approved';

-- 2. Create unique index on id (required for CONCURRENTLY refresh)
CREATE UNIQUE INDEX IF NOT EXISTS idx_content_search_id
ON public.content_search_index(id);

-- 3. Create GIN index for fast full-text search
CREATE INDEX IF NOT EXISTS idx_content_search_vector
ON public.content_search_index USING GIN(search_vector);

-- Additional indexes for filters
CREATE INDEX IF NOT EXISTS idx_content_search_music
ON public.content_search_index(is_music);

CREATE INDEX IF NOT EXISTS idx_content_search_category
ON public.content_search_index(category_id);

CREATE INDEX IF NOT EXISTS idx_content_search_free
ON public.content_search_index(is_free);

-- 4. Function to refresh the materialized view
-- Uses SECURITY DEFINER to bypass RLS when refreshing
CREATE OR REPLACE FUNCTION public.refresh_content_search_index()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY public.content_search_index;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Main search function
-- Uses SECURITY DEFINER to safely query the materialized view
-- Drop existing function first (required when changing return type)
DROP FUNCTION IF EXISTS public.search_content(TEXT, TEXT, INTEGER, BOOLEAN, INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION public.search_content(
    query_text TEXT,
    content_type TEXT DEFAULT NULL,  -- 'book', 'music', or NULL for all
    category_filter INTEGER DEFAULT NULL,
    free_only BOOLEAN DEFAULT FALSE,
    result_limit INTEGER DEFAULT 50,
    result_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    id INTEGER,
    title_fa TEXT,
    title_en TEXT,
    description_fa TEXT,
    cover_url TEXT,
    is_music BOOLEAN,
    is_free BOOLEAN,
    category_id INTEGER,
    category_name TEXT,
    play_count INTEGER,
    avg_rating NUMERIC,
    created_at TIMESTAMPTZ,
    total_duration_seconds INTEGER,
    author_display TEXT,
    narrator_display TEXT,
    rank REAL,
    matched_in TEXT
) AS $$
DECLARE
    search_query tsquery;
    normalized_query TEXT;
    has_text_query BOOLEAN;
BEGIN
    -- Normalize query
    normalized_query := trim(COALESCE(query_text, ''));
    has_text_query := length(normalized_query) >= 2;

    -- If no text query and no filters, return empty
    IF NOT has_text_query AND content_type IS NULL AND category_filter IS NULL AND NOT free_only THEN
        RETURN;
    END IF;

    -- Create tsquery for full-text search (if we have a query)
    IF has_text_query THEN
        search_query := plainto_tsquery('simple', normalized_query);
    END IF;

    RETURN QUERY
    SELECT
        csi.id,
        csi.title_fa,
        csi.title_en,
        csi.description_fa,
        csi.cover_url,
        csi.is_music,
        csi.is_free,
        csi.category_id,
        csi.category_name,
        csi.play_count,
        csi.avg_rating,
        csi.created_at,
        csi.total_duration_seconds,
        csi.author_display,
        csi.narrator_display,
        CASE WHEN has_text_query THEN ts_rank_cd(csi.search_vector, search_query) ELSE 0.0 END AS rank,
        -- Determine which field matched (for UI display)
        CASE
            WHEN NOT has_text_query THEN 'content'
            WHEN csi.title_fa ILIKE '%' || normalized_query || '%'
                 OR csi.title_en ILIKE '%' || normalized_query || '%' THEN 'title'
            WHEN csi.author_display ILIKE '%' || normalized_query || '%' THEN
                CASE WHEN csi.is_music THEN 'artist' ELSE 'author' END
            WHEN csi.narrator_display ILIKE '%' || normalized_query || '%' THEN 'narrator'
            WHEN csi.composer_display ILIKE '%' || normalized_query || '%' THEN 'composer'
            WHEN csi.chapters_text ILIKE '%' || normalized_query || '%' THEN 'chapter'
            WHEN csi.description_fa ILIKE '%' || normalized_query || '%' THEN 'description'
            ELSE 'content'
        END AS matched_in
    FROM public.content_search_index csi
    WHERE
        -- Text search (if query provided)
        (NOT has_text_query OR (
            csi.search_vector @@ search_query
            OR csi.title_fa ILIKE '%' || normalized_query || '%'
            OR csi.title_en ILIKE '%' || normalized_query || '%'
            OR csi.author_display ILIKE '%' || normalized_query || '%'
            OR csi.narrator_display ILIKE '%' || normalized_query || '%'
            OR csi.chapters_text ILIKE '%' || normalized_query || '%'
        ))
        -- Content type filter
        AND (content_type IS NULL
             OR (content_type = 'book' AND csi.is_music = FALSE)
             OR (content_type = 'music' AND csi.is_music = TRUE))
        -- Category filter
        AND (category_filter IS NULL OR csi.category_id = category_filter)
        -- Free only filter
        AND (free_only = FALSE OR csi.is_free = TRUE)
    ORDER BY
        -- Exact title prefix match first (most relevant)
        CASE WHEN has_text_query AND csi.title_fa ILIKE normalized_query || '%' THEN 0 ELSE 1 END,
        -- Then by full-text rank (if searching)
        rank DESC,
        -- Then by popularity
        csi.play_count DESC
    LIMIT result_limit
    OFFSET result_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- 6. Grant permissions
-- Materialized view is readable by all (only contains approved content)
GRANT SELECT ON public.content_search_index TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.search_content TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.refresh_content_search_index TO authenticated;

-- 7. Initial refresh of the materialized view
-- (Uses non-concurrent refresh since view is new)
REFRESH MATERIALIZED VIEW public.content_search_index;
