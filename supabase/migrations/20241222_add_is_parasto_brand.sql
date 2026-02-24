-- Migration: Add is_parasto_brand column to audiobooks table
-- Purpose: Allow admin to mark audiobooks as "Parasto brand" for display purposes
-- When is_parasto_brand = true, the UI shows "پرستو" instead of the real narrator name

-- Add the column with a safe default
ALTER TABLE public.audiobooks
ADD COLUMN IF NOT EXISTS is_parasto_brand boolean NOT NULL DEFAULT false;

-- Add a comment for documentation
COMMENT ON COLUMN public.audiobooks.is_parasto_brand IS
'When true, the audiobook is displayed as published by "پرستو" (Parasto) instead of showing the actual narrator name. This is for display purposes only; narrator_id still tracks the real owner for permissions.';

-- Create an index for efficient filtering (optional, but useful if you want to query by brand)
CREATE INDEX IF NOT EXISTS idx_audiobooks_is_parasto_brand ON public.audiobooks(is_parasto_brand);
