-- ============================================================================
-- FIX PLAYLIST_ITEMS UNIQUE CONSTRAINT (FINAL)
-- ============================================================================
-- This migration ensures the correct unique constraint on playlist_items.
-- It is fully idempotent and safe to run multiple times.
--
-- GOAL:
-- Allow a playlist to contain BOTH:
--   - A whole audiobook/album (chapter_index = NULL)
--   - AND specific chapters/tracks from that same audiobook
--
-- CONSTRAINT NEEDED:
--   UNIQUE (playlist_id, audiobook_id, chapter_index)
--
-- PostgreSQL treats NULL as distinct in UNIQUE constraints, so:
--   - (P, A, NULL) = whole audiobook
--   - (P, A, 0)    = chapter 1
--   - (P, A, 3)    = chapter 4
-- All can coexist in the same playlist.
--
-- TRUE DUPLICATES are still blocked:
--   - Two rows with (P, A, NULL) would be rejected
--   - Two rows with (P, A, 3) would be rejected
-- ============================================================================

-- Step 1: Drop the OLD constraint (if it exists)
-- This was created in the original 20241231 migration
ALTER TABLE playlist_items
    DROP CONSTRAINT IF EXISTS playlist_items_playlist_id_audiobook_id_key;

-- Step 2: Drop the INTERMEDIATE constraint (if it exists)
-- This was created in the 20250101 migration
ALTER TABLE playlist_items
    DROP CONSTRAINT IF EXISTS playlist_items_unique_item;

-- Step 3: Create the CORRECT constraint
-- Using a DO block to check if it already exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'playlist_items_unique_item'
        AND conrelid = 'public.playlist_items'::regclass
    ) THEN
        ALTER TABLE playlist_items
            ADD CONSTRAINT playlist_items_unique_item
            UNIQUE (playlist_id, audiobook_id, chapter_index);
    END IF;
END $$;

-- ============================================================================
-- VERIFICATION QUERIES (run these manually after migration)
-- ============================================================================
--
-- 1. Check that the correct constraint exists:
--    SELECT conname, pg_get_constraintdef(oid)
--    FROM pg_constraint
--    WHERE conrelid = 'public.playlist_items'::regclass AND contype = 'u';
--
-- Expected output:
--    conname                     | definition
--    playlist_items_unique_item  | UNIQUE (playlist_id, audiobook_id, chapter_index)
--
-- 2. Test: Add whole book then single chapter (should succeed):
--    INSERT INTO playlist_items (playlist_id, audiobook_id, chapter_index, position)
--    VALUES ('YOUR_PLAYLIST_UUID', 1, NULL, 0);
--    INSERT INTO playlist_items (playlist_id, audiobook_id, chapter_index, position)
--    VALUES ('YOUR_PLAYLIST_UUID', 1, 3, 1);
--
-- 3. Test: Add duplicate (should fail):
--    INSERT INTO playlist_items (playlist_id, audiobook_id, chapter_index, position)
--    VALUES ('YOUR_PLAYLIST_UUID', 1, 3, 2);
--    -- Expected: duplicate key value violates unique constraint
-- ============================================================================
