-- =====================================================================
-- COMBINED SUPABASE MIGRATIONS
-- Generated: 2026-01-13
-- Run this file in the Supabase SQL Editor (Dashboard > SQL Editor)
-- =====================================================================
-- Note: Run sections one at a time if you encounter errors
-- Some tables/columns may already exist - IF NOT EXISTS handles this
-- =====================================================================


-- ==========================================================================
-- MIGRATION 1: LISTENING SESSIONS TABLE (20250106)
-- ==========================================================================

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

ALTER TABLE public.listening_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own sessions" ON public.listening_sessions;
DROP POLICY IF EXISTS "Users can insert own sessions" ON public.listening_sessions;
DROP POLICY IF EXISTS "Users can update own sessions" ON public.listening_sessions;

CREATE POLICY "Users can view own sessions" ON public.listening_sessions
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can insert own sessions" ON public.listening_sessions
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own sessions" ON public.listening_sessions
    FOR UPDATE USING (user_id = auth.uid());

CREATE INDEX IF NOT EXISTS idx_listening_sessions_user_date
ON public.listening_sessions(user_id, session_date DESC);

CREATE INDEX IF NOT EXISTS idx_listening_sessions_audiobook
ON public.listening_sessions(audiobook_id);

-- Backfill from listening_progress
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


-- ==========================================================================
-- MIGRATION 2: MUSIC DISPLAY FIELDS (20250107)
-- ==========================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'audiobook_creators'
        AND column_name = 'is_primary'
    ) THEN
        ALTER TABLE audiobook_creators ADD COLUMN is_primary BOOLEAN DEFAULT false;
    END IF;
END $$;

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

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'creators'
        AND column_name = 'collection_label'
    ) THEN
        ALTER TABLE creators ADD COLUMN collection_label TEXT;
    END IF;
END $$;

-- Mark first singer as primary for music albums
UPDATE audiobook_creators ac
SET is_primary = true
WHERE ac.role IN ('singer', 'artist')
  AND ac.sort_order = 0
  AND ac.audiobook_id IN (SELECT id FROM audiobooks WHERE is_music = true)
  AND NOT EXISTS (
    SELECT 1 FROM audiobook_creators ac2
    WHERE ac2.audiobook_id = ac.audiobook_id
      AND ac2.role IN ('singer', 'artist')
      AND ac2.sort_order < ac.sort_order
  );


-- ==========================================================================
-- MIGRATION 3: SECURE PURCHASES TABLE (20250107)
-- ==========================================================================

ALTER TABLE purchases ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own purchases" ON purchases;
DROP POLICY IF EXISTS "Admins can view all purchases" ON purchases;
DROP POLICY IF EXISTS "Service role only can insert purchases" ON purchases;
DROP POLICY IF EXISTS "Prevent purchase updates" ON purchases;
DROP POLICY IF EXISTS "Prevent purchase deletes" ON purchases;

CREATE POLICY "Users can view own purchases" ON public.purchases
FOR SELECT TO authenticated USING (user_id = auth.uid());

CREATE POLICY "Admins can view all purchases" ON public.purchases
FOR SELECT TO authenticated
USING (EXISTS (
    SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
));

CREATE POLICY "Service role only can insert purchases" ON public.purchases
FOR INSERT TO service_role WITH CHECK (true);

CREATE POLICY "Prevent purchase updates" ON public.purchases
FOR UPDATE USING (false);

CREATE POLICY "Prevent purchase deletes" ON public.purchases
FOR DELETE USING (false);


-- ==========================================================================
-- MIGRATION 4: BOOK_METADATA AUTHOR REQUIRED (20250107)
-- ==========================================================================

UPDATE book_metadata SET author_name = 'نامشخص' WHERE author_name IS NULL OR author_name = '';
UPDATE book_metadata SET author_name = 'نامشخص' WHERE TRIM(author_name) = '';

ALTER TABLE book_metadata ALTER COLUMN author_name SET NOT NULL;

