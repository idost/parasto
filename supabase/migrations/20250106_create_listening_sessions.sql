-- =====================================================
-- LISTENING SESSIONS TABLE
-- =====================================================
-- This table tracks daily listening activity per audiobook
-- One record per user-audiobook-day combination
-- Used for accurate "days listening" stats and streak calculations
-- =====================================================

-- Create listening_sessions table
CREATE TABLE IF NOT EXISTS public.listening_sessions (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    audiobook_id INTEGER NOT NULL REFERENCES public.audiobooks(id) ON DELETE CASCADE,
    session_date DATE NOT NULL DEFAULT CURRENT_DATE,
    duration_seconds INTEGER DEFAULT 0,
    chapters_listened INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, audiobook_id, session_date)
);

-- Enable RLS
ALTER TABLE public.listening_sessions ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can manage own sessions" ON public.listening_sessions;
DROP POLICY IF EXISTS "Users can view own sessions" ON public.listening_sessions;
DROP POLICY IF EXISTS "Users can insert own sessions" ON public.listening_sessions;
DROP POLICY IF EXISTS "Users can update own sessions" ON public.listening_sessions;

-- Policy: Users can SELECT their own sessions
CREATE POLICY "Users can view own sessions" ON public.listening_sessions
    FOR SELECT USING (user_id = auth.uid());

-- Policy: Users can INSERT their own sessions
CREATE POLICY "Users can insert own sessions" ON public.listening_sessions
    FOR INSERT WITH CHECK (user_id = auth.uid());

-- Policy: Users can UPDATE their own sessions
CREATE POLICY "Users can update own sessions" ON public.listening_sessions
    FOR UPDATE USING (user_id = auth.uid());

-- Index for fast querying by user and date (for stats calculation)
CREATE INDEX IF NOT EXISTS idx_listening_sessions_user_date
ON public.listening_sessions(user_id, session_date DESC);

-- Index for fast querying by audiobook (for audiobook-specific stats)
CREATE INDEX IF NOT EXISTS idx_listening_sessions_audiobook
ON public.listening_sessions(audiobook_id);

-- =====================================================
-- BACKFILL: Populate initial data from listening_progress
-- =====================================================
-- This creates one session entry per existing listening_progress record
-- using the last_played_at date as the session_date
-- This provides a starting point for historical data

INSERT INTO public.listening_sessions (user_id, audiobook_id, session_date, duration_seconds, created_at, updated_at)
SELECT
    lp.user_id,
    lp.audiobook_id,
    DATE(lp.last_played_at) as session_date,
    lp.total_listen_time_seconds as duration_seconds,
    lp.last_played_at as created_at,
    NOW() as updated_at
FROM public.listening_progress lp
WHERE lp.user_id IS NOT NULL
  AND lp.audiobook_id IS NOT NULL
  AND lp.last_played_at IS NOT NULL
ON CONFLICT (user_id, audiobook_id, session_date) DO UPDATE SET
    duration_seconds = GREATEST(listening_sessions.duration_seconds, EXCLUDED.duration_seconds),
    updated_at = NOW();

-- =====================================================
-- COMMENTS
-- =====================================================
COMMENT ON TABLE public.listening_sessions IS 'Tracks daily listening activity per audiobook for accurate stats';
COMMENT ON COLUMN public.listening_sessions.session_date IS 'The date (YYYY-MM-DD) of the listening session';
COMMENT ON COLUMN public.listening_sessions.duration_seconds IS 'Total seconds listened on this date for this audiobook';
COMMENT ON COLUMN public.listening_sessions.chapters_listened IS 'Number of chapters listened to on this date';
