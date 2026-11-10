import { readFile, readdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';

/**
 * Opt-in migration hook for hosted builds.
 *
 * The Vercel function has the production database URL only at runtime, and
 * `vercel env pull` redacts sensitive values. Setting RUN_DB_MIGRATIONS=1 for a
 * deployment lets this script apply pending SQL migrations during `npm install`
 * in the build environment, where the deployment's environment variables are
 * available.
 *
 * Local installs and normal deploys are no-ops: without the flag the script
 * exits before touching a database.
 */
if (process.env.RUN_DB_MIGRATIONS !== '1') {
  process.exit(0);
}

const databaseUrl = process.env.SUPABASE_DB_URL || process.env.DATABASE_URL;
if (!databaseUrl) {
  console.error('[migrate] RUN_DB_MIGRATIONS=1 but no database URL is configured.');
  process.exit(1);
}

const root = path.resolve(fileURLToPath(new URL('..', import.meta.url)));
const directory = path.join(root, 'src', 'db', 'migrations');
const files = (await readdir(directory)).filter((file) => file.endsWith('.sql')).sort();

const client = new pg.Client({
  connectionString: databaseUrl,
  ssl: { rejectUnauthorized: false },
});

await client.connect();
try {
  await client.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      name text PRIMARY KEY,
      applied_at timestamptz NOT NULL DEFAULT now()
    );
  `);
  const applied = await client.query('SELECT name FROM schema_migrations');
  const done = new Set(applied.rows.map((row) => row.name));
  let count = 0;
  for (const file of files) {
    if (done.has(file)) continue;
    const sql = await readFile(path.join(directory, file), 'utf8');
    await client.query('BEGIN');
    try {
      await client.query(sql);
      await client.query('INSERT INTO schema_migrations (name) VALUES ($1)', [file]);
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    }
    count += 1;
    console.log(`[migrate] applied ${file}`);
  }
  console.log(`[migrate] complete (${count} new migration${count === 1 ? '' : 's'})`);
} finally {
  await client.end();
}
