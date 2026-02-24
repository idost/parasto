-- =====================================================
-- FIX ENTITLEMENTS RLS POLICIES
-- =====================================================
-- This migration ensures the entitlements table has correct RLS policies:
-- 1. Users can SELECT their own entitlements
-- 2. Users can INSERT entitlements for FREE audiobooks only
-- 3. Admins can view all entitlements
--
-- The previous migration (20241213) may not have created all policies.
-- This migration recreates them properly.
-- =====================================================

-- Ensure RLS is enabled
ALTER TABLE public.entitlements ENABLE ROW LEVEL SECURITY;

-- Drop ALL existing policies to start fresh
DROP POLICY IF EXISTS "Users can view own entitlements" ON public.entitlements;
DROP POLICY IF EXISTS "Users can insert own entitlements" ON public.entitlements;
DROP POLICY IF EXISTS "Users can claim free audiobooks" ON public.entitlements;
DROP POLICY IF EXISTS "Admins can view all entitlements" ON public.entitlements;

-- =====================================================
-- POLICY 1: Users can SELECT their own entitlements
-- =====================================================
CREATE POLICY "Users can view own entitlements" ON public.entitlements
    FOR SELECT USING (user_id = auth.uid());

-- =====================================================
-- POLICY 2: Users can INSERT entitlements for FREE audiobooks ONLY
-- =====================================================
-- This is the critical policy that allows free book claiming.
-- Requirements:
-- 1. user_id must match the authenticated user
-- 2. source must be 'free'
-- 3. The audiobook must be is_free = true AND status = 'approved'
CREATE POLICY "Users can claim free audiobooks" ON public.entitlements
    FOR INSERT WITH CHECK (
        user_id = auth.uid()
        AND source = 'free'
        AND EXISTS (
            SELECT 1 FROM public.audiobooks
            WHERE id = audiobook_id
            AND is_free = true
            AND status = 'approved'
        )
    );

-- =====================================================
-- POLICY 3: Admins can view all entitlements
-- =====================================================
CREATE POLICY "Admins can view all entitlements" ON public.entitlements
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid()
            AND role = 'admin'
        )
    );

-- =====================================================
-- NOTES
-- =====================================================
-- - service_role (used by Stripe webhook Edge Function) bypasses RLS entirely
--   so it can INSERT entitlements for PAID content without any policy
-- - This migration is idempotent (safe to run multiple times)
-- =====================================================
