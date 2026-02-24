-- Migration: Add Archive Attribution Fields
-- Created: 2025-01-08
-- Purpose: Add archive_source and collection_source to music_metadata
--          for archive/collection attribution display (e.g., "از بایگانی", "از آرشیو")

-- =============================================================================
-- Add archive attribution fields to music_metadata
-- =============================================================================

DO $$
BEGIN
    -- Add archive_source column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'music_metadata'
        AND column_name = 'archive_source'
    ) THEN
        ALTER TABLE music_metadata
        ADD COLUMN archive_source TEXT;

        COMMENT ON COLUMN music_metadata.archive_source IS
          'Archive attribution displayed as "از بایگانی [value]" on detail screen (e.g., "موسیقی ایرانی")';
    END IF;

    -- Add collection_source column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'music_metadata'
        AND column_name = 'collection_source'
    ) THEN
        ALTER TABLE music_metadata
        ADD COLUMN collection_source TEXT;

        COMMENT ON COLUMN music_metadata.collection_source IS
          'Collection attribution displayed as "از آرشیو [value]" on detail screen (e.g., "استاد شجریان")';
    END IF;
END $$;

-- Log migration completion
DO $$
BEGIN
  RAISE NOTICE 'Migration completed: Added archive_source and collection_source to music_metadata';
END $$;
