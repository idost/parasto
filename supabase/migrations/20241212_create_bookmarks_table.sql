-- Create bookmarks table for audiobook position markers
CREATE TABLE IF NOT EXISTS bookmarks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    audiobook_id INTEGER NOT NULL REFERENCES audiobooks(id) ON DELETE CASCADE,
    chapter_id INTEGER NOT NULL REFERENCES chapters(id) ON DELETE CASCADE,
    position_seconds INTEGER NOT NULL DEFAULT 0,
    note TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Ensure user can't have duplicate bookmarks at exact same position
    UNIQUE(user_id, audiobook_id, chapter_id, position_seconds)
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_bookmarks_user_id ON bookmarks(user_id);
CREATE INDEX IF NOT EXISTS idx_bookmarks_audiobook_id ON bookmarks(audiobook_id);
CREATE INDEX IF NOT EXISTS idx_bookmarks_chapter_id ON bookmarks(chapter_id);
CREATE INDEX IF NOT EXISTS idx_bookmarks_user_audiobook ON bookmarks(user_id, audiobook_id);

-- Enable Row Level Security (idempotent - safe to run multiple times)
ALTER TABLE bookmarks ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own bookmarks (idempotent)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'bookmarks'
          AND policyname = 'Users can view their own bookmarks'
    ) THEN
        CREATE POLICY "Users can view their own bookmarks"
            ON bookmarks FOR SELECT
            USING (auth.uid() = user_id);
    END IF;
END $$;

-- Policy: Users can create their own bookmarks (idempotent)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'bookmarks'
          AND policyname = 'Users can create their own bookmarks'
    ) THEN
        CREATE POLICY "Users can create their own bookmarks"
            ON bookmarks FOR INSERT
            WITH CHECK (auth.uid() = user_id);
    END IF;
END $$;

-- Policy: Users can update their own bookmarks (idempotent)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'bookmarks'
          AND policyname = 'Users can update their own bookmarks'
    ) THEN
        CREATE POLICY "Users can update their own bookmarks"
            ON bookmarks FOR UPDATE
            USING (auth.uid() = user_id);
    END IF;
END $$;

-- Policy: Users can delete their own bookmarks (idempotent)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'bookmarks'
          AND policyname = 'Users can delete their own bookmarks'
    ) THEN
        CREATE POLICY "Users can delete their own bookmarks"
            ON bookmarks FOR DELETE
            USING (auth.uid() = user_id);
    END IF;
END $$;
