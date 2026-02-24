-- Migration: Secure purchases table with proper RLS policies
-- Purpose: Prevent users from inserting fake purchase records
--          Only service_role (webhooks) should be able to insert purchases
-- Risk: LOW - Current behavior already uses service_role for purchases

-- Ensure RLS is enabled on purchases table
ALTER TABLE purchases ENABLE ROW LEVEL SECURITY;

-- DROP existing policies if any (safe - will recreate SELECT policies)
DROP POLICY IF EXISTS "Users can view own purchases" ON purchases;
DROP POLICY IF EXISTS "Admins can view all purchases" ON purchases;

-- Policy: Users can only view their own purchases
CREATE POLICY "Users can view own purchases"
ON public.purchases
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Policy: Admins can view all purchases
CREATE POLICY "Admins can view all purchases"
ON public.purchases
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role = 'admin'
  )
);

-- Policy: Only service_role can insert purchases (webhooks only)
CREATE POLICY "Service role only can insert purchases"
ON public.purchases
FOR INSERT
TO service_role
WITH CHECK (true);

-- Policy: Prevent UPDATE - purchases should be immutable after creation
CREATE POLICY "Prevent purchase updates"
ON public.purchases
FOR UPDATE
USING (false);

-- Policy: Prevent DELETE - purchases should never be deleted (audit trail)
CREATE POLICY "Prevent purchase deletes"
ON public.purchases
FOR DELETE
USING (false);

-- Add comments for documentation
COMMENT ON POLICY "Service role only can insert purchases" ON purchases IS
'Only service_role (Stripe webhooks) can insert purchase records.
Prevents users from creating fake purchases via client code.';

COMMENT ON POLICY "Prevent purchase updates" ON purchases IS
'Purchases are immutable after creation for audit trail integrity.';

COMMENT ON POLICY "Prevent purchase deletes" ON purchases IS
'Purchases cannot be deleted to maintain complete transaction history.';
