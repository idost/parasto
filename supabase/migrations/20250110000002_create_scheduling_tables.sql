-- Create scheduling tables for featured content and promotions
-- These tables support the زمان‌بندی محتوا feature in admin dashboard

-- ============================================================================
-- SCHEDULED FEATURES TABLE
-- For managing featured/banner/hero content scheduling
-- ============================================================================

CREATE TABLE IF NOT EXISTS scheduled_features (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    audiobook_id INTEGER NOT NULL REFERENCES audiobooks(id) ON DELETE CASCADE,
    feature_type TEXT NOT NULL DEFAULT 'featured' CHECK (feature_type IN ('featured', 'banner', 'hero', 'category_highlight')),
    status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'active', 'completed', 'cancelled')),
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ,
    priority INTEGER DEFAULT 0,
    notes TEXT,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_scheduled_features_audiobook ON scheduled_features(audiobook_id);
CREATE INDEX IF NOT EXISTS idx_scheduled_features_status ON scheduled_features(status);
CREATE INDEX IF NOT EXISTS idx_scheduled_features_dates ON scheduled_features(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_scheduled_features_type_status ON scheduled_features(feature_type, status);

-- ============================================================================
-- SCHEDULED PROMOTIONS TABLE
-- For managing discounts and promotional campaigns
-- ============================================================================

CREATE TABLE IF NOT EXISTS scheduled_promotions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    audiobook_id INTEGER REFERENCES audiobooks(id) ON DELETE CASCADE,
    category_id INTEGER REFERENCES categories(id) ON DELETE CASCADE,
    creator_id UUID REFERENCES creators(id) ON DELETE CASCADE,
    scope TEXT NOT NULL DEFAULT 'single' CHECK (scope IN ('single', 'category', 'creator', 'all')),
    discount_type TEXT NOT NULL DEFAULT 'percentage' CHECK (discount_type IN ('percentage', 'fixed')),
    discount_value DECIMAL(10,2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'active', 'completed', 'cancelled')),
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    title_fa TEXT NOT NULL,
    title_en TEXT,
    description TEXT,
    banner_url TEXT,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_scheduled_promotions_status ON scheduled_promotions(status);
CREATE INDEX IF NOT EXISTS idx_scheduled_promotions_dates ON scheduled_promotions(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_scheduled_promotions_audiobook ON scheduled_promotions(audiobook_id);
CREATE INDEX IF NOT EXISTS idx_scheduled_promotions_category ON scheduled_promotions(category_id);

-- ============================================================================
-- RLS POLICIES
-- ============================================================================

-- Enable RLS
ALTER TABLE scheduled_features ENABLE ROW LEVEL SECURITY;
ALTER TABLE scheduled_promotions ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to allow re-creation (idempotent)
DROP POLICY IF EXISTS "Admins can manage scheduled_features" ON scheduled_features;
DROP POLICY IF EXISTS "Admins can manage scheduled_promotions" ON scheduled_promotions;

-- Admins can do everything with scheduled_features
CREATE POLICY "Admins can manage scheduled_features"
ON scheduled_features
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role = 'admin'
    )
);

-- Admins can do everything with scheduled_promotions
CREATE POLICY "Admins can manage scheduled_promotions"
ON scheduled_promotions
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role = 'admin'
    )
);

-- ============================================================================
-- AUTO-UPDATE TRIGGER FOR updated_at
-- ============================================================================

CREATE OR REPLACE FUNCTION update_scheduled_features_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS scheduled_features_updated_at ON scheduled_features;
CREATE TRIGGER scheduled_features_updated_at
    BEFORE UPDATE ON scheduled_features
    FOR EACH ROW
    EXECUTE FUNCTION update_scheduled_features_updated_at();

CREATE OR REPLACE FUNCTION update_scheduled_promotions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS scheduled_promotions_updated_at ON scheduled_promotions;
CREATE TRIGGER scheduled_promotions_updated_at
    BEFORE UPDATE ON scheduled_promotions
    FOR EACH ROW
    EXECUTE FUNCTION update_scheduled_promotions_updated_at();

-- ============================================================================
-- FUNCTION TO AUTO-UPDATE SCHEDULE STATUS
-- Run periodically via cron or on-demand
-- ============================================================================

CREATE OR REPLACE FUNCTION update_schedule_statuses()
RETURNS void AS $$
BEGIN
    -- Activate scheduled features that have reached their start date
    UPDATE scheduled_features
    SET status = 'active'
    WHERE status = 'scheduled'
    AND start_date <= NOW();

    -- Complete active features that have passed their end date
    UPDATE scheduled_features
    SET status = 'completed'
    WHERE status = 'active'
    AND end_date IS NOT NULL
    AND end_date <= NOW();

    -- Same for promotions
    UPDATE scheduled_promotions
    SET status = 'active'
    WHERE status = 'scheduled'
    AND start_date <= NOW();

    UPDATE scheduled_promotions
    SET status = 'completed'
    WHERE status = 'active'
    AND end_date <= NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
