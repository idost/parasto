-- Create narrator_requests table for users requesting narrator status
CREATE TABLE public.narrator_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    experience_text TEXT NOT NULL,
    voice_sample_path TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    reviewed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    admin_feedback TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- One pending request per user (prevents spam)
CREATE UNIQUE INDEX idx_narrator_requests_one_pending_per_user
    ON public.narrator_requests(user_id)
    WHERE status = 'pending';

-- Index for admin filtering by status
CREATE INDEX idx_narrator_requests_status ON public.narrator_requests(status);

-- Index for admin sorting by date
CREATE INDEX idx_narrator_requests_created_at ON public.narrator_requests(created_at DESC);

-- RLS Policies
ALTER TABLE public.narrator_requests ENABLE ROW LEVEL SECURITY;

-- Users can view their own requests
CREATE POLICY "Users can view own requests"
    ON public.narrator_requests
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- Users can create their own requests
CREATE POLICY "Users can create own requests"
    ON public.narrator_requests
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- Admins can view all requests
CREATE POLICY "Admins can view all requests"
    ON public.narrator_requests
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role = 'admin'
        )
    );

-- Admins can update all requests
CREATE POLICY "Admins can update all requests"
    ON public.narrator_requests
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role = 'admin'
        )
    );

-- Admins can delete all requests
CREATE POLICY "Admins can delete all requests"
    ON public.narrator_requests
    FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role = 'admin'
        )
    );

-- Storage bucket for voice samples (private)
INSERT INTO storage.buckets (id, name, public)
VALUES ('narrator-requests', 'narrator-requests', false)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS: Users can upload to their own folder
CREATE POLICY "Users can upload own voice samples"
    ON storage.objects
    FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'narrator-requests'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- Storage RLS: Users can view their own voice samples
CREATE POLICY "Users can view own voice samples"
    ON storage.objects
    FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'narrator-requests'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- Storage RLS: Admins can view all voice samples
CREATE POLICY "Admins can view all voice samples"
    ON storage.objects
    FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'narrator-requests'
        AND EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid()
            AND profiles.role = 'admin'
        )
    );

-- Storage RLS: Users can delete their own voice samples
CREATE POLICY "Users can delete own voice samples"
    ON storage.objects
    FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'narrator-requests'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- Updated_at trigger
CREATE OR REPLACE FUNCTION public.update_narrator_requests_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER narrator_requests_updated_at_trigger
    BEFORE UPDATE ON public.narrator_requests
    FOR EACH ROW
    EXECUTE FUNCTION public.update_narrator_requests_updated_at();

-- Comment
COMMENT ON TABLE public.narrator_requests IS 'Stores narrator status requests from listeners with voice samples';
