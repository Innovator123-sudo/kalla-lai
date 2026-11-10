-- Migration 012: Add google_maps_link column to jobs table
-- Allows hirers to attach a Google Maps directions URL to a job posting.

ALTER TABLE jobs
  ADD COLUMN IF NOT EXISTS google_maps_link TEXT;
