-- =====================================================
-- FIX CIRCULAR RLS FOR AUDIOBOOKS AND CHAPTERS SELECT
-- =====================================================
-- ROOT CAUSE: When querying audiobooks, the RLS policy queries entitlements.
-- When querying entitlements for INSERT, the policy (before fix) queried audiobooks.
-- This created circular dependencies.
--
-- The INSERT policy was already fixed (20241227), but there might still be
-- issues with SELECT on audiobooks triggering entitlements RLS which then
-- tries to evaluate in a complex nested context.
--
-- SOLUTION: Create SECURITY DEFINER helper functions to check ownership
-- without triggering RLS chains.
-- =====================================================

-- =====================================================
-- HELPER FUNCTION: user_owns_audiobook
-- =====================================================
-- Checks if a user has an entitlement for an audiobook.
-- Uses SECURITY DEFINER to bypass RLS and prevent circular evaluation.
-- Using BIGINT to match the audiobooks.id column type.
CREATE OR REPLACE FUNCTION public.user_owns_audiobook(ab_id BIGINT, uid UUID)
RETURNS BOOLEAN AS $$
DECLARE
    result BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM public.entitlements
        WHERE audiobook_id = ab_id
        AND user_id = uid
    ) INTO result;

    RETURN COALESCE(result, false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.user_owns_audiobook(BIGINT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_owns_audiobook(BIGINT, UUID) TO anon;

-- =====================================================
-- HELPER FUNCTION: user_is_admin
-- =====================================================
-- Checks if a user is an admin.
-- Drop first in case it exists with different parameter names
DROP FUNCTION IF EXISTS public.user_is_admin(UUID);

CREATE FUNCTION public.user_is_admin(uid UUID)
RETURNS BOOLEAN AS $$
DECLARE
    result BOOLEAN;
BEGIN
    SELECT (role = 'admin') INTO result
    FROM public.profiles
    WHERE id = uid;

    RETURN COALESCE(result, false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.user_is_admin(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_is_admin(UUID) TO anon;

-- =====================================================
-- DROP AND RECREATE AUDIOBOOKS SELECT POLICY
-- =====================================================
DROP POLICY IF EXISTS "Audiobooks read access" ON public.audiobooks;

CREATE POLICY "Audiobooks read access" ON public.audiobooks
    FOR SELECT USING (
        -- Condition 1: Anyone can see approved audiobooks
        status = 'approved'

        -- Condition 2: Owners can see audiobooks they have entitlements for
        OR (
            auth.uid() IS NOT NULL
            AND public.user_owns_audiobook(id, auth.uid())
        )

        -- Condition 3: Narrators can see their own audiobooks (any status)
        OR narrator_id = auth.uid()

        -- Condition 4: Admins can see all audiobooks
        OR (
            auth.uid() IS NOT NULL
            AND public.user_is_admin(auth.uid())
        )
    );

-- =====================================================
-- DROP AND RECREATE CHAPTERS SELECT POLICY
-- =====================================================
DROP POLICY IF EXISTS "Chapters read access" ON public.chapters;

CREATE POLICY "Chapters read access" ON public.chapters
    FOR SELECT USING (
        -- Condition 1: Anyone can see chapters of approved audiobooks
        EXISTS (
            SELECT 1 FROM public.audiobooks
            WHERE audiobooks.id = chapters.audiobook_id
            AND audiobooks.status = 'approved'
        )

        -- Condition 2: Owners can see chapters of audiobooks they own
        OR (
            auth.uid() IS NOT NULL
            AND public.user_owns_audiobook(audiobook_id, auth.uid())
        )

        -- Condition 3: Narrators can see chapters of their own audiobooks
        OR EXISTS (
            SELECT 1 FROM public.audiobooks
            WHERE audiobooks.id = chapters.audiobook_id
            AND audiobooks.narrator_id = auth.uid()
        )

        -- Condition 4: Admins can see all chapters
        OR (
            auth.uid() IS NOT NULL
            AND public.user_is_admin(auth.uid())
        )
    );

-- =====================================================
-- NOTES
-- =====================================================
-- The SECURITY DEFINER functions bypass RLS when checking ownership/admin.
-- This prevents circular evaluation chains.
--
-- Security is maintained because:
-- 1. user_owns_audiobook only returns a boolean (no data leak)
-- 2. user_is_admin only returns a boolean
-- 3. The policies still correctly enforce access control
-- =====================================================
