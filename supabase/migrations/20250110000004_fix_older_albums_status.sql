-- ============================================
-- FIX OLDER ALBUMS STATUS
-- Migration: 20250110_fix_older_albums_status.sql
-- Purpose: Set status to 'approved' for older audiobooks that may have been
--          stuck in draft/submitted/pending status
-- ============================================

-- First, let's see what we're dealing with (run this SELECT first to check)
-- SELECT id, title_fa, status, is_music, created_at
-- FROM audiobooks
-- WHERE status NOT IN ('approved', 'rejected')
-- ORDER BY created_at ASC;

-- Update all audiobooks that are not approved/rejected to 'approved'
-- This includes: draft, submitted, pending, under_review, etc.
UPDATE audiobooks
SET status = 'approved',
    updated_at = NOW()
WHERE status NOT IN ('approved', 'rejected');

-- Also ensure all audiobooks have required fields set properly
-- Set is_music to false if it's NULL (default to book)
UPDATE audiobooks
SET is_music = false
WHERE is_music IS NULL;

-- Log how many were updated
DO $$
DECLARE
    updated_count INTEGER;
BEGIN
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RAISE NOTICE 'Updated % audiobooks to approved status', updated_count;
END $$;
