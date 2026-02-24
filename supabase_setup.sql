-- =====================================================
-- MYNA AUDIOBOOK APP - SUPABASE DATABASE SETUP
-- =====================================================
-- Run these scripts in the Supabase SQL Editor
-- Go to: Supabase Dashboard > SQL Editor > New Query
-- This script is SAFE to run multiple times (idempotent)
-- =====================================================

-- =====================================================
-- 1. PROFILES TABLE (User accounts)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    full_name TEXT,
    display_name TEXT,
    bio TEXT,
    avatar_url TEXT,
    role TEXT DEFAULT 'listener' CHECK (role IN ('listener', 'narrator', 'admin')),
    is_disabled BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies first, then create
DROP POLICY IF EXISTS "Users can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;

CREATE POLICY "Users can view all profiles" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Auto-create profile on signup (trigger)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name, role)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
        'listener'
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =====================================================
-- 2. CATEGORIES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.categories (
    id SERIAL PRIMARY KEY,
    name_fa TEXT NOT NULL,
    name_en TEXT,
    description_fa TEXT,
    icon TEXT,
    cover_url TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view active categories" ON public.categories;
DROP POLICY IF EXISTS "Admins can manage categories" ON public.categories;

CREATE POLICY "Anyone can view active categories" ON public.categories FOR SELECT USING (is_active = true);
CREATE POLICY "Admins can manage categories" ON public.categories FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- =====================================================
-- 3. AUDIOBOOKS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.audiobooks (
    id SERIAL PRIMARY KEY,
    title_fa TEXT NOT NULL,
    title_en TEXT,
    subtitle_fa TEXT,
    description_fa TEXT,
    narrator_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    category_id INTEGER REFERENCES public.categories(id) ON DELETE SET NULL,
    cover_storage_path TEXT,
    cover_url TEXT,
    price_toman INTEGER DEFAULT 0,
    is_free BOOLEAN DEFAULT FALSE,
    is_featured BOOLEAN DEFAULT FALSE,
    status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'submitted', 'under_review', 'approved', 'rejected')),
    rejection_reason TEXT,
    total_duration_seconds INTEGER DEFAULT 0,
    chapter_count INTEGER DEFAULT 0,
    play_count INTEGER DEFAULT 0,
    purchase_count INTEGER DEFAULT 0,
    avg_rating NUMERIC(3,2) DEFAULT 0,
    review_count INTEGER DEFAULT 0,
    published_at TIMESTAMPTZ,
    reviewed_at TIMESTAMPTZ,
    reviewed_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.audiobooks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view approved audiobooks" ON public.audiobooks;
DROP POLICY IF EXISTS "Narrators can manage own audiobooks" ON public.audiobooks;
DROP POLICY IF EXISTS "Admins can manage all audiobooks" ON public.audiobooks;

-- Everyone can view approved audiobooks
CREATE POLICY "Anyone can view approved audiobooks" ON public.audiobooks
    FOR SELECT USING (status = 'approved');

-- Narrators can view and manage their own audiobooks
CREATE POLICY "Narrators can manage own audiobooks" ON public.audiobooks
    FOR ALL USING (narrator_id = auth.uid());

-- Admins can view and manage all audiobooks
CREATE POLICY "Admins can manage all audiobooks" ON public.audiobooks
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- =====================================================
-- 4. CHAPTERS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.chapters (
    id SERIAL PRIMARY KEY,
    audiobook_id INTEGER REFERENCES public.audiobooks(id) ON DELETE CASCADE,
    title_fa TEXT NOT NULL,
    title_en TEXT,
    chapter_index INTEGER DEFAULT 0,
    audio_storage_path TEXT,
    audio_url TEXT,
    duration_seconds INTEGER DEFAULT 0,
    file_size_bytes BIGINT DEFAULT 0,
    is_preview BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.chapters ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view chapters of approved audiobooks" ON public.chapters;
DROP POLICY IF EXISTS "Narrators can manage own chapters" ON public.chapters;
DROP POLICY IF EXISTS "Admins can manage all chapters" ON public.chapters;

-- View chapters of approved audiobooks
CREATE POLICY "Anyone can view chapters of approved audiobooks" ON public.chapters
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM public.audiobooks WHERE id = audiobook_id AND status = 'approved')
    );

-- Narrators can manage chapters of their own audiobooks
CREATE POLICY "Narrators can manage own chapters" ON public.chapters
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.audiobooks WHERE id = audiobook_id AND narrator_id = auth.uid())
    );

-- Admins can manage all chapters
CREATE POLICY "Admins can manage all chapters" ON public.chapters
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- =====================================================
-- 5. ENTITLEMENTS TABLE (Purchases/Ownership)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.entitlements (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    audiobook_id INTEGER REFERENCES public.audiobooks(id) ON DELETE CASCADE,
    source TEXT DEFAULT 'purchase' CHECK (source IN ('purchase', 'free', 'gift', 'promo')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, audiobook_id)
);

