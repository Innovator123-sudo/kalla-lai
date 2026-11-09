-- Interview booking between a worker and an employer about a published job.
CREATE TABLE IF NOT EXISTS interviews (
  id uuid PRIMARY KEY,
  job_id uuid NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
  worker_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  employer_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  proposed_by uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  scheduled_at timestamptz NOT NULL,
  duration_minutes integer NOT NULL DEFAULT 30 CHECK (duration_minutes BETWEEN 10 AND 180),
  mode text NOT NULL DEFAULT 'ON_SITE' CHECK (mode IN ('ON_SITE', 'PHONE', 'VIDEO')),
  location_note text,
  message text,
  status text NOT NULL DEFAULT 'PROPOSED'
    CHECK (status IN ('PROPOSED', 'CONFIRMED', 'DECLINED', 'CANCELLED', 'COMPLETED')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS interviews_worker_idx ON interviews (worker_id, scheduled_at DESC);
CREATE INDEX IF NOT EXISTS interviews_employer_idx ON interviews (employer_id, scheduled_at DESC);
CREATE INDEX IF NOT EXISTS interviews_job_idx ON interviews (job_id);