-- =====================================================
-- ADMIN DASHBOARD STATISTICS DIAGNOSTIC QUERY
-- =====================================================
-- Run this query to check the actual statistics in your database
-- Compare the results with what shows in the admin dashboard

-- 1. Check role distribution
SELECT
    role,
    COUNT(*) as count
FROM profiles
GROUP BY role
ORDER BY role;

-- 2. Check for NULL or empty roles
SELECT COUNT(*) as profiles_with_null_role
FROM profiles
WHERE role IS NULL OR role = '';

-- 3. Detailed listener count (should match admin dashboard)
SELECT COUNT(*) as total_listeners
FROM profiles
WHERE role = 'listener';

-- 4. Detailed narrator count (should match admin dashboard)
SELECT COUNT(*) as total_narrators
FROM profiles
WHERE role = 'narrator';

-- 5. Admin count
SELECT COUNT(*) as total_admins
FROM profiles
WHERE role = 'admin';

-- 6. Audiobook status distribution
SELECT
    status,
    COUNT(*) as count
FROM audiobooks
GROUP BY status
ORDER BY status;

-- 7. Check for narrators who have uploaded content
SELECT
    p.id,
    p.display_name,
    p.role,
    COUNT(DISTINCT a.id) as audiobooks_count
FROM profiles p
LEFT JOIN audiobooks a ON a.narrator_id = p.id
WHERE a.id IS NOT NULL
GROUP BY p.id, p.display_name, p.role
ORDER BY audiobooks_count DESC
LIMIT 20;

-- 8. Purchase statistics
SELECT
    COUNT(*) as total_purchases,
    SUM(amount) as total_revenue,
    AVG(amount) as average_purchase
FROM purchases;

-- 9. Check for profiles without proper role assignment
SELECT
    id,
    display_name,
    email,
    role,
    created_at
FROM profiles
WHERE role NOT IN ('listener', 'narrator', 'admin')
   OR role IS NULL
ORDER BY created_at DESC
LIMIT 10;