-- Add check constraint (if not exists)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'book_metadata'
        AND constraint_name = 'book_metadata_author_name_not_empty'
    ) THEN
        ALTER TABLE book_metadata
        ADD CONSTRAINT book_metadata_author_name_not_empty
        CHECK (author_name IS NOT NULL AND TRIM(author_name) != '');
    END IF;
END $$;


-- ==========================================================================
-- MIGRATION 5: ADD PRODUCER FIELD (20250108)
-- ==========================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'music_metadata'
        AND column_name = 'producer'
    ) THEN
        ALTER TABLE music_metadata ADD COLUMN producer TEXT;
    END IF;
END $$;


-- ==========================================================================
-- MIGRATION 6: ADD ARCHIVE FIELDS TO MUSIC_METADATA (20250108)
-- ==========================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'music_metadata' AND column_name = 'archive_source'
    ) THEN
        ALTER TABLE music_metadata ADD COLUMN archive_source TEXT;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'music_metadata' AND column_name = 'collection_source'
    ) THEN
        ALTER TABLE music_metadata ADD COLUMN collection_source TEXT;
    END IF;
END $$;


-- ==========================================================================
-- MIGRATION 7: ADD ICON TO CATEGORIES (20250108)
-- ==========================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'categories' AND column_name = 'icon'
    ) THEN
        ALTER TABLE public.categories ADD COLUMN icon TEXT;
    END IF;
END $$;


-- ==========================================================================
-- MIGRATION 8: SINGLE MUSIC CATEGORY CONSTRAINT (20250108)
-- ==========================================================================

-- Remove duplicate category assignments (keep lowest category_id)
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

-- Add unique constraint (if not exists)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'audiobook_music_categories'
        AND constraint_name = 'audiobook_music_categories_unique_audiobook'
    ) THEN
        ALTER TABLE public.audiobook_music_categories
        ADD CONSTRAINT audiobook_music_categories_unique_audiobook UNIQUE (audiobook_id);
    END IF;
END $$;


-- ==========================================================================
-- MIGRATION 9: ADD ARCHIVE/COLLECTION TO BOOK_METADATA (20250108)
-- ==========================================================================

ALTER TABLE public.book_metadata ADD COLUMN IF NOT EXISTS archive_source TEXT;
ALTER TABLE public.book_metadata ADD COLUMN IF NOT EXISTS collection_source TEXT;


-- ==========================================================================
-- MIGRATION 10: NARRATOR REQUESTS TABLE (20250109)
-- ==========================================================================

CREATE TABLE IF NOT EXISTS public.narrator_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    experience_text TEXT NOT NULL,
    voice_sample_path TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    reviewed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    admin_feedback TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- One pending request per user
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_narrator_requests_one_pending_per_user') THEN
        CREATE UNIQUE INDEX idx_narrator_requests_one_pending_per_user
            ON public.narrator_requests(user_id) WHERE status = 'pending';
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_narrator_requests_status ON public.narrator_requests(status);
CREATE INDEX IF NOT EXISTS idx_narrator_requests_created_at ON public.narrator_requests(created_at DESC);

ALTER TABLE public.narrator_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own requests" ON public.narrator_requests;
DROP POLICY IF EXISTS "Users can create own requests" ON public.narrator_requests;
DROP POLICY IF EXISTS "Admins can view all requests" ON public.narrator_requests;
DROP POLICY IF EXISTS "Admins can update all requests" ON public.narrator_requests;
DROP POLICY IF EXISTS "Admins can delete all requests" ON public.narrator_requests;

