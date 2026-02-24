-- Migration: Add Music Display Fields
-- Created: 2025-01-07
-- Purpose: Add is_primary to audiobook_creators and collection_label to creators
--          for enhanced music album detail screen display

-- =============================================================================
-- PART 1: Add is_primary column to audiobook_creators
-- =============================================================================

-- Add the is_primary boolean column (defaults to false) if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'audiobook_creators'
        AND column_name = 'is_primary'
    ) THEN
        ALTER TABLE audiobook_creators
        ADD COLUMN is_primary BOOLEAN DEFAULT false;

        COMMENT ON COLUMN audiobook_creators.is_primary IS
          'Marks this creator as the primary display creator for this audiobook (shown prominently under title on detail screen)';
    END IF;
END $$;

-- Create unique partial index if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = 'public'
        AND tablename = 'audiobook_creators'
        AND indexname = 'idx_audiobook_creators_primary'
    ) THEN
        CREATE UNIQUE INDEX idx_audiobook_creators_primary
        ON audiobook_creators(audiobook_id)
        WHERE is_primary = true;
    END IF;
END $$;

-- =============================================================================
-- PART 2: Add collection_label column to creators
-- =============================================================================

-- Add the collection_label text column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'creators'
        AND column_name = 'collection_label'
    ) THEN
        ALTER TABLE creators
        ADD COLUMN collection_label TEXT;

        COMMENT ON COLUMN creators.collection_label IS
          'Optional collection/archive attribution displayed below creator name (e.g., "از گنجهء استاد شجریان", "از آرشیو موسیقی ایرانی", "از نگارستان هنر")';
    END IF;
END $$;

-- =============================================================================
-- PART 3: Backfill existing data
-- =============================================================================

-- Mark the first singer/artist (sort_order=0) as primary for all music albums
-- This ensures existing music albums have a default primary creator
UPDATE audiobook_creators ac
SET is_primary = true
WHERE ac.role IN ('singer', 'artist')
  AND ac.sort_order = 0
  AND ac.audiobook_id IN (
    SELECT id FROM audiobooks WHERE is_music = true
  )
  AND NOT EXISTS (
    -- Safety check: Ensure we don't mark multiple singers if sort_order isn't properly set
    SELECT 1 FROM audiobook_creators ac2
    WHERE ac2.audiobook_id = ac.audiobook_id
      AND ac2.role IN ('singer', 'artist')
      AND ac2.sort_order < ac.sort_order
  );

-- Log migration completion
DO $$
DECLARE
  updated_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO updated_count
  FROM audiobook_creators
  WHERE is_primary = true;

  RAISE NOTICE 'Migration completed: % creators marked as primary', updated_count;
END $$;
