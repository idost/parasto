-- ============================================
-- FIX search_content RPC function
-- Migration: 20250111_fix_search_content_rpc.sql
-- Purpose: Fix missing columns in RETURNS TABLE that are referenced in CASE statement
-- Issue: composer_display, lyricist_display, chapters_text are used in matched_in CASE
--        but were not included in the function's return type, causing silent failures
-- ============================================

-- Drop and recreate the function with correct return columns
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
    composer_display TEXT,
    lyricist_display TEXT,
    chapters_text TEXT,
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
        csi.composer_display,
        csi.lyricist_display,
        csi.chapters_text,
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
            WHEN csi.lyricist_display ILIKE '%' || normalized_query || '%' THEN 'lyricist'
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
            OR csi.composer_display ILIKE '%' || normalized_query || '%'
            OR csi.lyricist_display ILIKE '%' || normalized_query || '%'
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

-- Re-grant permissions
GRANT EXECUTE ON FUNCTION public.search_content TO authenticated, anon;

-- Refresh the materialized view to ensure it's up to date
REFRESH MATERIALIZED VIEW public.content_search_index;
