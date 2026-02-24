-- Migration: Add atomic playlist reorder function
-- Purpose: Fix transaction safety issue where reordering playlist items in a loop
--          could leave playlist in inconsistent state if operation fails midway
-- Risk: LOW - New function, doesn't change existing behavior until client code updated

-- Create function to reorder playlist items atomically within a single transaction
CREATE OR REPLACE FUNCTION reorder_playlist_items(
  p_playlist_id UUID,
  p_item_ids INTEGER[]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
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

  -- Update positions atomically
  -- Loop through the array and update each item's position
  FOR i IN 1..array_length(p_item_ids, 1) LOOP
    UPDATE playlist_items
    SET
      position = i - 1,  -- 0-indexed positions
      updated_at = NOW()
    WHERE
      id = p_item_ids[i]
      AND playlist_id = p_playlist_id;
  END LOOP;

  -- Update playlist's updated_at timestamp
  UPDATE playlists
  SET updated_at = NOW()
  WHERE id = p_playlist_id;
END;
$$;

-- Add comment for documentation
COMMENT ON FUNCTION reorder_playlist_items(UUID, INTEGER[]) IS
'Atomically reorder playlist items by providing an array of item IDs in desired order.
Ensures all position updates happen in a single transaction to prevent inconsistent state.';
