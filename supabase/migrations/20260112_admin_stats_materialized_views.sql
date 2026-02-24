-- Migration: Admin Stats Materialized Views
-- Purpose: Pre-compute admin dashboard statistics for fast retrieval at scale
-- Date: 2026-01-12
--
-- BENEFITS:
-- 1. Dashboard loads instantly (no aggregation at query time)
-- 2. Reduces database load from repeated aggregation queries
-- 3. Scales to millions of records without performance degradation
--
-- MAINTENANCE:
-- Views should be refreshed periodically (hourly recommended)
-- Use pg_cron or application-level scheduling

-- ============================================================================
-- DAILY CONTENT STATS
-- ============================================================================

-- Drop if exists for clean migration
DROP MATERIALIZED VIEW IF EXISTS admin_content_stats_daily CASCADE;

-- Daily aggregated content statistics
CREATE MATERIALIZED VIEW admin_content_stats_daily AS
SELECT
  DATE(created_at) as date,
  COUNT(*) as total_audiobooks,
  COUNT(*) FILTER (WHERE status = 'approved') as approved_count,
  COUNT(*) FILTER (WHERE status = 'submitted') as submitted_count,
  COUNT(*) FILTER (WHERE status = 'draft') as draft_count,
  COUNT(*) FILTER (WHERE status = 'rejected') as rejected_count,
  COUNT(*) FILTER (WHERE is_music = true) as music_count,
  COUNT(*) FILTER (WHERE is_music = false) as book_count,
  COUNT(*) FILTER (WHERE is_free = true) as free_count,
  COUNT(*) FILTER (WHERE is_free = false) as paid_count,
  SUM(play_count) as total_plays,
  COUNT(DISTINCT narrator_id) as active_narrators,
  COUNT(DISTINCT category_id) as categories_used
FROM audiobooks
GROUP BY DATE(created_at)
ORDER BY date DESC;

-- Index for fast date lookups
CREATE UNIQUE INDEX idx_content_stats_daily_date
ON admin_content_stats_daily(date);

-- ============================================================================
-- OVERALL CONTENT SUMMARY
-- ============================================================================

DROP MATERIALIZED VIEW IF EXISTS admin_content_summary CASCADE;

-- Current totals for dashboard cards
CREATE MATERIALIZED VIEW admin_content_summary AS
SELECT
  COUNT(*) as total_audiobooks,
  COUNT(*) FILTER (WHERE status = 'approved') as approved_count,
  COUNT(*) FILTER (WHERE status = 'submitted') as pending_count,
  COUNT(*) FILTER (WHERE is_music = true) as music_count,
  COUNT(*) FILTER (WHERE is_music = false) as book_count,
  COUNT(*) FILTER (WHERE is_free = true) as free_count,
  SUM(play_count) as total_plays,
  SUM(total_duration_seconds) as total_duration_seconds,
  AVG(avg_rating) FILTER (WHERE avg_rating > 0) as average_rating,
  COUNT(DISTINCT narrator_id) as total_narrators,
  COUNT(DISTINCT category_id) as total_categories
FROM audiobooks;

-- ============================================================================
-- DAILY USER STATS
-- ============================================================================

DROP MATERIALIZED VIEW IF EXISTS admin_user_stats_daily CASCADE;

-- Daily user registration and activity
CREATE MATERIALIZED VIEW admin_user_stats_daily AS
SELECT
  DATE(created_at) as date,
  COUNT(*) as new_users,
  COUNT(*) FILTER (WHERE role = 'listener') as new_listeners,
  COUNT(*) FILTER (WHERE role = 'narrator') as new_narrators,
  COUNT(*) FILTER (WHERE role = 'admin') as new_admins
FROM profiles
GROUP BY DATE(created_at)
ORDER BY date DESC;

CREATE UNIQUE INDEX idx_user_stats_daily_date
ON admin_user_stats_daily(date);

-- ============================================================================
-- USER SUMMARY
-- ============================================================================

DROP MATERIALIZED VIEW IF EXISTS admin_user_summary CASCADE;

-- Current user totals
CREATE MATERIALIZED VIEW admin_user_summary AS
SELECT
  COUNT(*) as total_users,
  COUNT(*) FILTER (WHERE role = 'listener') as listener_count,
  COUNT(*) FILTER (WHERE role = 'narrator') as narrator_count,
  COUNT(*) FILTER (WHERE role = 'admin') as admin_count,
  COUNT(*) FILTER (WHERE is_disabled = true) as disabled_count,
  COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '7 days') as new_this_week,
  COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '30 days') as new_this_month
FROM profiles;

-- ============================================================================
-- DAILY REVENUE STATS
-- ============================================================================

DROP MATERIALIZED VIEW IF EXISTS admin_revenue_stats_daily CASCADE;

