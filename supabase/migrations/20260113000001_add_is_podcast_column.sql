-- Migration: Add is_podcast column to audiobooks table
-- This enables podcasts as a third content type alongside books and music
-- Content type logic:
--   is_music=false, is_podcast=false → Audiobook
--   is_music=true,  is_podcast=false → Music
--   is_music=false, is_podcast=true  → Podcast

-- Add the is_podcast column
ALTER TABLE audiobooks ADD COLUMN IF NOT EXISTS is_podcast BOOLEAN DEFAULT FALSE;

-- Create index for podcast queries (approved podcasts, ordered by creation date)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audiobooks_podcast_approved
ON audiobooks(created_at DESC)
WHERE is_podcast = true AND status = 'approved';

-- Create composite index for library filtering by content type
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audiobooks_content_type_status
ON audiobooks(is_music, is_podcast, status, created_at DESC);

-- Add comment for documentation
COMMENT ON COLUMN audiobooks.is_podcast IS 'True if this content is a podcast. Mutually exclusive with is_music (a podcast should have is_music=false).';
