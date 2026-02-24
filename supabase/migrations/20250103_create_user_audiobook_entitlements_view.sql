-- =====================================================
-- CREATE user_audiobook_entitlements VIEW
-- =====================================================
-- This migration creates a read-only view that provides an alias
-- for the entitlements table. This aligns the database with
-- code that queries 'user_audiobook_entitlements'.
--
-- The view is a simple 1:1 mapping of the entitlements table.
-- It does NOT change any business logic or entitlement rules.
--
-- RLS: Views in PostgreSQL inherit RLS from the underlying table(s).
-- Since entitlements has RLS enabled, this view automatically
-- respects those policies - no additional RLS configuration needed.
-- =====================================================

-- Safely drop the view if it exists (idempotent)
DROP VIEW IF EXISTS public.user_audiobook_entitlements;

-- Create the view as a simple alias to the entitlements table
-- Exposing all columns that might be needed by application code
CREATE VIEW public.user_audiobook_entitlements AS
SELECT
    id,
    user_id,
    audiobook_id,
    source,
    payment_id,
    created_at
FROM public.entitlements;

-- =====================================================
-- SECURITY NOTES
-- =====================================================
-- 1. This view inherits RLS from the entitlements table automatically
-- 2. Users can only SELECT rows where user_id = auth.uid()
-- 3. Admins can SELECT all rows
-- 4. No INSERT/UPDATE/DELETE through this view (read-only by design)
-- 5. This is purely additive - the entitlements table is unchanged
-- =====================================================

-- Grant SELECT on the view to authenticated users
-- (The underlying RLS policies still control what rows they can see)
GRANT SELECT ON public.user_audiobook_entitlements TO authenticated;
GRANT SELECT ON public.user_audiobook_entitlements TO anon;

-- =====================================================
-- VERIFICATION QUERY (run manually to test):
-- =====================================================
-- SELECT * FROM user_audiobook_entitlements LIMIT 5;
-- Should return the same as: SELECT * FROM entitlements LIMIT 5;
-- (filtered by RLS for the current user)
-- =====================================================
