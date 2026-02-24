-- =====================================================
-- SECURE ENTITLEMENTS RLS POLICIES
-- =====================================================
-- This migration updates RLS policies on the entitlements table
-- to prevent client-side entitlement creation for paid content.
--
-- After this migration:
-- - Users can SELECT their own entitlements
-- - Users can INSERT entitlements ONLY for FREE audiobooks
-- - Only service_role (webhooks) can INSERT entitlements for paid content
-- - Admins can view all entitlements
-- =====================================================

-- =====================================================
-- ADD source COLUMN TO ENTITLEMENTS (if not exists)
-- =====================================================
-- This column tracks how the entitlement was obtained: 'free', 'purchase', 'gift', etc.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'entitlements'
        AND column_name = 'source'
    ) THEN
        ALTER TABLE public.entitlements ADD COLUMN source TEXT DEFAULT 'purchase';
    END IF;
END $$;

-- First, drop the existing overly-permissive INSERT policy (if exists)
DROP POLICY IF EXISTS "Users can insert own entitlements" ON public.entitlements;

-- Create a restricted INSERT policy that only allows free book claims (idempotent)
-- This policy verifies:
-- 1. The user_id matches the authenticated user
-- 2. The source is 'free'
-- 3. The audiobook is actually marked as free in the database
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'entitlements'
          AND policyname = 'Users can claim free audiobooks'
    ) THEN
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
    END IF;
END $$;

-- Note: service_role bypasses RLS entirely, so the stripe-webhook
-- Edge Function can INSERT entitlements for paid content without
-- needing a specific policy.

-- =====================================================
-- HELPER FUNCTION: increment_purchase_count
-- =====================================================
-- Create or replace the function to increment purchase count
-- This is called by the webhook after successful payment

CREATE OR REPLACE FUNCTION public.increment_purchase_count(audiobook_id INTEGER)
RETURNS void AS $$
BEGIN
    UPDATE public.audiobooks
    SET purchase_count = purchase_count + 1
    WHERE id = audiobook_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users and service_role
GRANT EXECUTE ON FUNCTION public.increment_purchase_count(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.increment_purchase_count(INTEGER) TO service_role;

-- =====================================================
-- ADD payment_id COLUMN TO ENTITLEMENTS (if not exists)
-- =====================================================
-- Add a column to store the Stripe PaymentIntent ID for audit purposes

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'entitlements'
        AND column_name = 'payment_id'
    ) THEN
        ALTER TABLE public.entitlements ADD COLUMN payment_id TEXT;
    END IF;
END $$;

-- =====================================================
-- SUMMARY OF FINAL POLICIES ON ENTITLEMENTS
-- =====================================================
-- After this migration, the policies should be:
--
-- 1. "Users can view own entitlements" - SELECT - user_id = auth.uid()
-- 2. "Users can claim free audiobooks" - INSERT - restricted as above
-- 3. "Admins can view all entitlements" - SELECT - role = 'admin'
--
-- service_role (webhooks) bypasses RLS and can INSERT any entitlement
-- =====================================================
