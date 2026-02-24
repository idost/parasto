-- ============================================================================
-- FIX PLAYLIST_ITEMS UNIQUE CONSTRAINT
-- ============================================================================
-- This migration fixes the unique constraint on playlist_items to allow:
-- - A whole audiobook/album (chapter_index = NULL)
-- - AND individual chapters/tracks from that same audiobook (chapter_index = N)
-- to coexist in the same playlist.
--
-- PROBLEM:
-- The original constraint UNIQUE (playlist_id, audiobook_id) prevents adding:
--   - playlist P + audiobook A (whole book)     -> OK
--   - playlist P + audiobook A + chapter 3     -> REJECTED (same playlist_id, audiobook_id)
--
-- SOLUTION:
-- Include chapter_index in the unique constraint.
-- PostgreSQL treats NULL as distinct in unique constraints, so:
--   - (P, A, NULL) and (P, A, 3) are considered DIFFERENT and both allowed.
--
-- This is safe because:
-- - Existing data has unique (playlist_id, audiobook_id) pairs
-- - Adding chapter_index only RELAXES the constraint (allows more combinations)
-- - No data migration needed
-- ============================================================================

-- Step 1: Drop the old unique constraint
-- The auto-generated name for UNIQUE (playlist_id, audiobook_id) is:
-- playlist_items_playlist_id_audiobook_id_key
ALTER TABLE playlist_items
    DROP CONSTRAINT IF EXISTS playlist_items_playlist_id_audiobook_id_key;

-- Step 2: Add the new unique constraint including chapter_index
-- This allows:
--   - (playlist_id=X, audiobook_id=Y, chapter_index=NULL)  -> whole book
--   - (playlist_id=X, audiobook_id=Y, chapter_index=0)     -> chapter 1
--   - (playlist_id=X, audiobook_id=Y, chapter_index=1)     -> chapter 2
-- All three can coexist in the same playlist.
ALTER TABLE playlist_items
    ADD CONSTRAINT playlist_items_unique_item
    UNIQUE (playlist_id, audiobook_id, chapter_index);

-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- After applying this migration, you should be able to:
--
-- 1. Add a whole audiobook to a playlist:
--    INSERT INTO playlist_items (playlist_id, audiobook_id, chapter_index, position)
--    VALUES ('...', 123, NULL, 0);
--
-- 2. Add a specific chapter from the SAME audiobook to the SAME playlist:
--    INSERT INTO playlist_items (playlist_id, audiobook_id, chapter_index, position)
--    VALUES ('...', 123, 3, 1);
--
-- Both should succeed (no duplicate error).
--
-- To apply this migration:
--   supabase db push
-- ============================================================================
