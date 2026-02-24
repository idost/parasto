-- Migration: Add music categories (سبک‌های موسیقی) support
-- Purpose: Allow admin to create and manage music genres/styles
-- Date: 2024-12-24
--
-- This migration creates:
-- 1. music_categories table - stores music genres (e.g., پاپ، سنتی، کلاسیک)
-- 2. audiobook_music_categories junction table - many-to-many relationship
-- 3. Proper RLS policies for both tables
--

-- ==============================================
-- 1. Create music_categories table
-- ==============================================
CREATE TABLE IF NOT EXISTS public.music_categories (
    id serial PRIMARY KEY,
    name_fa text NOT NULL,                    -- Persian name (e.g., پاپ)
    name_en text,                             -- English name (optional)
    icon text,                                -- Emoji or icon code (e.g., 🎵)
    description_fa text,                      -- Persian description (optional)
    is_active boolean NOT NULL DEFAULT true,  -- Whether category is shown in UI
    sort_order integer NOT NULL DEFAULT 0,    -- Display order
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Add comments for documentation
COMMENT ON TABLE public.music_categories IS 'Music genres/styles (سبک‌های موسیقی) for categorizing music content';
COMMENT ON COLUMN public.music_categories.name_fa IS 'Persian name of the music category';
COMMENT ON COLUMN public.music_categories.icon IS 'Emoji or icon to display with the category';

-- Create index for sorting
CREATE INDEX IF NOT EXISTS idx_music_categories_sort_order ON public.music_categories(sort_order);
CREATE INDEX IF NOT EXISTS idx_music_categories_is_active ON public.music_categories(is_active);

-- ==============================================
-- 2. Create junction table for many-to-many
-- ==============================================
CREATE TABLE IF NOT EXISTS public.audiobook_music_categories (
    audiobook_id integer NOT NULL REFERENCES public.audiobooks(id) ON DELETE CASCADE,
    music_category_id integer NOT NULL REFERENCES public.music_categories(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (audiobook_id, music_category_id)
);

COMMENT ON TABLE public.audiobook_music_categories IS 'Junction table linking audiobooks (music) to music categories (many-to-many)';

-- Create indexes for efficient lookups
CREATE INDEX IF NOT EXISTS idx_audiobook_music_categories_audiobook ON public.audiobook_music_categories(audiobook_id);
CREATE INDEX IF NOT EXISTS idx_audiobook_music_categories_category ON public.audiobook_music_categories(music_category_id);

-- ==============================================
-- 3. Enable RLS and create policies
-- ==============================================

-- Enable RLS on music_categories
ALTER TABLE public.music_categories ENABLE ROW LEVEL SECURITY;

-- Everyone can read active music categories
CREATE POLICY "Anyone can view active music categories"
ON public.music_categories
FOR SELECT
USING (is_active = true);

-- Admins can manage all music categories
CREATE POLICY "Admins can manage music categories"
ON public.music_categories
FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid()
        AND role = 'admin'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid()
        AND role = 'admin'
    )
);

-- Enable RLS on junction table
ALTER TABLE public.audiobook_music_categories ENABLE ROW LEVEL SECURITY;

-- Everyone can read category assignments for visible audiobooks
CREATE POLICY "Anyone can view music category assignments"
ON public.audiobook_music_categories
FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.audiobooks
        WHERE audiobooks.id = audiobook_music_categories.audiobook_id
        AND audiobooks.status = 'approved'
    )
);

-- Admins can manage all category assignments
CREATE POLICY "Admins can manage music category assignments"
ON public.audiobook_music_categories
FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid()
        AND role = 'admin'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid()
        AND role = 'admin'
    )
);

-- Narrators can manage category assignments for their own audiobooks
CREATE POLICY "Narrators can manage their music category assignments"
ON public.audiobook_music_categories
FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM public.audiobooks
        WHERE audiobooks.id = audiobook_music_categories.audiobook_id
        AND audiobooks.narrator_id = auth.uid()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.audiobooks
        WHERE audiobooks.id = audiobook_music_categories.audiobook_id
        AND audiobooks.narrator_id = auth.uid()
    )
);

-- ==============================================
-- 4. Insert default music categories
-- ==============================================
INSERT INTO public.music_categories (name_fa, name_en, icon, sort_order) VALUES
    ('پاپ', 'Pop', '🎤', 1),
    ('سنتی', 'Traditional', '🪕', 2),
    ('کلاسیک', 'Classical', '🎻', 3),
    ('راک', 'Rock', '🎸', 4),
    ('جاز', 'Jazz', '🎷', 5),
    ('الکترونیک', 'Electronic', '🎹', 6),
    ('آرامش‌بخش', 'Relaxing', '🧘', 7),
    ('کودکانه', 'Children', '🧸', 8),
    ('مذهبی', 'Religious', '🕌', 9),
    ('بی‌کلام', 'Instrumental', '🎼', 10)
ON CONFLICT DO NOTHING;

-- ==============================================
-- 5. Update trigger for updated_at
-- ==============================================
CREATE OR REPLACE FUNCTION update_music_categories_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS music_categories_updated_at ON public.music_categories;
CREATE TRIGGER music_categories_updated_at
    BEFORE UPDATE ON public.music_categories
    FOR EACH ROW
    EXECUTE FUNCTION update_music_categories_updated_at();
