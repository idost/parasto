-- Create audit_logs table for activity tracking
-- This table supports the گزارش فعالیت‌ها feature in admin dashboard

-- ============================================================================
-- AUDIT LOGS TABLE
-- Tracks all admin actions and system events
-- ============================================================================

CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID REFERENCES auth.users(id),
    actor_email TEXT,
    action TEXT NOT NULL CHECK (action IN (
        'create', 'update', 'delete',
        'approve', 'reject',
        'feature', 'unfeature',
        'ban', 'unban',
        'role_change',
        'login', 'logout',
        'export', 'import',
        'bulk_action'
    )),
    entity_type TEXT NOT NULL CHECK (entity_type IN (
        'audiobook', 'user', 'creator', 'category',
        'ticket', 'narrator_request', 'promotion',
        'schedule', 'settings'
    )),
    entity_id TEXT NOT NULL,
    old_values JSONB,
    new_values JSONB,
    changed_fields TEXT[],
    description TEXT,
    ip_address TEXT,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor ON audit_logs(actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action_date ON audit_logs(action, created_at DESC);

-- ============================================================================
-- RLS POLICIES
-- ============================================================================

-- Enable RLS
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to allow re-creation (idempotent)
DROP POLICY IF EXISTS "Admins can read audit_logs" ON audit_logs;
DROP POLICY IF EXISTS "Authenticated users can insert audit_logs" ON audit_logs;

-- Admins can read all audit logs
CREATE POLICY "Admins can read audit_logs"
ON audit_logs
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM profiles
        WHERE profiles.id = auth.uid()
        AND profiles.role = 'admin'
    )
);

-- Authenticated users can insert audit logs (for logging their own actions)
CREATE POLICY "Authenticated users can insert audit_logs"
ON audit_logs
FOR INSERT
TO authenticated
WITH CHECK (
    actor_id = auth.uid()
);

-- ============================================================================
-- TRIGGER FUNCTION FOR AUTOMATIC AUDIT LOGGING
-- Can be attached to tables that need automatic audit logging
-- ============================================================================

CREATE OR REPLACE FUNCTION log_audit_event()
RETURNS TRIGGER AS $$
DECLARE
    changed_cols TEXT[];
    old_json JSONB;
    new_json JSONB;
    entity TEXT;
BEGIN
    -- Determine entity type from table name
    entity := TG_TABLE_NAME;
    IF entity = 'audiobooks' THEN entity := 'audiobook';
    ELSIF entity = 'profiles' THEN entity := 'user';
    ELSIF entity = 'creators' THEN entity := 'creator';
    ELSIF entity = 'categories' THEN entity := 'category';
    ELSIF entity = 'tickets' THEN entity := 'ticket';
    ELSIF entity = 'narrator_requests' THEN entity := 'narrator_request';
    ELSIF entity = 'scheduled_promotions' THEN entity := 'promotion';
    ELSIF entity = 'scheduled_features' THEN entity := 'schedule';
    END IF;

    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_logs (
            actor_id,
            action,
            entity_type,
            entity_id,
            new_values
        ) VALUES (
            auth.uid(),
            'create',
            entity,
            NEW.id::TEXT,
            to_jsonb(NEW)
        );
        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN
        -- Calculate changed fields
        old_json := to_jsonb(OLD);
        new_json := to_jsonb(NEW);
        SELECT array_agg(key) INTO changed_cols
        FROM jsonb_each(new_json) n
        WHERE old_json->n.key IS DISTINCT FROM n.value
        AND n.key NOT IN ('updated_at', 'created_at');

        -- Only log if there are actual changes (excluding timestamps)
        IF array_length(changed_cols, 1) > 0 THEN
            INSERT INTO audit_logs (
                actor_id,
                action,
                entity_type,
                entity_id,
                old_values,
                new_values,
                changed_fields
            ) VALUES (
                auth.uid(),
                'update',
                entity,
                NEW.id::TEXT,
                old_json,
                new_json,
                changed_cols
            );
        END IF;
        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_logs (
            actor_id,
            action,
            entity_type,
            entity_id,
            old_values
        ) VALUES (
            auth.uid(),
            'delete',
            entity,
            OLD.id::TEXT,
            to_jsonb(OLD)
        );
        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- ATTACH AUDIT TRIGGERS TO KEY TABLES
-- Uncomment and run these to enable automatic audit logging
-- ============================================================================

-- Audiobooks audit trigger
-- CREATE TRIGGER audit_audiobooks
--     AFTER INSERT OR UPDATE OR DELETE ON audiobooks
--     FOR EACH ROW EXECUTE FUNCTION log_audit_event();

-- Profiles audit trigger
-- CREATE TRIGGER audit_profiles
--     AFTER INSERT OR UPDATE OR DELETE ON profiles
--     FOR EACH ROW EXECUTE FUNCTION log_audit_event();

-- Categories audit trigger
-- CREATE TRIGGER audit_categories
--     AFTER INSERT OR UPDATE OR DELETE ON categories
--     FOR EACH ROW EXECUTE FUNCTION log_audit_event();