ALTER TABLE public.entitlements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own entitlements" ON public.entitlements;
DROP POLICY IF EXISTS "Users can insert own entitlements" ON public.entitlements;
DROP POLICY IF EXISTS "Admins can view all entitlements" ON public.entitlements;

CREATE POLICY "Users can view own entitlements" ON public.entitlements
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can insert own entitlements" ON public.entitlements
    FOR INSERT WITH CHECK (user_id = auth.uid());

-- Admins can view all entitlements
CREATE POLICY "Admins can view all entitlements" ON public.entitlements
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- =====================================================
-- 6. PURCHASES TABLE (Payment records)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.purchases (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    audiobook_id INTEGER REFERENCES public.audiobooks(id) ON DELETE SET NULL,
    amount INTEGER DEFAULT 0,  -- Amount in Toman
    price_toman INTEGER DEFAULT 0,  -- Alternative column name
    payment_method TEXT,
    payment_reference TEXT,
    status TEXT DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.purchases ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own purchases" ON public.purchases;
DROP POLICY IF EXISTS "Admins can view all purchases" ON public.purchases;

CREATE POLICY "Users can view own purchases" ON public.purchases
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Admins can view all purchases" ON public.purchases
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- =====================================================
-- 7. LISTENING_PROGRESS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.listening_progress (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    audiobook_id INTEGER REFERENCES public.audiobooks(id) ON DELETE CASCADE,
    chapter_id INTEGER REFERENCES public.chapters(id) ON DELETE SET NULL,
    current_chapter_id INTEGER REFERENCES public.chapters(id) ON DELETE SET NULL,
    current_chapter_index INTEGER DEFAULT 0,
    position_seconds INTEGER DEFAULT 0,
    playback_speed NUMERIC(3,2) DEFAULT 1.0,
    is_completed BOOLEAN DEFAULT FALSE,
    completion_percentage INTEGER DEFAULT 0,
    total_listen_time_seconds INTEGER DEFAULT 0,
    last_played_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, audiobook_id)
);

ALTER TABLE public.listening_progress ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own progress" ON public.listening_progress;

CREATE POLICY "Users can manage own progress" ON public.listening_progress
    FOR ALL USING (user_id = auth.uid());

-- =====================================================
-- 7b. LISTENING_SESSIONS TABLE (Daily Tracking)
-- =====================================================
-- Tracks daily listening activity per audiobook for accurate stats
-- One record per user-audiobook-day combination
-- Used for accurate "days listening" count and streak calculations
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

-- Indexes for fast querying
CREATE INDEX IF NOT EXISTS idx_listening_sessions_user_date
ON public.listening_sessions(user_id, session_date DESC);

-- =====================================================
-- 8. USER_WISHLIST TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.user_wishlist (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    audiobook_id INTEGER REFERENCES public.audiobooks(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, audiobook_id)
);

ALTER TABLE public.user_wishlist ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own wishlist" ON public.user_wishlist;

CREATE POLICY "Users can manage own wishlist" ON public.user_wishlist
    FOR ALL USING (user_id = auth.uid());

-- =====================================================
-- 9. REVIEWS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.reviews (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    audiobook_id INTEGER REFERENCES public.audiobooks(id) ON DELETE CASCADE,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    is_approved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, audiobook_id)
);

ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view approved reviews" ON public.reviews;
DROP POLICY IF EXISTS "Users can manage own reviews" ON public.reviews;
DROP POLICY IF EXISTS "Admins can manage all reviews" ON public.reviews;

CREATE POLICY "Anyone can view approved reviews" ON public.reviews
    FOR SELECT USING (is_approved = true);

CREATE POLICY "Users can manage own reviews" ON public.reviews
    FOR ALL USING (user_id = auth.uid());

