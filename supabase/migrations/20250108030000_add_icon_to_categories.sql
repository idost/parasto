-- Migration: Add icon column to categories table
-- Created: 2025-01-08
-- Purpose: Add icon field to book categories table for consistency with music_categories

-- Add icon column to categories table (if it doesn't exist)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'categories'
        AND column_name = 'icon'
    ) THEN
        ALTER TABLE public.categories ADD COLUMN icon TEXT;

        -- Add comment explaining the purpose
        COMMENT ON COLUMN public.categories.icon IS 'Emoji or icon code to display with the category (e.g., 📚, 🎭, 🔬)';
    END IF;
END $$;
