-- =====================================================
-- ALLOW OWNERS TO VIEW THEIR PURCHASED AUDIOBOOKS
-- =====================================================
-- This migration adds an RLS policy that allows users to view
-- audiobooks they own via entitlements, regardless of the
-- audiobook's status. This fixes an issue where users couldn't
-- see their purchased/owned books in the library if the book's
-- status was changed (e.g., from 'approved' to 'pending').
-- =====================================================

-- Create policy for owners to view their purchased audiobooks
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'audiobooks'
          AND policyname = 'Owners can view their audiobooks'
    ) THEN
        CREATE POLICY "Owners can view their audiobooks" ON public.audiobooks
            FOR SELECT USING (
                EXISTS (
                    SELECT 1 FROM public.entitlements
                    WHERE entitlements.audiobook_id = audiobooks.id
                    AND entitlements.user_id = auth.uid()
                )
            );
    END IF;
END $$;

-- Also allow owners to view chapters of their purchased audiobooks
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'chapters'
          AND policyname = 'Owners can view chapters of their audiobooks'
    ) THEN
        CREATE POLICY "Owners can view chapters of their audiobooks" ON public.chapters
            FOR SELECT USING (
                EXISTS (
                    SELECT 1 FROM public.entitlements
                    WHERE entitlements.audiobook_id = chapters.audiobook_id
                    AND entitlements.user_id = auth.uid()
                )
            );
    END IF;
END $$;

-- =====================================================
-- SUMMARY
-- =====================================================
-- After this migration, users can view audiobooks and chapters if:
-- 1. The audiobook status is 'approved' (existing policy), OR
-- 2. They have an entitlement for that audiobook (new policy)
--
-- This ensures users always see books they've purchased/claimed
-- in their library, even if the book's status changes later.
-- =====================================================
