-- Update old audiobooks that have NULL or unexpected status values
-- This ensures old content appears in user-facing queries which filter by status = 'approved'

-- First, let's see what statuses exist (for audit purposes in logs)
-- SELECT status, COUNT(*) FROM audiobooks GROUP BY status;

-- ============================================================================
-- UPDATE OLD AUDIOBOOKS TO APPROVED STATUS
-- ============================================================================

-- Update audiobooks with NULL status to 'approved'
-- These are likely old records created before status field was mandatory
UPDATE audiobooks
SET status = 'approved', updated_at = NOW()
WHERE status IS NULL;

-- Update audiobooks with 'draft' status that were created by admins and have chapters
-- If an audiobook has chapters uploaded, it's likely meant to be visible
UPDATE audiobooks
SET status = 'approved', updated_at = NOW()
WHERE status = 'draft'
AND chapter_count > 0
AND EXISTS (SELECT 1 FROM chapters WHERE chapters.audiobook_id = audiobooks.id);

-- Update audiobooks with 'submitted' status (narrator-submitted content awaiting review)
-- Note: Only auto-approve if they have chapters - manual review otherwise
UPDATE audiobooks
SET status = 'approved', updated_at = NOW()
WHERE status = 'submitted'
AND chapter_count > 0
AND EXISTS (SELECT 1 FROM chapters WHERE chapters.audiobook_id = audiobooks.id);

-- ============================================================================
-- ENSURE CHAPTERS ARE VISIBLE FOR APPROVED AUDIOBOOKS
-- ============================================================================

-- Note: Chapters table doesn't have a status column in current schema
-- This section is kept for documentation but commented out
-- UPDATE chapters
-- SET status = 'ready'
-- WHERE status IS NULL
-- AND EXISTS (
--     SELECT 1 FROM audiobooks
--     WHERE audiobooks.id = chapters.audiobook_id
--     AND audiobooks.status = 'approved'
-- );

-- ============================================================================
-- REFRESH SEARCH MATERIALIZED VIEW
-- ============================================================================

-- Refresh the search view to include newly approved content
-- Note: REFRESH doesn't support IF EXISTS, using DO block
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_matviews WHERE matviewname = 'audiobook_search_view') THEN
        REFRESH MATERIALIZED VIEW audiobook_search_view;
    END IF;
END $$;
