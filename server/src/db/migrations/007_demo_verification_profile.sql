-- In-app demo document verification + richer (Fiverr-style) worker profiles.

-- Allow the local demo verification provider alongside Veriff. Production
-- still uses Veriff; the DEMO provider is only reachable when DEMO_MODE is on.
ALTER TABLE identity_verifications
  DROP CONSTRAINT IF EXISTS identity_verifications_provider_check;
ALTER TABLE identity_verifications
  ADD CONSTRAINT identity_verifications_provider_check
  CHECK (provider IN ('VERIFF', 'DEMO'));
ALTER TABLE identity_verifications
  ADD COLUMN IF NOT EXISTS document_type text,
  ADD COLUMN IF NOT EXISTS detail jsonb NOT NULL DEFAULT '{}'::jsonb;

-- Richer worker profile fields.
ALTER TABLE worker_profiles
  ADD COLUMN IF NOT EXISTS tagline text,
  ADD COLUMN IF NOT EXISTS languages text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS categories text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS promo_video_url text,
  ADD COLUMN IF NOT EXISTS cv_url text,
  ADD COLUMN IF NOT EXISTS portfolio_urls text[] NOT NULL DEFAULT '{}';

-- Demo file uploads (promo video, CV, profile images). Only the decision and
-- opaque file references are stored for identity checks; these uploads are
-- user-owned showcase media, not biometric evidence.
CREATE TABLE IF NOT EXISTS uploads (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN ('PROMO_VIDEO', 'CV', 'IMAGE')),
  mime_type text NOT NULL,
  size_bytes bigint NOT NULL CHECK (size_bytes >= 0),
  original_name text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS uploads_user_idx ON uploads (user_id, created_at DESC);