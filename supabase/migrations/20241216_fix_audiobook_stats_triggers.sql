-- Fix audiobook stats triggers
-- This migration fixes the review count trigger to handle DELETE properly
-- and adds a trigger to update total_duration_seconds when chapters change

-- =====================================================
-- 1. Fix review stats trigger to handle DELETE
-- =====================================================
CREATE OR REPLACE FUNCTION update_audiobook_rating()
RETURNS TRIGGER AS $$
DECLARE
    target_audiobook_id INTEGER;
BEGIN
    -- Determine which audiobook_id to use
    IF TG_OP = 'DELETE' THEN
        target_audiobook_id := OLD.audiobook_id;
    ELSE
        target_audiobook_id := NEW.audiobook_id;
    END IF;

    -- Update the audiobook stats
    UPDATE public.audiobooks
    SET
        avg_rating = (SELECT COALESCE(AVG(rating), 0) FROM public.reviews WHERE audiobook_id = target_audiobook_id AND is_approved = true),
        review_count = (SELECT COUNT(*) FROM public.reviews WHERE audiobook_id = target_audiobook_id AND is_approved = true)
    WHERE id = target_audiobook_id;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 2. Add trigger to update total_duration_seconds
-- =====================================================
CREATE OR REPLACE FUNCTION update_audiobook_duration()
RETURNS TRIGGER AS $$
DECLARE
    target_audiobook_id INTEGER;
BEGIN
    -- Determine which audiobook_id to use
    IF TG_OP = 'DELETE' THEN
        target_audiobook_id := OLD.audiobook_id;
    ELSE
        target_audiobook_id := NEW.audiobook_id;
    END IF;

    -- Update total duration by summing all chapter durations
    UPDATE public.audiobooks
    SET
        total_duration_seconds = (
            SELECT COALESCE(SUM(duration_seconds), 0)
            FROM public.chapters
            WHERE audiobook_id = target_audiobook_id
        ),
        chapter_count = (
            SELECT COUNT(*)
            FROM public.chapters
            WHERE audiobook_id = target_audiobook_id
        )
    WHERE id = target_audiobook_id;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger and create new one
DROP TRIGGER IF EXISTS on_chapter_change ON public.chapters;
CREATE TRIGGER on_chapter_change
    AFTER INSERT OR UPDATE OR DELETE ON public.chapters
    FOR EACH ROW EXECUTE FUNCTION update_audiobook_duration();

-- =====================================================
-- 3. Recalculate existing audiobook stats
-- =====================================================
-- Update all audiobooks with correct total_duration_seconds
UPDATE public.audiobooks a
SET
    total_duration_seconds = (
        SELECT COALESCE(SUM(c.duration_seconds), 0)
        FROM public.chapters c
        WHERE c.audiobook_id = a.id
    ),
    chapter_count = (
        SELECT COUNT(*)
        FROM public.chapters c
        WHERE c.audiobook_id = a.id
    );

-- Update all audiobooks with correct review stats
UPDATE public.audiobooks a
SET
    avg_rating = (
        SELECT COALESCE(AVG(r.rating), 0)
        FROM public.reviews r
        WHERE r.audiobook_id = a.id AND r.is_approved = true
    ),
    review_count = (
        SELECT COUNT(*)
        FROM public.reviews r
        WHERE r.audiobook_id = a.id AND r.is_approved = true
    );
