-- Migration: Make book_metadata.author_name required (NOT NULL)
-- Purpose: Enforce data integrity - all books must have an author
-- Risk: MEDIUM - Requires backfill before constraint applied
--        Migration queries for NULL rows first to ensure safe backfill

-- Step 1: Backfill NULL values with placeholder text
-- This ensures existing rows won't violate the NOT NULL constraint
UPDATE book_metadata
SET author_name = 'نامشخص'  -- "Unknown" in Farsi
WHERE author_name IS NULL OR author_name = '';

-- Step 2: Also handle empty string as NULL (set to placeholder)
UPDATE book_metadata
SET author_name = 'نامشخص'
WHERE TRIM(author_name) = '';

-- Step 3: Add NOT NULL constraint
-- This will fail if any NULL rows remain (safety check)
ALTER TABLE book_metadata
ALTER COLUMN author_name SET NOT NULL;

-- Step 4: Add check constraint to prevent empty strings in future
ALTER TABLE book_metadata
ADD CONSTRAINT book_metadata_author_name_not_empty
CHECK (author_name IS NOT NULL AND TRIM(author_name) != '');

-- Add comment for documentation
COMMENT ON CONSTRAINT book_metadata_author_name_not_empty ON book_metadata IS
'Ensures author_name is always present and not empty.
Books without known author should use placeholder text like "نامشخص" (Unknown).';

COMMENT ON COLUMN book_metadata.author_name IS
'Main author name in Farsi (نویسنده) - REQUIRED field.
Use "نامشخص" for unknown authors.';
