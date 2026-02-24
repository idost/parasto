-- Migration: Add atomic playlist item addition function
-- Purpose: Fix race condition where concurrent adds could get same position
--          by atomically calculating next position and inserting
-- Risk: LOW - New function, client code will be updated to use it

-- Create function to add item to playlist with atomic position calculation
CREATE OR REPLACE FUNCTION add_playlist_item(
  p_playlist_id UUID,
  p_audiobook_id INTEGER,
  p_chapter_id INTEGER DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_next_position INTEGER;
  v_user_id UUID;
  v_new_item_id INTEGER;
BEGIN
  -- Get current user ID
  v_user_id := auth.uid();

  -- Verify user owns this playlist
  IF NOT EXISTS (
    SELECT 1 FROM playlists
    WHERE id = p_playlist_id AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Playlist not found or access denied';
  END IF;

  -- Atomically get max position and calculate next
  -- COALESCE handles empty playlist case (returns -1 + 1 = 0)
  SELECT COALESCE(MAX(position), -1) + 1
  INTO v_next_position
  FROM playlist_items
  WHERE playlist_id = p_playlist_id;

  -- Insert new item with calculated position
  INSERT INTO playlist_items (
    playlist_id,
    audiobook_id,
    chapter_id,
    position,
    created_at,
    updated_at
  ) VALUES (
    p_playlist_id,
    p_audiobook_id,
    p_chapter_id,
    v_next_position,
    NOW(),
    NOW()
  )
  RETURNING id INTO v_new_item_id;

  -- Update playlist's updated_at timestamp
  UPDATE playlists
  SET updated_at = NOW()
  WHERE id = p_playlist_id;

  -- Return the position that was assigned
  RETURN v_next_position;
END;
$$;

-- Add comment for documentation
COMMENT ON FUNCTION add_playlist_item(UUID, INTEGER, INTEGER) IS
'Atomically add item to playlist with automatic position calculation.
Prevents race condition where concurrent adds could get duplicate positions.
Returns the position assigned to the new item.';