CREATE POLICY "Admins can manage all reviews" ON public.reviews
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- =====================================================
-- 10. ADMIN_FEEDBACK TABLE (Admin to Narrator feedback)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.admin_feedback (
    id SERIAL PRIMARY KEY,
    audiobook_id INTEGER REFERENCES public.audiobooks(id) ON DELETE CASCADE,
    chapter_id INTEGER REFERENCES public.chapters(id) ON DELETE SET NULL,
    admin_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    narrator_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    feedback_type TEXT DEFAULT 'info' CHECK (feedback_type IN ('info', 'change_required', 'rejection_reason')),
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.admin_feedback ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage feedback" ON public.admin_feedback;
DROP POLICY IF EXISTS "Narrators can view own feedback" ON public.admin_feedback;
DROP POLICY IF EXISTS "Narrators can update read status" ON public.admin_feedback;

-- Admins can create and view all feedback
CREATE POLICY "Admins can manage feedback" ON public.admin_feedback
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- Narrators can view feedback sent to them
CREATE POLICY "Narrators can view own feedback" ON public.admin_feedback
    FOR SELECT USING (narrator_id = auth.uid());

-- Narrators can mark feedback as read
CREATE POLICY "Narrators can update read status" ON public.admin_feedback
    FOR UPDATE USING (narrator_id = auth.uid());

-- =====================================================
-- 11. APP_SETTINGS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.app_settings (
    key TEXT PRIMARY KEY,
    value JSONB,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view settings" ON public.app_settings;
DROP POLICY IF EXISTS "Admins can manage settings" ON public.app_settings;

CREATE POLICY "Anyone can view settings" ON public.app_settings FOR SELECT USING (true);
CREATE POLICY "Admins can manage settings" ON public.app_settings FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- =====================================================
-- 12. STORAGE BUCKETS
-- =====================================================
-- Create storage buckets (if not exists)
INSERT INTO storage.buckets (id, name, public)
VALUES ('audiobook-covers', 'audiobook-covers', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('audiobook-audio', 'audiobook-audio', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Drop existing storage policies first
DROP POLICY IF EXISTS "Anyone can view covers" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload covers" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own covers" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own covers" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view audio" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload audio" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own audio" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own audio" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view avatars" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload avatars" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own avatar" ON storage.objects;

-- Storage policies for audiobook-covers
CREATE POLICY "Anyone can view covers" ON storage.objects
    FOR SELECT USING (bucket_id = 'audiobook-covers');

CREATE POLICY "Authenticated users can upload covers" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'audiobook-covers' AND auth.role() = 'authenticated');

CREATE POLICY "Users can update own covers" ON storage.objects
    FOR UPDATE USING (bucket_id = 'audiobook-covers' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can delete own covers" ON storage.objects
    FOR DELETE USING (bucket_id = 'audiobook-covers' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Storage policies for audiobook-audio
CREATE POLICY "Anyone can view audio" ON storage.objects
    FOR SELECT USING (bucket_id = 'audiobook-audio');

CREATE POLICY "Authenticated users can upload audio" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'audiobook-audio' AND auth.role() = 'authenticated');

CREATE POLICY "Users can update own audio" ON storage.objects
    FOR UPDATE USING (bucket_id = 'audiobook-audio' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can delete own audio" ON storage.objects
    FOR DELETE USING (bucket_id = 'audiobook-audio' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Storage policies for avatars
CREATE POLICY "Anyone can view avatars" ON storage.objects
    FOR SELECT USING (bucket_id = 'avatars');

CREATE POLICY "Authenticated users can upload avatars" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'avatars' AND auth.role() = 'authenticated');

CREATE POLICY "Users can update own avatar" ON storage.objects
    FOR UPDATE USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- =====================================================
-- 13. HELPER FUNCTIONS
-- =====================================================

-- Function to update audiobook stats after review
CREATE OR REPLACE FUNCTION update_audiobook_rating()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.audiobooks
    SET
        avg_rating = (SELECT COALESCE(AVG(rating), 0) FROM public.reviews WHERE audiobook_id = NEW.audiobook_id AND is_approved = true),
        review_count = (SELECT COUNT(*) FROM public.reviews WHERE audiobook_id = NEW.audiobook_id AND is_approved = true)
    WHERE id = NEW.audiobook_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_review_change ON public.reviews;
CREATE TRIGGER on_review_change
    AFTER INSERT OR UPDATE OR DELETE ON public.reviews
    FOR EACH ROW EXECUTE FUNCTION update_audiobook_rating();

-- Function to update chapter count
CREATE OR REPLACE FUNCTION update_chapter_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        UPDATE public.audiobooks
        SET chapter_count = (SELECT COUNT(*) FROM public.chapters WHERE audiobook_id = OLD.audiobook_id)
        WHERE id = OLD.audiobook_id;
        RETURN OLD;
    ELSE
        UPDATE public.audiobooks
        SET chapter_count = (SELECT COUNT(*) FROM public.chapters WHERE audiobook_id = NEW.audiobook_id)
        WHERE id = NEW.audiobook_id;
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_chapter_change ON public.chapters;
CREATE TRIGGER on_chapter_change
    AFTER INSERT OR DELETE ON public.chapters
    FOR EACH ROW EXECUTE FUNCTION update_chapter_count();

-- =====================================================
-- 14. SAMPLE DATA (Optional - for testing)
-- =====================================================
-- Uncomment below to add sample categories

-- INSERT INTO public.categories (name_fa, name_en, sort_order, is_active) VALUES
-- ('داستان و رمان', 'Fiction & Novels', 1, true),
-- ('روانشناسی', 'Psychology', 2, true),
-- ('تاریخ', 'History', 3, true),
-- ('علمی', 'Science', 4, true),
-- ('کودک و نوجوان', 'Children & Young Adult', 5, true),
-- ('مذهبی', 'Religious', 6, true),
-- ('شعر', 'Poetry', 7, true),
-- ('موفقیت و انگیزشی', 'Self-Help & Motivation', 8, true);

-- =====================================================
-- DONE! Your database is now ready.
-- =====================================================
