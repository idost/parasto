-- Add author and translator columns to audiobooks table
-- Author Farsi is the only required field (enforced at application level)

ALTER TABLE audiobooks
ADD COLUMN IF NOT EXISTS author_fa TEXT,
ADD COLUMN IF NOT EXISTS author_en TEXT,
ADD COLUMN IF NOT EXISTS translator_fa TEXT,
ADD COLUMN IF NOT EXISTS translator_en TEXT;

-- Add comment for documentation
COMMENT ON COLUMN audiobooks.author_fa IS 'Author name in Farsi (required for new books)';
COMMENT ON COLUMN audiobooks.author_en IS 'Author name in English (optional)';
COMMENT ON COLUMN audiobooks.translator_fa IS 'Translator name in Farsi (optional, shown only when set)';
COMMENT ON COLUMN audiobooks.translator_en IS 'Translator name in English (optional)';
