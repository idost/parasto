-- Migration: Create book_summaries table for AI-generated summaries
-- This table caches AI-generated book summaries to reduce API costs and improve latency

-- Create the book_summaries table
CREATE TABLE IF NOT EXISTS public.book_summaries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    audiobook_id INTEGER NOT NULL UNIQUE REFERENCES public.audiobooks(id) ON DELETE CASCADE,
    summary_fa TEXT NOT NULL,
    model TEXT,  -- Which AI model generated this (e.g., 'claude-3-haiku', 'gpt-4o-mini')
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create index on audiobook_id for fast lookups
CREATE INDEX IF NOT EXISTS idx_book_summaries_audiobook_id ON public.book_summaries(audiobook_id);

-- Add comment explaining the table
COMMENT ON TABLE public.book_summaries IS 'Cached AI-generated book summaries. Accessed via Edge Functions using service_role key.';

-- Create trigger to auto-update updated_at
CREATE OR REPLACE FUNCTION update_book_summaries_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS book_summaries_updated_at ON public.book_summaries;
CREATE TRIGGER book_summaries_updated_at
    BEFORE UPDATE ON public.book_summaries
    FOR EACH ROW EXECUTE FUNCTION update_book_summaries_updated_at();

-- RLS Policy: No RLS for now since we access via service_role key in Edge Functions
-- If needed later, enable RLS with: ALTER TABLE public.book_summaries ENABLE ROW LEVEL SECURITY;
