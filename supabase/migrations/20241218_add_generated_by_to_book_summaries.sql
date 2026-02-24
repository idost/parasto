-- Migration: Add generated_by column to book_summaries for rate limiting
-- This tracks which user generated each summary for rate limiting purposes

-- Add generated_by column (nullable for existing rows)
ALTER TABLE public.book_summaries
ADD COLUMN IF NOT EXISTS generated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- Create index for rate limit queries (user + time range)
CREATE INDEX IF NOT EXISTS idx_book_summaries_generated_by_created_at
ON public.book_summaries(generated_by, created_at)
WHERE generated_by IS NOT NULL;

-- Add comment
COMMENT ON COLUMN public.book_summaries.generated_by IS 'User who triggered the AI generation. Used for rate limiting.';
