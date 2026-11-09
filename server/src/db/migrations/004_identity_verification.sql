ALTER TABLE users
  ADD COLUMN IF NOT EXISTS identity_status text NOT NULL DEFAULT 'NOT_STARTED'
    CHECK (identity_status IN ('NOT_STARTED', 'PENDING', 'NEEDS_ACTION', 'VERIFIED', 'REJECTED')),
  ADD COLUMN IF NOT EXISTS onboarding_complete boolean NOT NULL DEFAULT false;

ALTER TABLE worker_profiles
  ADD COLUMN IF NOT EXISTS education text,
  ADD COLUMN IF NOT EXISTS skills_summary text;

ALTER TABLE employer_profiles
  ADD COLUMN IF NOT EXISTS worksite_area text,
  ADD COLUMN IF NOT EXISTS hiring_summary text;

CREATE TABLE IF NOT EXISTS identity_verifications (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider text NOT NULL CHECK (provider IN ('VERIFF')),
  provider_session_id text NOT NULL UNIQUE,
  state text NOT NULL DEFAULT 'PENDING'
    CHECK (state IN ('PENDING', 'NEEDS_ACTION', 'VERIFIED', 'REJECTED')),
  consent_version text NOT NULL,
  consented_at timestamptz NOT NULL,
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS identity_verifications_user_idx
  ON identity_verifications (user_id, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS identity_verifications_one_pending_uq
  ON identity_verifications (user_id) WHERE state = 'PENDING';
