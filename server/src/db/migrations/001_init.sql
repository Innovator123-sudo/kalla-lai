-- Kalla-Lai core schema.
-- PostgreSQL is the system of record for all durable business state.

CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY,
  email text NOT NULL,
  password_hash text NOT NULL,
  full_name text NOT NULL,
  phone text,
  status text NOT NULL DEFAULT 'ACTIVE'
    CHECK (status IN ('ACTIVE', 'SUSPENDED', 'DELETED')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS users_email_lower_uq ON users (lower(email));

CREATE TABLE IF NOT EXISTS user_roles (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('WORKER', 'EMPLOYER', 'MODERATOR', 'BILLING_ADMIN')),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, role)
);

CREATE TABLE IF NOT EXISTS worker_profiles (
  user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  public_name text NOT NULL,
  base_area text,
  latitude double precision,
  longitude double precision,
  min_rate_npr bigint CHECK (min_rate_npr IS NULL OR min_rate_npr >= 0),
  rate_negotiable boolean NOT NULL DEFAULT true,
  availability text,
  bio text,
  verification_status text NOT NULL DEFAULT 'PENDING'
    CHECK (verification_status IN ('UNVERIFIED', 'PENDING', 'VERIFIED', 'REJECTED')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS employer_profiles (
  user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  display_name text NOT NULL,
  organization text,
  trust_status text NOT NULL DEFAULT 'UNVERIFIED'
    CHECK (trust_status IN ('UNVERIFIED', 'VERIFIED', 'SUSPENDED')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS skills (
  id serial PRIMARY KEY,
  slug text NOT NULL UNIQUE,
  name text NOT NULL
);

CREATE TABLE IF NOT EXISTS worker_skills (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  skill_id integer NOT NULL REFERENCES skills(id) ON DELETE RESTRICT,
  years_experience numeric(4,1) NOT NULL DEFAULT 0 CHECK (years_experience >= 0),
  PRIMARY KEY (user_id, skill_id)
);

CREATE TABLE IF NOT EXISTS verification_cases (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  state text NOT NULL DEFAULT 'PENDING'
    CHECK (state IN ('PENDING', 'NEEDS_REVIEW', 'VERIFIED', 'REJECTED')),
  document_type text NOT NULL,
  document_ref text,
  provider_ref text,
  decision_reason text,
  reviewed_by uuid REFERENCES users(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS verification_cases_user_idx ON verification_cases (user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS jobs (
  id uuid PRIMARY KEY,
  employer_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role text NOT NULL,
  description text NOT NULL,
  work_mode text NOT NULL DEFAULT 'ON_SITE'
    CHECK (work_mode IN ('ON_SITE', 'REMOTE', 'HYBRID')),
  address text,
  area text,
  latitude double precision,
  longitude double precision,
  dispatch_radius_km numeric(5,1) NOT NULL DEFAULT 10 CHECK (dispatch_radius_km > 0),
  compensation_type text NOT NULL DEFAULT 'HOURLY'
    CHECK (compensation_type IN ('HOURLY', 'DAILY', 'PROJECT', 'MILESTONE')),
  rate_npr bigint NOT NULL CHECK (rate_npr >= 0),
  currency text NOT NULL DEFAULT 'NPR',
  negotiable boolean NOT NULL DEFAULT true,
  required_skills text[] NOT NULL DEFAULT '{}',
  qualifications text[] NOT NULL DEFAULT '{}',
  status text NOT NULL DEFAULT 'DRAFT'
    CHECK (status IN ('DRAFT', 'PUBLISHED', 'CANCELLED', 'FILLED', 'CLOSED')),
  published_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS jobs_employer_idx ON jobs (employer_id, created_at DESC);
CREATE INDEX IF NOT EXISTS jobs_status_published_idx ON jobs (status, published_at DESC);
CREATE INDEX IF NOT EXISTS jobs_geo_idx ON jobs (latitude, longitude);

CREATE TABLE IF NOT EXISTS applications (
  id uuid PRIMARY KEY,
  job_id uuid NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
  worker_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'APPLIED'
    CHECK (status IN ('APPLIED', 'SHORTLISTED', 'ACCEPTED', 'REJECTED', 'WITHDRAWN')),
  message text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (job_id, worker_id)
);
CREATE INDEX IF NOT EXISTS applications_worker_idx ON applications (worker_id, created_at DESC);

CREATE TABLE IF NOT EXISTS offers (
  id uuid PRIMARY KEY,
  job_id uuid NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
  employer_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  worker_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rate_npr bigint NOT NULL CHECK (rate_npr >= 0),
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'CREATED'
    CHECK (status IN ('CREATED', 'ACCEPTED', 'DECLINED', 'WITHDRAWN', 'EXPIRED')),
  message text,
  responded_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (ends_at > starts_at)
);
CREATE INDEX IF NOT EXISTS offers_worker_idx ON offers (worker_id, status, created_at DESC);

CREATE TABLE IF NOT EXISTS shifts (
  id uuid PRIMARY KEY,
  job_id uuid NOT NULL REFERENCES jobs(id) ON DELETE RESTRICT,
  worker_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  employer_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  offer_id uuid REFERENCES offers(id) ON DELETE SET NULL,
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'ACCEPTED'
    CHECK (status IN ('ACCEPTED', 'CONFIRMED', 'ON_THE_WAY', 'IN_PROGRESS',
                      'COMPLETION_SUBMITTED', 'UNDER_REVIEW', 'COMPLETED',
                      'CANCELLED', 'DISPUTED', 'NO_SHOW')),
  on_my_way_at timestamptz,
  started_at timestamptz,
  completion_submitted_at timestamptz,
  completion_note text,
  approved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (ends_at > starts_at)
);
CREATE INDEX IF NOT EXISTS shifts_worker_idx ON shifts (worker_id, starts_at DESC);
CREATE INDEX IF NOT EXISTS shifts_employer_idx ON shifts (employer_id, starts_at DESC);

CREATE TABLE IF NOT EXISTS attendance_events (
  id uuid PRIMARY KEY,
  shift_id uuid NOT NULL REFERENCES shifts(id) ON DELETE CASCADE,
  worker_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('ON_MY_WAY', 'ARRIVED', 'STARTED', 'COMPLETED')),
  latitude double precision,
  longitude double precision,
  recorded_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS attendance_shift_idx ON attendance_events (shift_id, recorded_at);

CREATE TABLE IF NOT EXISTS invoices (
  id uuid PRIMARY KEY,
  shift_id uuid NOT NULL UNIQUE REFERENCES shifts(id) ON DELETE RESTRICT,
  employer_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  worker_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  hours numeric(6,2) NOT NULL CHECK (hours >= 0),
  rate_npr bigint NOT NULL CHECK (rate_npr >= 0),
  amount_npr bigint NOT NULL CHECK (amount_npr >= 0),
  currency text NOT NULL DEFAULT 'NPR',
  status text NOT NULL DEFAULT 'AWAITING_EMPLOYER_REVIEW'
    CHECK (status IN ('AWAITING_EMPLOYER_REVIEW', 'REMINDER_SENT', 'ESCALATED',
                      'DISPUTED', 'SETTLEMENT_PROCESSING', 'PAID', 'REFUNDED',
                      'FAILED', 'ON_HOLD', 'FLAGGED_UNPAID')),
  issued_at timestamptz NOT NULL DEFAULT now(),
  review_due_at timestamptz NOT NULL,
  reminder_sent_at timestamptz,
  escalated_at timestamptz,
  paid_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS invoices_employer_idx ON invoices (employer_id, status);
CREATE INDEX IF NOT EXISTS invoices_worker_idx ON invoices (worker_id, status);

CREATE TABLE IF NOT EXISTS payment_transactions (
  id uuid PRIMARY KEY,
  invoice_id uuid NOT NULL REFERENCES invoices(id) ON DELETE RESTRICT,
  provider text NOT NULL DEFAULT 'DEMO',
  provider_ref text,
  provider_event_id text UNIQUE,
  amount_npr bigint NOT NULL,
  currency text NOT NULL DEFAULT 'NPR',
  status text NOT NULL CHECK (status IN ('REQUIRES_FUNDING', 'FUNDED', 'PROCESSING', 'SETTLED', 'FAILED', 'REFUNDED')),
  idempotency_key text UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS payment_transactions_invoice_idx ON payment_transactions (invoice_id);

CREATE TABLE IF NOT EXISTS ledger_entries (
  id uuid PRIMARY KEY,
  invoice_id uuid NOT NULL REFERENCES invoices(id) ON DELETE RESTRICT,
  entry_type text NOT NULL CHECK (entry_type IN ('HOLD', 'RELEASE', 'REFUND', 'ADJUSTMENT')),
  amount_npr bigint NOT NULL,
  currency text NOT NULL DEFAULT 'NPR',
  description text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ledger_invoice_idx ON ledger_entries (invoice_id, created_at);

CREATE TABLE IF NOT EXISTS disputes (
  id uuid PRIMARY KEY,
  invoice_id uuid NOT NULL REFERENCES invoices(id) ON DELETE RESTRICT,
  raised_by uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  reason text NOT NULL,
  evidence_ref text,
  status text NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'UNDER_REVIEW', 'RESOLVED', 'REJECTED')),
  resolution text,
  resolved_by uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);
CREATE INDEX IF NOT EXISTS disputes_invoice_idx ON disputes (invoice_id, created_at DESC);

CREATE TABLE IF NOT EXISTS messages (
  id uuid PRIMARY KEY,
  shift_id uuid NOT NULL REFERENCES shifts(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 4000),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS messages_shift_idx ON messages (shift_id, created_at);

CREATE TABLE IF NOT EXISTS reviews (
  id uuid PRIMARY KEY,
  shift_id uuid NOT NULL REFERENCES shifts(id) ON DELETE CASCADE,
  author_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  recipient_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rating smallint NOT NULL CHECK (rating BETWEEN 1 AND 5),
  text text,
  created_at timestamptz NOT NULL DEFAULT now(),
  revealed_at timestamptz,
  UNIQUE (shift_id, author_id),
  CHECK (author_id <> recipient_id)
);
CREATE INDEX IF NOT EXISTS reviews_recipient_idx ON reviews (recipient_id, revealed_at);

CREATE TABLE IF NOT EXISTS notifications (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type text NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  resource_type text,
  resource_id uuid,
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS notifications_user_idx ON notifications (user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS audit_events (
  id uuid PRIMARY KEY,
  actor_id uuid REFERENCES users(id) ON DELETE SET NULL,
  action text NOT NULL,
  resource_type text NOT NULL,
  resource_id text,
  outcome text NOT NULL DEFAULT 'SUCCESS',
  correlation_id text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS audit_created_idx ON audit_events (created_at DESC);
CREATE INDEX IF NOT EXISTS audit_actor_idx ON audit_events (actor_id, created_at DESC);

CREATE TABLE IF NOT EXISTS sessions (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  refresh_token_hash text NOT NULL,
  user_agent text,
  ip text,
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sessions_user_idx ON sessions (user_id, revoked_at);
CREATE UNIQUE INDEX IF NOT EXISTS sessions_token_uq ON sessions (refresh_token_hash);

CREATE TABLE IF NOT EXISTS idempotency_keys (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  key text NOT NULL,
  endpoint text NOT NULL,
  request_hash text NOT NULL,
  response_status integer,
  response_body jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, key, endpoint)
);

CREATE TABLE IF NOT EXISTS provider_events (
  id uuid PRIMARY KEY,
  provider text NOT NULL,
  provider_event_id text NOT NULL,
  event_type text NOT NULL,
  payload jsonb NOT NULL,
  processed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (provider, provider_event_id)
);
