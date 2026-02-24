-- =====================================================
-- FIX INFINITE RECURSION IN AUDIOBOOKS RLS POLICIES
-- =====================================================
-- This migration fixes PostgrestException(code: 42P17):
-- "infinite recursion detected in policy for relation 'audiobooks'"
--
-- ROOT CAUSE:
-- The policy "Owners can view their audiobooks" (from 20241219 migration)
-- queries the entitlements table. When combined with other policies and
-- foreign key joins (e.g., support_tickets → audiobooks), this creates
-- a circular policy evaluation chain.
--
-- SOLUTION:
-- 1. Drop ALL existing SELECT policies on audiobooks
-- 2. Create a SINGLE consolidated SELECT policy that combines:
--    - Public can see approved audiobooks
--    - Owners can see their entitled audiobooks (via direct subquery)
--    - Narrators can see their own audiobooks (any status)
--    - Admins can see all audiobooks
-- 3. The subquery to entitlements is safe because entitlements RLS
--    only checks user_id = auth.uid() for SELECT (no audiobooks reference)
--
-- IMPORTANT: This does NOT weaken security - it maintains the same
-- access control logic but avoids circular policy references.
-- =====================================================

-- Step 1: Drop ALL existing SELECT/ALL policies on audiobooks
-- We need to drop ALL policies and recreate them to avoid conflicts
DROP POLICY IF EXISTS "Anyone can view approved audiobooks" ON public.audiobooks;
DROP POLICY IF EXISTS "Owners can view their audiobooks" ON public.audiobooks;
DROP POLICY IF EXISTS "Narrators can manage own audiobooks" ON public.audiobooks;
DROP POLICY IF EXISTS "Admins can manage all audiobooks" ON public.audiobooks;

-- Step 2: Create a SINGLE consolidated SELECT policy
-- This combines all read conditions in one policy to avoid recursion
-- The subquery to entitlements is safe because:
-- - entitlements SELECT policy only checks: user_id = auth.uid()
-- - entitlements does NOT query audiobooks in its SELECT policy
-- - Therefore no circular reference can occur
CREATE POLICY "Audiobooks read access" ON public.audiobooks
    FOR SELECT USING (
        -- Condition 1: Anyone can see approved audiobooks
        status = 'approved'

        -- Condition 2: Owners can see audiobooks they have entitlements for
        -- (regardless of status - important for library screen)
        OR (
            auth.uid() IS NOT NULL
            AND id IN (
                SELECT audiobook_id
                FROM public.entitlements
                WHERE user_id = auth.uid()
            )
        )

        -- Condition 3: Narrators can see their own audiobooks (any status)
        OR narrator_id = auth.uid()

        -- Condition 4: Admins can see all audiobooks
        -- Using a direct role check to avoid additional subquery complexity
        OR (
            auth.uid() IS NOT NULL
            AND EXISTS (
                SELECT 1 FROM public.profiles
                WHERE id = auth.uid()
                AND role = 'admin'
            )
        )
    );

-- Step 3: Create separate policies for INSERT, UPDATE, DELETE
-- These don't need the "owner" condition since owners don't modify audiobooks

-- Narrators can INSERT (create) their own audiobooks
CREATE POLICY "Narrators can create audiobooks" ON public.audiobooks
    FOR INSERT WITH CHECK (narrator_id = auth.uid());

-- Narrators can UPDATE their own audiobooks
CREATE POLICY "Narrators can update own audiobooks" ON public.audiobooks
    FOR UPDATE USING (narrator_id = auth.uid());

-- Narrators can DELETE their own audiobooks (drafts only, typically)
CREATE POLICY "Narrators can delete own audiobooks" ON public.audiobooks
    FOR DELETE USING (narrator_id = auth.uid());

-- Admins can INSERT any audiobook
CREATE POLICY "Admins can create audiobooks" ON public.audiobooks
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- Admins can UPDATE any audiobook
CREATE POLICY "Admins can update audiobooks" ON public.audiobooks
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- Admins can DELETE any audiobook
CREATE POLICY "Admins can delete audiobooks" ON public.audiobooks
    FOR DELETE USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- =====================================================
-- ALSO FIX CHAPTERS POLICY (same pattern)
-- =====================================================
-- The chapters policy from 20241219 may have similar issues

DROP POLICY IF EXISTS "Anyone can view chapters of approved audiobooks" ON public.chapters;
DROP POLICY IF EXISTS "Owners can view chapters of their audiobooks" ON public.chapters;
DROP POLICY IF EXISTS "Narrators can manage own chapters" ON public.chapters;
DROP POLICY IF EXISTS "Admins can manage all chapters" ON public.chapters;

-- Single consolidated SELECT policy for chapters
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
            AND audiobook_id IN (
                SELECT audiobook_id
                FROM public.entitlements
                WHERE user_id = auth.uid()
            )
        )

        -- Condition 3: Narrators can see chapters of their own audiobooks
        OR EXISTS (
            SELECT 1 FROM public.audiobooks
            WHERE audiobooks.id = chapters.audiobook_id
            AND audiobooks.narrator_id = auth.uid()
        )

        -- Condition 4: Admins can see all chapters
        OR EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid()
            AND role = 'admin'
        )
    );

-- Narrators can manage chapters of their own audiobooks
CREATE POLICY "Narrators can manage own chapters" ON public.chapters
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.audiobooks
            WHERE audiobooks.id = chapters.audiobook_id
            AND audiobooks.narrator_id = auth.uid()
        )
    );

-- Admins can manage all chapters
CREATE POLICY "Admins can manage all chapters" ON public.chapters
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- =====================================================
-- VERIFICATION COMMENTS
-- =====================================================
-- After applying this migration:
--
-- 1. ADMIN users should be able to:
--    - View ALL audiobooks (any status) in admin dashboard
--    - View stats (pending, approved counts)
--    - View support tickets with audiobook references
--
-- 2. LISTENER users should be able to:
--    - View approved audiobooks (home, search, category screens)
--    - View their entitled/purchased audiobooks in library
--      (even if status changes from 'approved')
--
-- 3. NARRATOR users should be able to:
--    - View all their own audiobooks (any status)
--    - Manage (create, edit, delete) their own audiobooks
--
-- 4. NO RECURSION because:
--    - The entitlements table SELECT policy only checks user_id = auth.uid()
--    - It does NOT reference audiobooks table
--    - Therefore the subquery in audiobooks policy is safe
--
-- To verify: Run these queries as each role and confirm no errors:
-- SELECT * FROM audiobooks LIMIT 10;
-- SELECT * FROM audiobooks WHERE status = 'submitted';
-- SELECT *, audiobooks(title_fa) FROM support_tickets LIMIT 5;
-- =====================================================
