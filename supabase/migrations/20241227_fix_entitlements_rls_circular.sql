-- =====================================================
-- FIX CIRCULAR RLS DEPENDENCY FOR FREE BOOK CLAIMS
-- =====================================================
-- ROOT CAUSE: When inserting into entitlements, the RLS policy queries
-- audiobooks, which in turn has an RLS policy that queries entitlements.
-- This creates a circular dependency that PostgreSQL cannot resolve.
--
-- SOLUTION: Use a SECURITY DEFINER function to check audiobook eligibility.
-- This bypasses RLS on the audiobooks table during the check.
-- =====================================================

-- Drop the problematic INSERT policy
DROP POLICY IF EXISTS "Users can claim free audiobooks" ON public.entitlements;

-- =====================================================
-- HELPER FUNCTION: check_audiobook_is_free_and_approved
-- =====================================================
-- This function runs with SECURITY DEFINER, bypassing RLS.
-- It safely checks if an audiobook is free and approved.
-- Using BIGINT to match the audiobook_id column type in entitlements.
CREATE OR REPLACE FUNCTION public.check_audiobook_is_free_and_approved(ab_id BIGINT)
RETURNS BOOLEAN AS $$
DECLARE
    result BOOLEAN;
BEGIN
    SELECT (is_free = true AND status = 'approved')
    INTO result
    FROM public.audiobooks
    WHERE id = ab_id;

    RETURN COALESCE(result, false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.check_audiobook_is_free_and_approved(BIGINT) TO authenticated;

-- =====================================================
-- RECREATE INSERT POLICY using the helper function
-- =====================================================
-- This avoids circular RLS by using SECURITY DEFINER function
CREATE POLICY "Users can claim free audiobooks" ON public.entitlements
    FOR INSERT WITH CHECK (
        user_id = auth.uid()
        AND source = 'free'
        AND public.check_audiobook_is_free_and_approved(audiobook_id)
    );

-- =====================================================
-- VERIFY OTHER POLICIES STILL EXIST
-- =====================================================
-- Recreate SELECT policy if not exists (idempotent)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'entitlements'
          AND policyname = 'Users can view own entitlements'
    ) THEN
        CREATE POLICY "Users can view own entitlements" ON public.entitlements
            FOR SELECT USING (user_id = auth.uid());
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'entitlements'
          AND policyname = 'Admins can view all entitlements'
    ) THEN
        CREATE POLICY "Admins can view all entitlements" ON public.entitlements
            FOR SELECT USING (
                EXISTS (
                    SELECT 1 FROM public.profiles
                    WHERE id = auth.uid()
                    AND role = 'admin'
                )
            );
    END IF;
END $$;

-- =====================================================
-- NOTES
-- =====================================================
-- The SECURITY DEFINER function check_audiobook_is_free_and_approved
-- runs with the privileges of the function owner (typically postgres),
-- which bypasses RLS. This breaks the circular dependency.
--
-- Security is maintained because:
-- 1. The function only returns a boolean (no data leak)
-- 2. The function only checks is_free and status (safe conditions)
-- 3. The INSERT policy still requires user_id = auth.uid()
-- 4. The INSERT policy still requires source = 'free'
-- =====================================================
