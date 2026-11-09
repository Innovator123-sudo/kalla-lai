-- Richer employer job posts: job category, contact phone, working hours,
-- employment type, number of openings, and salary-growth details.
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS category text;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS contact_phone text;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS working_hours text;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS employment_type text NOT NULL DEFAULT 'FULL_TIME'
  CHECK (employment_type IN ('FULL_TIME', 'PART_TIME', 'CONTRACT', 'TEMPORARY', 'INTERNSHIP'));
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS openings integer NOT NULL DEFAULT 1
  CHECK (openings >= 1 AND openings <= 1000);
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS salary_increment boolean NOT NULL DEFAULT false;
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS increment_note text;