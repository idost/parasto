-- Migration: Add Producer Field to Music Metadata
-- Created: 2025-01-08
-- Purpose: Add producer field to music_metadata table for better music credit tracking

-- Add producer column to music_metadata table if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'music_metadata'
        AND column_name = 'producer'
    ) THEN
        ALTER TABLE music_metadata
        ADD COLUMN producer TEXT;

        COMMENT ON COLUMN music_metadata.producer IS
          'Producer name (Persian) - the person/team who produced the track/album';
    END IF;
END $$;

-- Log migration completion
DO $$
BEGIN
  RAISE NOTICE 'Migration completed: Added producer field to music_metadata';
END $$;
