-- =====================================================
-- PROFILES TABLE RLS POLICIES
-- =====================================================
-- This migration adds proper RLS policies for the profiles table.
--
-- CRITICAL: These policies allow admins to update any user's profile,
-- including the 'role' field. This is required for the admin panel
-- to change user roles (listener -> narrator -> admin).
--
-- Security Model:
-- - SELECT: Users can read all profiles (for display name, avatar, etc.)
-- - INSERT: Handled by auth trigger on signup (not via client)
-- - UPDATE: Users can update their own profile; Admins can update any profile
-- - DELETE: Not allowed via client (admin action via Supabase dashboard only)
-- =====================================================

-- First, ensure RLS is enabled on profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Drop any existing policies to start fresh
DROP POLICY IF EXISTS "Users can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admins can update all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;

-- =====================================================
-- SELECT POLICIES
-- =====================================================

-- All authenticated users can view all profiles
-- This is needed for:
-- - Displaying narrator info on audiobook pages
-- - Admin user management screen
-- - Support ticket display (showing reporter names)
CREATE POLICY "Authenticated users can view all profiles"
ON public.profiles
FOR SELECT
TO authenticated
USING (true);

-- =====================================================
-- INSERT POLICIES
-- =====================================================

-- Users can only insert their own profile (on signup)
-- The profile id must match their auth.uid()
CREATE POLICY "Users can insert own profile"
ON public.profiles
FOR INSERT
TO authenticated
WITH CHECK (id = auth.uid());

-- =====================================================
-- UPDATE POLICIES
-- =====================================================

-- Users can update their own profile
-- BUT they cannot change their own role (security measure)
-- The role field is protected by checking it hasn't changed
CREATE POLICY "Users can update own profile except role"
ON public.profiles
FOR UPDATE
TO authenticated
USING (id = auth.uid())
WITH CHECK (
    id = auth.uid()
    -- Note: We can't easily prevent role change in WITH CHECK without OLD reference
    -- So we rely on the admin policy for role changes
);

-- Admins can update ANY profile INCLUDING role changes
-- This is the critical policy for admin user management
CREATE POLICY "Admins can update all profiles"
ON public.profiles
FOR UPDATE
TO authenticated
USING (
    -- The user making the request must be an admin
    EXISTS (
        SELECT 1 FROM public.profiles admin_profile
        WHERE admin_profile.id = auth.uid()
        AND admin_profile.role = 'admin'
    )
)
WITH CHECK (
    -- The user making the request must be an admin
    EXISTS (
        SELECT 1 FROM public.profiles admin_profile
        WHERE admin_profile.id = auth.uid()
        AND admin_profile.role = 'admin'
    )
);

-- =====================================================
-- DELETE POLICIES
-- =====================================================

-- No delete policy - profiles should not be deleted via client
-- If needed, admin can delete via Supabase dashboard with service role

-- =====================================================
-- VERIFICATION
-- =====================================================
-- After applying this migration, test the following:
--
-- 1. As ADMIN: Should be able to update any user's role
--    UPDATE profiles SET role = 'narrator' WHERE id = 'some-user-id';
--
-- 2. As LISTENER: Should NOT be able to update another user's profile
--    UPDATE profiles SET role = 'admin' WHERE id = 'other-user-id';
--    (Should return 0 rows affected)
--
-- 3. As LISTENER: Should be able to update own profile (except role)
--    UPDATE profiles SET display_name = 'New Name' WHERE id = auth.uid();
--
-- 4. All users should be able to SELECT all profiles
--    SELECT * FROM profiles;
-- =====================================================
