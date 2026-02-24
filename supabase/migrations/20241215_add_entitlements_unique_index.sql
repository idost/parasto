-- =====================================================
-- ADD UNIQUE INDEX ON ENTITLEMENTS
-- =====================================================
-- This ensures database-level idempotency for entitlements.
-- A user can only have one entitlement per audiobook.
-- This prevents race conditions in webhook processing.
-- =====================================================

-- Create unique index if not exists
-- Using CREATE UNIQUE INDEX ... IF NOT EXISTS for idempotency
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = 'public'
          AND tablename = 'entitlements'
          AND indexname = 'idx_entitlements_user_audiobook_unique'
    ) THEN
        CREATE UNIQUE INDEX idx_entitlements_user_audiobook_unique
        ON public.entitlements (user_id, audiobook_id);
    END IF;
END $$;

-- Also add an index on payment_id for faster lookup during idempotency checks
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = 'public'
          AND tablename = 'entitlements'
          AND indexname = 'idx_entitlements_payment_id'
    ) THEN
        CREATE INDEX idx_entitlements_payment_id
        ON public.entitlements (payment_id)
        WHERE payment_id IS NOT NULL;
    END IF;
END $$;
