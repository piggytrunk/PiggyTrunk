-- ==============================================================================
-- 37_app_versions.sql
-- Table to manage mobile app versions and in-app update checks for Piggy Trunk
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.app_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    platform TEXT NOT NULL DEFAULT 'android' CHECK (platform IN ('android', 'ios')),
    version_name TEXT NOT NULL,
    version_code INTEGER NOT NULL,
    min_supported_version TEXT DEFAULT '1.0.0',
    min_supported_version_code INTEGER DEFAULT 1,
    release_notes TEXT[] DEFAULT ARRAY[]::TEXT[],
    apk_url TEXT NOT NULL DEFAULT 'https://github.com/rewithjie/Piggy-Trunk/releases/latest/download/PiggyTrunkMobile.apk',
    file_size_bytes BIGINT DEFAULT 26822477,
    file_size_mb NUMERIC(5,2) DEFAULT 25.58,
    force_update BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    released_at TIMESTAMPTZ DEFAULT NOW()
);

-- Grants
GRANT ALL ON TABLE public.app_versions TO anon, authenticated, service_role;

-- Enable Row Level Security
ALTER TABLE public.app_versions ENABLE ROW LEVEL SECURITY;

-- Allow public read access to active app versions so mobile apps can check updates
DROP POLICY IF EXISTS "app_versions_anon_select" ON public.app_versions;
DROP POLICY IF EXISTS "Allow public read access to active app versions" ON public.app_versions;
CREATE POLICY "app_versions_anon_select"
ON public.app_versions FOR SELECT
TO anon
USING (is_active = TRUE);

-- Allow authenticated users to manage versions (matching 28_rls_policies.sql standard)
DROP POLICY IF EXISTS "app_versions_auth_all" ON public.app_versions;
DROP POLICY IF EXISTS "Allow admin full access to app versions" ON public.app_versions;
CREATE POLICY "app_versions_auth_all"
ON public.app_versions FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Seed initial version record
INSERT INTO public.app_versions (
    platform,
    version_name,
    version_code,
    min_supported_version,
    min_supported_version_code,
    release_notes,
    apk_url,
    file_size_bytes,
    file_size_mb,
    force_update,
    is_active
) VALUES (
    'android',
    '1.0.0',
    1,
    '1.0.0',
    1,
    ARRAY[
        'Polished cashier mobile POS and inventory management',
        'Enhanced order checkout and cash calculation workflows',
        'Added automated in-app update notifications'
    ],
    'https://github.com/rewithjie/Piggy-Trunk/releases/latest/download/PiggyTrunkMobile.apk',
    26822477,
    25.58,
    FALSE,
    TRUE
)
ON CONFLICT DO NOTHING;
