-- EBOOK HIGHLIGHTS, BOOKMARKS, AND READING PROGRESS TABLES
-- Migration for Myna E-book Reader (Parasto)
-- Supports Apple Books-style highlights with notes and cloud sync

-- ============================================================================
-- EBOOK HIGHLIGHTS TABLE
-- Stores text highlights with optional notes, colors, and position data
-- ============================================================================

CREATE TABLE IF NOT EXISTS ebook_highlights (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  book_id TEXT NOT NULL,
  chapter_index INT NOT NULL,
  start_offset INT NOT NULL,
  end_offset INT NOT NULL,
  highlighted_text TEXT NOT NULL,
  anchor_text TEXT NOT NULL, -- Context for re-locating after pagination changes
  color_hex TEXT NOT NULL DEFAULT 'FFF9E066', -- Default yellow
  note_text TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Constraint to ensure valid text range
  CONSTRAINT valid_highlight_offsets CHECK (end_offset > start_offset),
  -- Unique constraint to prevent duplicate highlights at same position
  CONSTRAINT unique_highlight_position UNIQUE(user_id, book_id, chapter_index, start_offset, end_offset)
);

-- Enable Row Level Security
ALTER TABLE ebook_highlights ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Users can only access their own highlights
CREATE POLICY "Users can view own highlights" ON ebook_highlights
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own highlights" ON ebook_highlights
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own highlights" ON ebook_highlights
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own highlights" ON ebook_highlights
  FOR DELETE USING (auth.uid() = user_id);

-- Indexes for efficient queries
CREATE INDEX idx_ebook_highlights_user_book ON ebook_highlights(user_id, book_id);
CREATE INDEX idx_ebook_highlights_chapter ON ebook_highlights(book_id, chapter_index);

-- ============================================================================
-- EBOOK BOOKMARKS TABLE
-- Stores page bookmarks (chapter + page position)
-- ============================================================================

CREATE TABLE IF NOT EXISTS ebook_bookmarks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  book_id TEXT NOT NULL,
  chapter_index INT NOT NULL,
  page_index INT NOT NULL,
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),

  -- Unique constraint: one bookmark per page per user
  CONSTRAINT unique_bookmark_position UNIQUE(user_id, book_id, chapter_index, page_index)
);

-- Enable Row Level Security
ALTER TABLE ebook_bookmarks ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own bookmarks" ON ebook_bookmarks
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own bookmarks" ON ebook_bookmarks
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own bookmarks" ON ebook_bookmarks
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own bookmarks" ON ebook_bookmarks
  FOR DELETE USING (auth.uid() = user_id);

-- Indexes
CREATE INDEX idx_ebook_bookmarks_user_book ON ebook_bookmarks(user_id, book_id);

-- ============================================================================
-- EBOOK READING PROGRESS TABLE
-- Tracks reading position and total reading time
-- ============================================================================

CREATE TABLE IF NOT EXISTS ebook_reading_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  book_id TEXT NOT NULL,
  chapter_index INT NOT NULL DEFAULT 0,
  page_index INT NOT NULL DEFAULT 0,
  progress_percent FLOAT NOT NULL DEFAULT 0,
  last_read_at TIMESTAMPTZ DEFAULT NOW(),
  total_reading_time_seconds INT NOT NULL DEFAULT 0,

  -- One progress record per book per user
  CONSTRAINT unique_progress_per_book UNIQUE(user_id, book_id)
);

-- Enable Row Level Security
ALTER TABLE ebook_reading_progress ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own progress" ON ebook_reading_progress
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own progress" ON ebook_reading_progress
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own progress" ON ebook_reading_progress
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own progress" ON ebook_reading_progress
  FOR DELETE USING (auth.uid() = user_id);

-- Indexes
CREATE INDEX idx_ebook_progress_user_book ON ebook_reading_progress(user_id, book_id);

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_ebook_highlight_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update timestamp on highlight changes
CREATE TRIGGER trigger_ebook_highlights_updated_at
  BEFORE UPDATE ON ebook_highlights
  FOR EACH ROW
  EXECUTE FUNCTION update_ebook_highlight_timestamp();

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE ebook_highlights IS 'Stores text highlights with notes for EPUB reader';
COMMENT ON COLUMN ebook_highlights.anchor_text IS 'Context text around highlight for re-locating after pagination changes';
COMMENT ON COLUMN ebook_highlights.color_hex IS 'Highlight color in ARGB hex format (e.g., FFF9E066 for yellow)';

COMMENT ON TABLE ebook_bookmarks IS 'Stores page bookmarks for EPUB reader';
COMMENT ON TABLE ebook_reading_progress IS 'Tracks reading position and time for EPUB books';