-- Daily purchase and revenue tracking
CREATE MATERIALIZED VIEW admin_revenue_stats_daily AS
SELECT
  DATE(created_at) as date,
  COUNT(*) as purchase_count,
  COALESCE(SUM(amount), 0) as total_revenue,
  COALESCE(AVG(amount), 0) as avg_purchase_amount,
  COUNT(DISTINCT user_id) as unique_buyers,
  COUNT(DISTINCT audiobook_id) as unique_products_sold
FROM purchases
GROUP BY DATE(created_at)
ORDER BY date DESC;

CREATE UNIQUE INDEX idx_revenue_stats_daily_date
ON admin_revenue_stats_daily(date);

-- ============================================================================
-- REVENUE SUMMARY
-- ============================================================================

DROP MATERIALIZED VIEW IF EXISTS admin_revenue_summary CASCADE;

-- Current revenue totals
CREATE MATERIALIZED VIEW admin_revenue_summary AS
SELECT
  COUNT(*) as total_purchases,
  COALESCE(SUM(amount), 0) as total_revenue,
  COALESCE(AVG(amount), 0) as avg_purchase_amount,
  COUNT(DISTINCT user_id) as total_unique_buyers,
  COALESCE(SUM(amount) FILTER (WHERE created_at >= NOW() - INTERVAL '7 days'), 0) as revenue_this_week,
  COALESCE(SUM(amount) FILTER (WHERE created_at >= NOW() - INTERVAL '30 days'), 0) as revenue_this_month,
  COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '24 hours') as purchases_today
FROM purchases;

-- ============================================================================
-- LISTENING ACTIVITY STATS
-- ============================================================================

DROP MATERIALIZED VIEW IF EXISTS admin_listening_stats_daily CASCADE;

-- Daily listening activity
CREATE MATERIALIZED VIEW admin_listening_stats_daily AS
SELECT
  session_date as date,
  COUNT(*) as session_count,
  COUNT(DISTINCT user_id) as unique_listeners,
  COUNT(DISTINCT audiobook_id) as unique_audiobooks_played,
  SUM(duration_seconds) as total_listening_seconds
FROM listening_sessions
GROUP BY session_date
ORDER BY session_date DESC;

CREATE UNIQUE INDEX idx_listening_stats_daily_date
ON admin_listening_stats_daily(date);

-- ============================================================================
-- POPULAR CONTENT STATS
-- ============================================================================

DROP MATERIALIZED VIEW IF EXISTS admin_popular_content CASCADE;

-- Top content by various metrics (for charts)
CREATE MATERIALIZED VIEW admin_popular_content AS
SELECT
  a.id,
  a.title_fa,
  a.is_music,
  a.play_count,
  a.avg_rating,
  a.created_at,
  COALESCE(purchase_stats.purchase_count, 0) as purchase_count,
  COALESCE(purchase_stats.revenue, 0) as revenue
FROM audiobooks a
LEFT JOIN (
  SELECT
    audiobook_id,
    COUNT(*) as purchase_count,
    SUM(amount) as revenue
  FROM purchases
  GROUP BY audiobook_id
) purchase_stats ON purchase_stats.audiobook_id = a.id
WHERE a.status = 'approved'
ORDER BY a.play_count DESC
LIMIT 100;

-- ============================================================================
-- REFRESH FUNCTIONS
-- ============================================================================

-- Function to refresh all admin stats views
CREATE OR REPLACE FUNCTION refresh_admin_stats()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY admin_content_stats_daily;
  REFRESH MATERIALIZED VIEW admin_content_summary;
  REFRESH MATERIALIZED VIEW CONCURRENTLY admin_user_stats_daily;
  REFRESH MATERIALIZED VIEW admin_user_summary;
  REFRESH MATERIALIZED VIEW CONCURRENTLY admin_revenue_stats_daily;
  REFRESH MATERIALIZED VIEW admin_revenue_summary;
  REFRESH MATERIALIZED VIEW CONCURRENTLY admin_listening_stats_daily;
  REFRESH MATERIALIZED VIEW admin_popular_content;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON MATERIALIZED VIEW admin_content_stats_daily IS
'Daily aggregated content statistics. Refresh hourly for dashboard charts.';

COMMENT ON MATERIALIZED VIEW admin_content_summary IS
'Current content totals for dashboard cards. Refresh every 15 minutes.';

COMMENT ON MATERIALIZED VIEW admin_user_stats_daily IS
'Daily user registration stats. Refresh hourly.';

COMMENT ON MATERIALIZED VIEW admin_revenue_stats_daily IS
'Daily revenue and purchase stats. Refresh hourly.';

COMMENT ON FUNCTION refresh_admin_stats() IS
'Refreshes all admin dashboard materialized views. Call hourly via pg_cron or application scheduler.';

-- ============================================================================
-- INITIAL REFRESH
-- ============================================================================

-- Populate the views immediately
SELECT refresh_admin_stats();
