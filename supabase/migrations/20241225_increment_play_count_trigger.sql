-- Migration: Add trigger to increment play_count when user listens
-- Purpose: Track actual listening activity for "پُرشنونده‌ترین‌ها" (Most Popular) section
-- Date: 2024-12-25
--
-- This migration creates:
-- 1. A trigger function that increments play_count on audiobooks
-- 2. A trigger that fires on INSERT to listening_progress (first time user listens)
-- 3. Only increments once per user per audiobook (INSERT only, not UPDATE)

-- ==============================================
-- 1. Create function to increment play_count
-- ==============================================
CREATE OR REPLACE FUNCTION increment_audiobook_play_count()
RETURNS TRIGGER AS $$
BEGIN
    -- Only increment play_count on INSERT (new listening record)
    -- This means it increments once per user per audiobook (first listen)
    IF TG_OP = 'INSERT' THEN
        UPDATE public.audiobooks
        SET play_count = COALESCE(play_count, 0) + 1
        WHERE id = NEW.audiobook_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add comment for documentation
COMMENT ON FUNCTION increment_audiobook_play_count() IS
'Increments play_count on audiobooks table when a new listening_progress record is created. This tracks unique listeners per audiobook.';

-- ==============================================
-- 2. Create trigger on listening_progress
-- ==============================================
DROP TRIGGER IF EXISTS on_listening_progress_insert ON public.listening_progress;
CREATE TRIGGER on_listening_progress_insert
    AFTER INSERT ON public.listening_progress
    FOR EACH ROW
    EXECUTE FUNCTION increment_audiobook_play_count();

-- ==============================================
-- 3. Recalculate existing play_counts from actual data
-- ==============================================
-- Reset all play_counts based on actual listening_progress records
UPDATE public.audiobooks a
SET play_count = (
    SELECT COUNT(DISTINCT user_id)
    FROM public.listening_progress lp
    WHERE lp.audiobook_id = a.id
);

-- Add index for faster play_count ordering (if not exists)
CREATE INDEX IF NOT EXISTS idx_audiobooks_play_count ON public.audiobooks(play_count DESC);
