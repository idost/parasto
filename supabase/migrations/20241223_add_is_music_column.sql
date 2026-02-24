-- Migration: Add is_music column to audiobooks table
-- Purpose: Distinguish music content from audiobooks for separate display
-- Date: 2024-12-23
--
-- This is a backwards-compatible change:
-- - Existing rows default to is_music = false (treated as books)
-- - No RLS policy changes required (is_music is just a classification field)
-- - Entitlements, payments, and player behavior remain unchanged

-- Add the is_music column with default false
ALTER TABLE public.audiobooks
ADD COLUMN IF NOT EXISTS is_music boolean NOT NULL DEFAULT false;

-- Add an index for efficient filtering by is_music
-- This helps with queries like "get all music" or "get all books"
CREATE INDEX IF NOT EXISTS idx_audiobooks_is_music ON public.audiobooks(is_music);

-- Add a composite index for common query patterns (music + status)
CREATE INDEX IF NOT EXISTS idx_audiobooks_is_music_status ON public.audiobooks(is_music, status);

-- Comment for documentation
COMMENT ON COLUMN public.audiobooks.is_music IS 'True if this content is music (not an audiobook). Used to separate music from books in the app UI.';
