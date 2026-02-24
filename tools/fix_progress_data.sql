-- ============================================================================
-- ONE-TIME PROGRESS DATA CLEANUP - SQL VERSION
-- ============================================================================
--
-- PURPOSE:
-- Recalculate completion_percentage for all listening_progress rows
-- using the corrected album-level calculation.
--
-- HOW TO RUN:
-- 1. Go to Supabase Dashboard → SQL Editor
-- 2. BACKUP YOUR DATABASE FIRST
-- 3. Run STEP 1 first to preview changes
-- 4. If the output looks correct, run STEP 2 to apply changes
--
-- ============================================================================

-- ============================================================================
-- STEP 1: DRY RUN - Preview what will change (RUN THIS FIRST)
-- ============================================================================

WITH chapter_stats AS (
    -- Calculate total duration per audiobook
    SELECT
        audiobook_id,
        COUNT(*) as total_chapters,
        SUM(COALESCE(duration_seconds, 0)) as total_duration
    FROM chapters
    GROUP BY audiobook_id
),
previous_chapters_time AS (
    -- Calculate sum of duration for chapters BEFORE current chapter
    SELECT
        lp.id as progress_id,
        lp.audiobook_id,
        lp.current_chapter_index,
        COALESCE(SUM(c.duration_seconds), 0) as previous_completed
    FROM listening_progress lp
    LEFT JOIN chapters c ON c.audiobook_id = lp.audiobook_id
        AND c.chapter_index < lp.current_chapter_index
    GROUP BY lp.id, lp.audiobook_id, lp.current_chapter_index
),
current_chapter_duration AS (
    -- Get duration of the current chapter
    SELECT
        lp.id as progress_id,
        COALESCE(c.duration_seconds, 0) as current_dur
    FROM listening_progress lp
    LEFT JOIN chapters c ON c.audiobook_id = lp.audiobook_id
        AND c.chapter_index = lp.current_chapter_index
),
calculated AS (
    SELECT
        lp.id,
        lp.audiobook_id,
        lp.user_id,
        lp.completion_percentage as old_pct,
        lp.is_completed,
        lp.current_chapter_index,
        lp.position_seconds,
        cs.total_duration,
        pct.previous_completed,
        ccd.current_dur,
        -- Calculate current chapter contribution
        -- Cap position at chapter duration, apply 95% threshold
        CASE
            WHEN ccd.current_dur > 0 AND
                 (LEAST(lp.position_seconds, ccd.current_dur)::float / ccd.current_dur) >= 0.95
            THEN ccd.current_dur
            ELSE LEAST(lp.position_seconds, GREATEST(ccd.current_dur, lp.position_seconds))
        END as current_contribution,
        -- Total completed seconds
        pct.previous_completed +
        CASE
            WHEN ccd.current_dur > 0 AND
                 (LEAST(lp.position_seconds, ccd.current_dur)::float / ccd.current_dur) >= 0.95
            THEN ccd.current_dur
            ELSE LEAST(lp.position_seconds, GREATEST(ccd.current_dur, lp.position_seconds))
        END as total_completed
    FROM listening_progress lp
    JOIN chapter_stats cs ON cs.audiobook_id = lp.audiobook_id
    LEFT JOIN previous_chapters_time pct ON pct.progress_id = lp.id
    LEFT JOIN current_chapter_duration ccd ON ccd.progress_id = lp.id
),
new_percentages AS (
    SELECT
        c.*,
        -- Calculate raw percentage
        CASE
            WHEN c.total_duration > 0
            THEN (c.total_completed::float * 100.0 / c.total_duration)
            ELSE 0
        END as raw_pct,
        -- Apply 98% near-completion threshold and is_completed override
        CASE
            WHEN c.is_completed = true THEN 100
            WHEN c.total_duration > 0 AND
                 (c.total_completed::float * 100.0 / c.total_duration) >= 98 THEN 100
            WHEN c.total_duration > 0
            THEN LEAST(100, GREATEST(0, ROUND(c.total_completed::float * 100.0 / c.total_duration)))::int
            ELSE 0
        END as new_pct
    FROM calculated c
)
SELECT
    id,
    audiobook_id,
    current_chapter_index,
    position_seconds,
    total_duration,
    previous_completed,
    current_dur as current_chapter_dur,
    total_completed,
    ROUND(raw_pct::numeric, 1) as raw_pct,
    old_pct,
    new_pct,
    (new_pct - old_pct) as diff,
    CASE
        WHEN ABS(new_pct - old_pct) >= 1 THEN 'WILL UPDATE'
        ELSE 'NO CHANGE'
    END as action
FROM new_percentages
WHERE ABS(new_pct - old_pct) >= 1
ORDER BY ABS(new_pct - old_pct) DESC
LIMIT 50;

-- ============================================================================
-- STEP 2: APPLY CHANGES (RUN THIS AFTER REVIEWING STEP 1)
-- ============================================================================
-- UNCOMMENT AND RUN THIS SECTION ONLY AFTER BACKUP AND DRY RUN REVIEW

/*
WITH chapter_stats AS (
    SELECT
        audiobook_id,
        SUM(COALESCE(duration_seconds, 0)) as total_duration
    FROM chapters
    GROUP BY audiobook_id
),
previous_chapters_time AS (
    SELECT
        lp.id as progress_id,
        COALESCE(SUM(c.duration_seconds), 0) as previous_completed
    FROM listening_progress lp
    LEFT JOIN chapters c ON c.audiobook_id = lp.audiobook_id
        AND c.chapter_index < lp.current_chapter_index
    GROUP BY lp.id
),
current_chapter_duration AS (
    SELECT
        lp.id as progress_id,
        COALESCE(c.duration_seconds, 0) as current_dur
    FROM listening_progress lp
    LEFT JOIN chapters c ON c.audiobook_id = lp.audiobook_id
        AND c.chapter_index = lp.current_chapter_index
),
new_percentages AS (
    SELECT
        lp.id,
        lp.is_completed,
        cs.total_duration,
        pct.previous_completed +
        CASE
            WHEN ccd.current_dur > 0 AND
                 (LEAST(lp.position_seconds, ccd.current_dur)::float / ccd.current_dur) >= 0.95
            THEN ccd.current_dur
            ELSE LEAST(lp.position_seconds, GREATEST(ccd.current_dur, lp.position_seconds))
        END as total_completed
    FROM listening_progress lp
    JOIN chapter_stats cs ON cs.audiobook_id = lp.audiobook_id
    LEFT JOIN previous_chapters_time pct ON pct.progress_id = lp.id
    LEFT JOIN current_chapter_duration ccd ON ccd.progress_id = lp.id
),
calculated_pct AS (
    SELECT
        np.id,
        CASE
            WHEN np.is_completed = true THEN 100
            WHEN np.total_duration > 0 AND
                 (np.total_completed::float * 100.0 / np.total_duration) >= 98 THEN 100
            WHEN np.total_duration > 0
            THEN LEAST(100, GREATEST(0, ROUND(np.total_completed::float * 100.0 / np.total_duration)))::int
            ELSE 0
        END as new_pct
    FROM new_percentages np
)
UPDATE listening_progress lp
SET completion_percentage = cp.new_pct
FROM calculated_pct cp
WHERE lp.id = cp.id
  AND ABS(cp.new_pct - lp.completion_percentage) >= 1;
*/

-- ============================================================================
-- VERIFICATION QUERY (Run after STEP 2 to verify changes)
-- ============================================================================

/*
SELECT
    completion_percentage,
    COUNT(*) as count
FROM listening_progress
GROUP BY completion_percentage
ORDER BY completion_percentage;
*/
