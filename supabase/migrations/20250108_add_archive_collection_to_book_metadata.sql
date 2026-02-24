-- Migration: 20250108_add_archive_collection_to_book_metadata.sql
-- Purpose: Add archive_source (آرشیف) and collection_source (بایگانی) columns to book_metadata
-- Date: 2025-01-08
--
-- This migration adds two new optional text columns to book_metadata:
-- 1. archive_source - آرشیف (archive source name)
-- 2. collection_source - بایگانی (collection/series name)
--
-- These fields allow narrators and admins to specify the archive and collection
-- information for audiobooks, similar to how music_metadata tracks these for music.

-- Add archive_source column
ALTER TABLE public.book_metadata
ADD COLUMN IF NOT EXISTS archive_source TEXT;

-- Add collection_source column
ALTER TABLE public.book_metadata
ADD COLUMN IF NOT EXISTS collection_source TEXT;

-- Add documentation comments
COMMENT ON COLUMN public.book_metadata.archive_source IS 'Archive source name in Farsi (آرشیف) - where the audiobook was sourced from';
COMMENT ON COLUMN public.book_metadata.collection_source IS 'Collection/series name in Farsi (بایگانی) - the collection this audiobook belongs to';
