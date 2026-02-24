-- Migration: Enforce Single Category Per Music Album
-- Created: 2025-01-08
-- Purpose: Change music category system from many-to-many to one-to-one
--          Each music album can have ONLY ONE category (like Spotify)
--          Mutually exclusive categories (کلاسیک can't be پاپ)

-- =============================================================================
-- Step 1: Backfill - Keep only first category for albums with multiple
-- =============================================================================

-- Delete duplicate category assignments (keep lowest category_id for each audiobook)
DELETE FROM public.audiobook_music_categories
WHERE (audiobook_id, music_category_id) IN (
  SELECT audiobook_id, music_category_id
  FROM public.audiobook_music_categories amc1
  WHERE EXISTS (
    SELECT 1 FROM public.audiobook_music_categories amc2
    WHERE amc2.audiobook_id = amc1.audiobook_id
    AND amc2.music_category_id < amc1.music_category_id
  )
);

-- Log backfill results
DO $$
DECLARE
  remaining_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO remaining_count
  FROM public.audiobook_music_categories;

  RAISE NOTICE 'Backfill completed: % category assignments remain after removing duplicates', remaining_count;
END $$;

-- =============================================================================
-- Step 2: Add unique constraint on audiobook_id (one category per audiobook)
-- =============================================================================

ALTER TABLE public.audiobook_music_categories
ADD CONSTRAINT audiobook_music_categories_unique_audiobook
UNIQUE (audiobook_id);

COMMENT ON CONSTRAINT audiobook_music_categories_unique_audiobook
ON public.audiobook_music_categories IS
'Enforces single category per music album (like Spotify). A music album cannot belong to multiple categories. Mutually exclusive categories.';

-- =============================================================================
-- Migration completed
-- =============================================================================

DO $$
BEGIN
  RAISE NOTICE 'Migration completed: Single category constraint added successfully';
  RAISE NOTICE 'Each music album can now have ONLY ONE category';
  RAISE NOTICE 'Rollback command: ALTER TABLE audiobook_music_categories DROP CONSTRAINT audiobook_music_categories_unique_audiobook;';
END $$;