CREATE POLICY "Users can view own requests" ON public.narrator_requests
    FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE POLICY "Users can create own requests" ON public.narrator_requests
    FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can view all requests" ON public.narrator_requests
    FOR SELECT TO authenticated
    USING (EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin'));

CREATE POLICY "Admins can update all requests" ON public.narrator_requests
    FOR UPDATE TO authenticated
    USING (EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin'));

CREATE POLICY "Admins can delete all requests" ON public.narrator_requests
    FOR DELETE TO authenticated
    USING (EXISTS (SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin'));

-- Storage bucket for voice samples
INSERT INTO storage.buckets (id, name, public)
VALUES ('narrator-requests', 'narrator-requests', false)
ON CONFLICT (id) DO NOTHING;

-- Storage policies
DROP POLICY IF EXISTS "Users can upload own voice samples" ON storage.objects;
DROP POLICY IF EXISTS "Users can view own voice samples" ON storage.objects;
DROP POLICY IF EXISTS "Admins can view all voice samples" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own voice samples" ON storage.objects;

CREATE POLICY "Users can upload own voice samples" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'narrator-requests' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Users can view own voice samples" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'narrator-requests' AND (storage.foldername(name))[1] = auth.uid()::text);

CREATE POLICY "Admins can view all voice samples" ON storage.objects
    FOR SELECT TO authenticated
    USING (bucket_id = 'narrator-requests' AND EXISTS (
        SELECT 1 FROM public.profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    ));

CREATE POLICY "Users can delete own voice samples" ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'narrator-requests' AND (storage.foldername(name))[1] = auth.uid()::text);

-- Updated_at trigger
CREATE OR REPLACE FUNCTION public.update_narrator_requests_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS narrator_requests_updated_at_trigger ON public.narrator_requests;
CREATE TRIGGER narrator_requests_updated_at_trigger
    BEFORE UPDATE ON public.narrator_requests
    FOR EACH ROW EXECUTE FUNCTION public.update_narrator_requests_updated_at();


-- ==========================================================================
-- MIGRATION 11: AUDIT LOGS TABLE (20250110)
-- ==========================================================================

CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID REFERENCES auth.users(id),
    actor_email TEXT,
    action TEXT NOT NULL CHECK (action IN (
        'create', 'update', 'delete', 'approve', 'reject',
        'feature', 'unfeature', 'ban', 'unban', 'role_change',
        'login', 'logout', 'export', 'import', 'bulk_action'
    )),
    entity_type TEXT NOT NULL CHECK (entity_type IN (
        'audiobook', 'user', 'creator', 'category',
        'ticket', 'narrator_request', 'promotion', 'schedule', 'settings'
    )),
    entity_id TEXT NOT NULL,
    old_values JSONB,
    new_values JSONB,
    changed_fields TEXT[],
    description TEXT,
    ip_address TEXT,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_actor ON audit_logs(actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at DESC);

ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can read audit_logs" ON audit_logs;
DROP POLICY IF EXISTS "Authenticated users can insert audit_logs" ON audit_logs;

CREATE POLICY "Admins can read audit_logs" ON audit_logs
FOR SELECT TO authenticated
USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin'));

CREATE POLICY "Authenticated users can insert audit_logs" ON audit_logs
FOR INSERT TO authenticated WITH CHECK (actor_id = auth.uid());


-- ==========================================================================
-- MIGRATION 12: SCHEDULING TABLES (20250110)
-- ==========================================================================

CREATE TABLE IF NOT EXISTS scheduled_features (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    audiobook_id INTEGER NOT NULL REFERENCES audiobooks(id) ON DELETE CASCADE,
    feature_type TEXT NOT NULL DEFAULT 'featured' CHECK (feature_type IN ('featured', 'banner', 'hero', 'category_highlight')),
    status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'active', 'completed', 'cancelled')),
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ,
    priority INTEGER DEFAULT 0,
    notes TEXT,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_scheduled_features_audiobook ON scheduled_features(audiobook_id);
CREATE INDEX IF NOT EXISTS idx_scheduled_features_status ON scheduled_features(status);
CREATE INDEX IF NOT EXISTS idx_scheduled_features_dates ON scheduled_features(start_date, end_date);

CREATE TABLE IF NOT EXISTS scheduled_promotions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    audiobook_id INTEGER REFERENCES audiobooks(id) ON DELETE CASCADE,
    category_id INTEGER REFERENCES categories(id) ON DELETE CASCADE,
    creator_id UUID REFERENCES creators(id) ON DELETE CASCADE,
    scope TEXT NOT NULL DEFAULT 'single' CHECK (scope IN ('single', 'category', 'creator', 'all')),
    discount_type TEXT NOT NULL DEFAULT 'percentage' CHECK (discount_type IN ('percentage', 'fixed')),
    discount_value DECIMAL(10,2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'active', 'completed', 'cancelled')),
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    title_fa TEXT NOT NULL,
    title_en TEXT,
    description TEXT,
    banner_url TEXT,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_scheduled_promotions_status ON scheduled_promotions(status);
CREATE INDEX IF NOT EXISTS idx_scheduled_promotions_dates ON scheduled_promotions(start_date, end_date);

ALTER TABLE scheduled_features ENABLE ROW LEVEL SECURITY;
ALTER TABLE scheduled_promotions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage scheduled_features" ON scheduled_features;
DROP POLICY IF EXISTS "Admins can manage scheduled_promotions" ON scheduled_promotions;

CREATE POLICY "Admins can manage scheduled_features" ON scheduled_features
FOR ALL TO authenticated
USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin'));

CREATE POLICY "Admins can manage scheduled_promotions" ON scheduled_promotions
FOR ALL TO authenticated
USING (EXISTS (SELECT 1 FROM profiles WHERE profiles.id = auth.uid() AND profiles.role = 'admin'));


-- ==========================================================================
-- MIGRATION 13: FIX RLS WITH CHECK (20250110)
-- ==========================================================================

DROP POLICY IF EXISTS "Narrators can update own audiobooks" ON public.audiobooks;
CREATE POLICY "Narrators can update own audiobooks" ON public.audiobooks
    FOR UPDATE USING (narrator_id = auth.uid()) WITH CHECK (narrator_id = auth.uid());

DROP POLICY IF EXISTS "Narrators can update own chapters" ON public.chapters;
CREATE POLICY "Narrators can update own chapters" ON public.chapters
    FOR UPDATE
    USING (EXISTS (SELECT 1 FROM audiobooks WHERE audiobooks.id = chapters.audiobook_id AND audiobooks.narrator_id = auth.uid()))
    WITH CHECK (EXISTS (SELECT 1 FROM audiobooks WHERE audiobooks.id = chapters.audiobook_id AND audiobooks.narrator_id = auth.uid()));

DROP POLICY IF EXISTS "Narrators can update own book_metadata" ON public.book_metadata;
CREATE POLICY "Narrators can update own book_metadata" ON public.book_metadata
    FOR UPDATE
    USING (EXISTS (SELECT 1 FROM audiobooks WHERE audiobooks.id = book_metadata.audiobook_id AND audiobooks.narrator_id = auth.uid()))
    WITH CHECK (EXISTS (SELECT 1 FROM audiobooks WHERE audiobooks.id = book_metadata.audiobook_id AND audiobooks.narrator_id = auth.uid()));

DROP POLICY IF EXISTS "Narrators can update own music_metadata" ON public.music_metadata;
CREATE POLICY "Narrators can update own music_metadata" ON public.music_metadata
    FOR UPDATE
    USING (EXISTS (SELECT 1 FROM audiobooks WHERE audiobooks.id = music_metadata.audiobook_id AND audiobooks.narrator_id = auth.uid()))
    WITH CHECK (EXISTS (SELECT 1 FROM audiobooks WHERE audiobooks.id = music_metadata.audiobook_id AND audiobooks.narrator_id = auth.uid()));


-- ==========================================================================
-- MIGRATION 14: UPDATE OLD AUDIOBOOK STATUSES (20250110)
-- ==========================================================================

-- Update NULL status to approved
UPDATE audiobooks SET status = 'approved', updated_at = NOW() WHERE status IS NULL;

-- Update draft audiobooks with chapters to approved
UPDATE audiobooks SET status = 'approved', updated_at = NOW()
WHERE status = 'draft' AND chapter_count > 0
AND EXISTS (SELECT 1 FROM chapters WHERE chapters.audiobook_id = audiobooks.id);

-- Update submitted audiobooks with chapters to approved
UPDATE audiobooks SET status = 'approved', updated_at = NOW()
WHERE status = 'submitted' AND chapter_count > 0
AND EXISTS (SELECT 1 FROM chapters WHERE chapters.audiobook_id = audiobooks.id);

-- Set is_music to false where NULL
UPDATE audiobooks SET is_music = false WHERE is_music IS NULL;


-- ==========================================================================
-- MIGRATION 15: ADVANCED SEARCH SYSTEM (20250110)
-- ==========================================================================

DROP MATERIALIZED VIEW IF EXISTS public.content_search_index CASCADE;

CREATE MATERIALIZED VIEW public.content_search_index AS
SELECT
    a.id,
    a.title_fa,
    a.title_en,
    a.description_fa,
    a.cover_url,
    a.is_music,
    a.is_free,
    a.status,
    a.category_id,
    a.play_count,
    a.avg_rating,
    a.created_at,
    a.total_duration_seconds,
    COALESCE(a.author_fa, bm.author_name, mm.artist_name, '') AS author_display,
    COALESCE(bm.narrator_name, '') AS narrator_display,
    COALESCE(mm.composer, '') AS composer_display,
    COALESCE(mm.lyricist, '') AS lyricist_display,
    COALESCE((SELECT string_agg(ch.title_fa, ' ') FROM public.chapters ch WHERE ch.audiobook_id = a.id), '') AS chapters_text,
    cat.name_fa AS category_name,
    setweight(to_tsvector('simple', COALESCE(a.title_fa, '')), 'A') ||
    setweight(to_tsvector('simple', COALESCE(a.title_en, '')), 'A') ||
    setweight(to_tsvector('simple', COALESCE(a.author_fa, '')), 'B') ||
    setweight(to_tsvector('simple', COALESCE(bm.author_name, '')), 'B') ||
    setweight(to_tsvector('simple', COALESCE(mm.artist_name, '')), 'B') ||
    setweight(to_tsvector('simple', COALESCE(bm.narrator_name, '')), 'C') ||
    setweight(to_tsvector('simple', COALESCE(mm.composer, '')), 'C') ||
    setweight(to_tsvector('simple', COALESCE(mm.lyricist, '')), 'C') ||
    setweight(to_tsvector('simple', COALESCE((SELECT string_agg(ch.title_fa, ' ') FROM public.chapters ch WHERE ch.audiobook_id = a.id), '')), 'D') ||
    setweight(to_tsvector('simple', COALESCE(a.description_fa, '')), 'D')
    AS search_vector
FROM public.audiobooks a
LEFT JOIN public.book_metadata bm ON a.id = bm.audiobook_id
LEFT JOIN public.music_metadata mm ON a.id = mm.audiobook_id
LEFT JOIN public.categories cat ON a.category_id = cat.id
WHERE a.status = 'approved';

CREATE UNIQUE INDEX IF NOT EXISTS idx_content_search_id ON public.content_search_index(id);
CREATE INDEX IF NOT EXISTS idx_content_search_vector ON public.content_search_index USING GIN(search_vector);
CREATE INDEX IF NOT EXISTS idx_content_search_music ON public.content_search_index(is_music);
CREATE INDEX IF NOT EXISTS idx_content_search_category ON public.content_search_index(category_id);
CREATE INDEX IF NOT EXISTS idx_content_search_free ON public.content_search_index(is_free);

CREATE OR REPLACE FUNCTION public.refresh_content_search_index()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY public.content_search_index;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Search function
DROP FUNCTION IF EXISTS public.search_content(TEXT, TEXT, INTEGER, BOOLEAN, INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION public.search_content(
    query_text TEXT,
    content_type TEXT DEFAULT NULL,
    category_filter INTEGER DEFAULT NULL,
    free_only BOOLEAN DEFAULT FALSE,
    result_limit INTEGER DEFAULT 50,
    result_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    id INTEGER, title_fa TEXT, title_en TEXT, description_fa TEXT, cover_url TEXT,
    is_music BOOLEAN, is_free BOOLEAN, category_id INTEGER, category_name TEXT,
    play_count INTEGER, avg_rating NUMERIC, created_at TIMESTAMPTZ, total_duration_seconds INTEGER,
    author_display TEXT, narrator_display TEXT, composer_display TEXT, lyricist_display TEXT,
    chapters_text TEXT, rank REAL, matched_in TEXT
) AS $$
DECLARE
    search_query tsquery;
    normalized_query TEXT;
    has_text_query BOOLEAN;
BEGIN
    normalized_query := trim(COALESCE(query_text, ''));
    has_text_query := length(normalized_query) >= 2;

    IF NOT has_text_query AND content_type IS NULL AND category_filter IS NULL AND NOT free_only THEN
        RETURN;
    END IF;

    IF has_text_query THEN
        search_query := plainto_tsquery('simple', normalized_query);
    END IF;

    RETURN QUERY
    SELECT
        csi.id, csi.title_fa, csi.title_en, csi.description_fa, csi.cover_url,
        csi.is_music, csi.is_free, csi.category_id, csi.category_name,
        csi.play_count, csi.avg_rating, csi.created_at, csi.total_duration_seconds,
        csi.author_display, csi.narrator_display, csi.composer_display, csi.lyricist_display,
        csi.chapters_text,
        CASE WHEN has_text_query THEN ts_rank_cd(csi.search_vector, search_query) ELSE 0.0 END AS rank,
        CASE
            WHEN NOT has_text_query THEN 'content'
            WHEN csi.title_fa ILIKE '%' || normalized_query || '%' OR csi.title_en ILIKE '%' || normalized_query || '%' THEN 'title'
            WHEN csi.author_display ILIKE '%' || normalized_query || '%' THEN CASE WHEN csi.is_music THEN 'artist' ELSE 'author' END
            WHEN csi.narrator_display ILIKE '%' || normalized_query || '%' THEN 'narrator'
            WHEN csi.composer_display ILIKE '%' || normalized_query || '%' THEN 'composer'
            WHEN csi.lyricist_display ILIKE '%' || normalized_query || '%' THEN 'lyricist'
            WHEN csi.chapters_text ILIKE '%' || normalized_query || '%' THEN 'chapter'
            WHEN csi.description_fa ILIKE '%' || normalized_query || '%' THEN 'description'
            ELSE 'content'
        END AS matched_in
    FROM public.content_search_index csi
    WHERE
        (NOT has_text_query OR (
            csi.search_vector @@ search_query
            OR csi.title_fa ILIKE '%' || normalized_query || '%'
            OR csi.title_en ILIKE '%' || normalized_query || '%'
            OR csi.author_display ILIKE '%' || normalized_query || '%'
            OR csi.narrator_display ILIKE '%' || normalized_query || '%'
            OR csi.composer_display ILIKE '%' || normalized_query || '%'
            OR csi.lyricist_display ILIKE '%' || normalized_query || '%'
            OR csi.chapters_text ILIKE '%' || normalized_query || '%'
        ))
        AND (content_type IS NULL OR (content_type = 'book' AND csi.is_music = FALSE) OR (content_type = 'music' AND csi.is_music = TRUE))
        AND (category_filter IS NULL OR csi.category_id = category_filter)
        AND (free_only = FALSE OR csi.is_free = TRUE)
    ORDER BY
        CASE WHEN has_text_query AND csi.title_fa ILIKE normalized_query || '%' THEN 0 ELSE 1 END,
        rank DESC,
        csi.play_count DESC
    LIMIT result_limit OFFSET result_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

GRANT SELECT ON public.content_search_index TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.search_content TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.refresh_content_search_index TO authenticated;

REFRESH MATERIALIZED VIEW public.content_search_index;


-- ==========================================================================
-- MIGRATION 16: SCALABILITY INDEXES (20260112)
-- ==========================================================================

CREATE INDEX IF NOT EXISTS idx_audiobooks_status_music_created ON audiobooks(status, is_music, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audiobooks_play_count ON audiobooks(play_count DESC NULLS LAST) WHERE status = 'approved';
CREATE INDEX IF NOT EXISTS idx_audiobooks_category_status ON audiobooks(category_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audiobooks_approved_created ON audiobooks(created_at DESC) WHERE status = 'approved';
CREATE INDEX IF NOT EXISTS idx_audiobooks_narrator ON audiobooks(narrator_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_listening_progress_user_updated ON listening_progress(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_listening_progress_user_audiobook ON listening_progress(user_id, audiobook_id);
CREATE INDEX IF NOT EXISTS idx_entitlements_user_audiobook ON entitlements(user_id, audiobook_id);
CREATE INDEX IF NOT EXISTS idx_chapters_audiobook_index ON chapters(audiobook_id, chapter_index);
CREATE INDEX IF NOT EXISTS idx_listening_sessions_user_date ON listening_sessions(user_id, session_date DESC);
CREATE INDEX IF NOT EXISTS idx_listening_sessions_audiobook_date ON listening_sessions(audiobook_id, session_date DESC);
CREATE INDEX IF NOT EXISTS idx_purchases_created ON purchases(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_purchases_user ON purchases(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_role_created ON profiles(role, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_playlists_user ON playlists(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_playlist_items_position ON playlist_items(playlist_id, position);

-- Trigram extension for fuzzy search
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX IF NOT EXISTS idx_audiobooks_title_fa_trgm ON audiobooks USING gin(title_fa gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_audiobooks_title_en_trgm ON audiobooks USING gin(title_en gin_trgm_ops) WHERE title_en IS NOT NULL;


-- ==========================================================================
-- MIGRATION 17: ADMIN STATS MATERIALIZED VIEWS (20260112)
-- ==========================================================================

DROP MATERIALIZED VIEW IF EXISTS admin_content_stats_daily CASCADE;
CREATE MATERIALIZED VIEW admin_content_stats_daily AS
SELECT
  DATE(created_at) as date,
  COUNT(*) as total_audiobooks,
  COUNT(*) FILTER (WHERE status = 'approved') as approved_count,
  COUNT(*) FILTER (WHERE status = 'submitted') as submitted_count,
  COUNT(*) FILTER (WHERE status = 'draft') as draft_count,
  COUNT(*) FILTER (WHERE is_music = true) as music_count,
  COUNT(*) FILTER (WHERE is_music = false) as book_count,
  COUNT(*) FILTER (WHERE is_free = true) as free_count,
  SUM(play_count) as total_plays,
  COUNT(DISTINCT narrator_id) as active_narrators
FROM audiobooks GROUP BY DATE(created_at) ORDER BY date DESC;

CREATE UNIQUE INDEX idx_content_stats_daily_date ON admin_content_stats_daily(date);

DROP MATERIALIZED VIEW IF EXISTS admin_content_summary CASCADE;
CREATE MATERIALIZED VIEW admin_content_summary AS
SELECT
  COUNT(*) as total_audiobooks,
  COUNT(*) FILTER (WHERE status = 'approved') as approved_count,
  COUNT(*) FILTER (WHERE status = 'submitted') as pending_count,
  COUNT(*) FILTER (WHERE is_music = true) as music_count,
  COUNT(*) FILTER (WHERE is_music = false) as book_count,
  SUM(play_count) as total_plays,
  SUM(total_duration_seconds) as total_duration_seconds,
  COUNT(DISTINCT narrator_id) as total_narrators
FROM audiobooks;

DROP MATERIALIZED VIEW IF EXISTS admin_user_stats_daily CASCADE;
CREATE MATERIALIZED VIEW admin_user_stats_daily AS
SELECT
  DATE(created_at) as date,
  COUNT(*) as new_users,
  COUNT(*) FILTER (WHERE role = 'listener') as new_listeners,
  COUNT(*) FILTER (WHERE role = 'narrator') as new_narrators
FROM profiles GROUP BY DATE(created_at) ORDER BY date DESC;

CREATE UNIQUE INDEX idx_user_stats_daily_date ON admin_user_stats_daily(date);

DROP MATERIALIZED VIEW IF EXISTS admin_user_summary CASCADE;
CREATE MATERIALIZED VIEW admin_user_summary AS
SELECT
  COUNT(*) as total_users,
  COUNT(*) FILTER (WHERE role = 'listener') as listener_count,
  COUNT(*) FILTER (WHERE role = 'narrator') as narrator_count,
  COUNT(*) FILTER (WHERE role = 'admin') as admin_count,
  COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '7 days') as new_this_week,
  COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '30 days') as new_this_month
FROM profiles;

DROP MATERIALIZED VIEW IF EXISTS admin_revenue_stats_daily CASCADE;
CREATE MATERIALIZED VIEW admin_revenue_stats_daily AS
SELECT
  DATE(created_at) as date,
  COUNT(*) as purchase_count,
  COALESCE(SUM(amount), 0) as total_revenue,
  COUNT(DISTINCT user_id) as unique_buyers
FROM purchases GROUP BY DATE(created_at) ORDER BY date DESC;

CREATE UNIQUE INDEX idx_revenue_stats_daily_date ON admin_revenue_stats_daily(date);

DROP MATERIALIZED VIEW IF EXISTS admin_revenue_summary CASCADE;
CREATE MATERIALIZED VIEW admin_revenue_summary AS
SELECT
  COUNT(*) as total_purchases,
  COALESCE(SUM(amount), 0) as total_revenue,
  COUNT(DISTINCT user_id) as total_unique_buyers,
  COALESCE(SUM(amount) FILTER (WHERE created_at >= NOW() - INTERVAL '7 days'), 0) as revenue_this_week,
  COALESCE(SUM(amount) FILTER (WHERE created_at >= NOW() - INTERVAL '30 days'), 0) as revenue_this_month
FROM purchases;

DROP MATERIALIZED VIEW IF EXISTS admin_listening_stats_daily CASCADE;
CREATE MATERIALIZED VIEW admin_listening_stats_daily AS
SELECT
  session_date as date,
  COUNT(*) as session_count,
  COUNT(DISTINCT user_id) as unique_listeners,
  SUM(duration_seconds) as total_listening_seconds
FROM listening_sessions GROUP BY session_date ORDER BY session_date DESC;

CREATE UNIQUE INDEX idx_listening_stats_daily_date ON admin_listening_stats_daily(date);

CREATE OR REPLACE FUNCTION refresh_admin_stats()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY admin_content_stats_daily;
  REFRESH MATERIALIZED VIEW admin_content_summary;
  REFRESH MATERIALIZED VIEW CONCURRENTLY admin_user_stats_daily;
  REFRESH MATERIALIZED VIEW admin_user_summary;
  REFRESH MATERIALIZED VIEW CONCURRENTLY admin_revenue_stats_daily;
  REFRESH MATERIALIZED VIEW admin_revenue_summary;
  REFRESH MATERIALIZED VIEW CONCURRENTLY admin_listening_stats_daily;
END;
$$ LANGUAGE plpgsql;


-- ==========================================================================
-- MIGRATION 18: IS_PODCAST COLUMN (20260113) - You already ran this manually
-- ==========================================================================

ALTER TABLE audiobooks ADD COLUMN IF NOT EXISTS is_podcast BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_audiobooks_podcast_approved
ON audiobooks(created_at DESC) WHERE is_podcast = true AND status = 'approved';

CREATE INDEX IF NOT EXISTS idx_audiobooks_content_type_status
ON audiobooks(is_music, is_podcast, status, created_at DESC);


-- ==========================================================================
-- DONE!
-- ==========================================================================
-- All migrations combined. Run in Supabase SQL Editor.
-- Some may show notices/warnings if objects already exist - that's OK.
