-- Optional PostGIS acceleration. The application works with plain lat/lng
-- (haversine SQL) and upgrades to PostGIS when the extension is available.
DO $$
BEGIN
  BEGIN
    CREATE EXTENSION IF NOT EXISTS postgis;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'PostGIS unavailable; continuing with lat/lng columns only';
  END;

  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'postgis') THEN
    ALTER TABLE jobs ADD COLUMN IF NOT EXISTS location geography(Point, 4326);
    UPDATE jobs
       SET location = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
     WHERE location IS NULL AND latitude IS NOT NULL AND longitude IS NOT NULL;
    CREATE INDEX IF NOT EXISTS jobs_location_gix ON jobs USING gist (location);
  END IF;
END
$$;
