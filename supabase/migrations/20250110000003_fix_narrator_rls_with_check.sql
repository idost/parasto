-- Fix RLS policies to include WITH CHECK clause for UPDATE operations
-- Without WITH CHECK, updates may silently fail even though USING allows reads

-- ============================================================================
-- FIX AUDIOBOOKS UPDATE POLICIES
-- ============================================================================

-- Drop and recreate narrator update policy with WITH CHECK
DROP POLICY IF EXISTS "Narrators can update own audiobooks" ON public.audiobooks;

CREATE POLICY "Narrators can update own audiobooks" ON public.audiobooks
    FOR UPDATE
    USING (narrator_id = auth.uid())
    WITH CHECK (narrator_id = auth.uid());

-- ============================================================================
-- FIX CHAPTERS UPDATE POLICIES
-- ============================================================================

-- Check if chapters policy exists and needs fixing
DROP POLICY IF EXISTS "Narrators can update own chapters" ON public.chapters;

CREATE POLICY "Narrators can update own chapters" ON public.chapters
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM audiobooks
            WHERE audiobooks.id = chapters.audiobook_id
            AND audiobooks.narrator_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM audiobooks
            WHERE audiobooks.id = chapters.audiobook_id
            AND audiobooks.narrator_id = auth.uid()
        )
    );

-- ============================================================================
-- FIX BOOK_METADATA UPDATE POLICIES
-- ============================================================================

DROP POLICY IF EXISTS "Narrators can update own book_metadata" ON public.book_metadata;

CREATE POLICY "Narrators can update own book_metadata" ON public.book_metadata
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM audiobooks
            WHERE audiobooks.id = book_metadata.audiobook_id
            AND audiobooks.narrator_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM audiobooks
            WHERE audiobooks.id = book_metadata.audiobook_id
            AND audiobooks.narrator_id = auth.uid()
        )
    );

-- ============================================================================
-- FIX MUSIC_METADATA UPDATE POLICIES
-- ============================================================================

DROP POLICY IF EXISTS "Narrators can update own music_metadata" ON public.music_metadata;

CREATE POLICY "Narrators can update own music_metadata" ON public.music_metadata
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM audiobooks
            WHERE audiobooks.id = music_metadata.audiobook_id
            AND audiobooks.narrator_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM audiobooks
            WHERE audiobooks.id = music_metadata.audiobook_id
            AND audiobooks.narrator_id = auth.uid()
        )
    );
