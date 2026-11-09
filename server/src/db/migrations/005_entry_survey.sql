-- First-run survey answers. One row per user, no identity or contact data.
CREATE TABLE IF NOT EXISTS entry_surveys (
  user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  intent text NOT NULL CHECK (intent IN ('WORKER', 'EMPLOYER')),
  acquisition_source text NOT NULL CHECK (acquisition_source IN (
    'FRIEND_FAMILY', 'FACEBOOK_TIKTOK', 'GOOGLE_SEARCH', 'JOB_BOARD', 'COMMUNITY_EVENT', 'OTHER'
  )),
  timeline text NOT NULL CHECK (timeline IN ('THIS_WEEK', 'THIS_MONTH', 'EXPLORING')),
  experience text NOT NULL CHECK (experience IN ('NEW', 'SOME', 'EXPERIENCED')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
