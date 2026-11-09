import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { randomBytes, randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import bcrypt from 'bcryptjs';
import { config, supabase } from '../src/config.js';
import { closeDb, db, initDb, withTransaction } from '../src/db/index.js';
import { migrate } from '../src/db/migrate.js';
import { probeSupabaseDataApi } from '../src/lib/supabase.js';

/**
 * Configures Supabase as the Kalla-Lai backend:
 *   1. verifies the publishable key against the Data API,
 *   2. applies the core schema migrations to Supabase Postgres,
 *   3. applies the RLS + admin profile policies,
 *   4. ensures one platform admin account exists so the console is reachable.
 *
 *   npm run supabase:check   -> step 1 only (no database writes)
 *   npm run supabase:setup   -> all steps
 *
 * Run from the `server/` directory. Never run this against a project that
 * already holds different production data without reviewing the migrations.
 */

const checkOnly = process.argv.includes('--check');

function line(text = '') {
  // eslint-disable-next-line no-console
  console.log(text);
}

function supabaseMigrationsDir(): string {
  const candidates = [
    fileURLToPath(new URL('../../supabase/migrations', import.meta.url)),
    path.resolve(process.cwd(), '../supabase/migrations'),
  ];
  const found = candidates.find((candidate) => existsSync(candidate));
  if (!found) throw new Error('supabase/migrations directory not found');
  return found;
}

async function applySupabaseMigrations(): Promise<number> {
  const directory = supabaseMigrationsDir();
  const files = readdirSync(directory).filter((file) => file.endsWith('.sql')).sort();
  await db().exec(`
    CREATE TABLE IF NOT EXISTS supabase_migrations (
      name text PRIMARY KEY,
      applied_at timestamptz NOT NULL DEFAULT now()
    );
  `);
  const applied = await db().query<{ name: string }>('SELECT name FROM supabase_migrations');
  const done = new Set(applied.rows.map((row) => row.name));

  let count = 0;
  for (const file of files) {
    if (done.has(file)) continue;
    const sql = readFileSync(path.join(directory, file), 'utf8');
    await withTransaction(async (tx) => {
      await tx.exec(sql);
      await tx.query('INSERT INTO supabase_migrations (name) VALUES ($1)', [file]);
    });
    line(`  applied ${file}`);
    count += 1;
  }
  return count;
}

const DEFAULT_ADMIN_EMAIL = 'admin@kallalai.app';

interface AdminResult {
  email: string;
  signInId: string;
  password: string | null;
  created: boolean;
  renamed: boolean;
  rotated: boolean;
}

/**
 * Creates or updates exactly ONE platform admin. If SUPABASE_ADMIN_EMAIL
 * changes, the previously bootstrapped admin is renamed rather than leaving a
 * stale generated account behind. When SUPABASE_ADMIN_PASSWORD is set it is
 * applied on every run, so re-running setup is a credential rotation.
 */
async function ensureAdmin(): Promise<AdminResult> {
  const configuredEmail = config.SUPABASE_ADMIN_EMAIL?.trim().toLowerCase();
  const configuredPassword = config.SUPABASE_ADMIN_PASSWORD;
  const email = configuredEmail ?? DEFAULT_ADMIN_EMAIL;
  const signInId = email.split('@')[0];

  let existing = await db().query<{ id: string }>(
    'SELECT id FROM users WHERE lower(email) = $1',
    [email],
  );
  let renamed = false;

  if (!existing.rows[0] && configuredEmail && configuredEmail !== DEFAULT_ADMIN_EMAIL) {
    const previous = await db().query<{ id: string }>(
      `SELECT u.id FROM users u
         JOIN user_roles r ON r.user_id = u.id AND r.role = 'ADMIN'
        WHERE lower(u.email) = $1 LIMIT 1`,
      [DEFAULT_ADMIN_EMAIL],
    );
    if (previous.rows[0]) {
      await db().query(
        `UPDATE users SET email = $1, full_name = $2, updated_at = now() WHERE id = $3`,
        [email, signInId, previous.rows[0].id],
      );
      existing = await db().query<{ id: string }>(
        'SELECT id FROM users WHERE lower(email) = $1',
        [email],
      );
      renamed = true;
    }
  }

  let id: string;
  let created = false;
  let rotated = false;
  let password: string | null = null;

  if (existing.rows[0]) {
    id = existing.rows[0].id;
    if (configuredPassword) {
      const hash = await bcrypt.hash(configuredPassword, 12);
      await db().query(
        `UPDATE users SET password_hash = $1, status = 'ACTIVE', updated_at = now() WHERE id = $2`,
        [hash, id],
      );
      rotated = true;
    }
    if (renamed || rotated) {
      await db().query(
        `UPDATE sessions SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL`,
        [id],
      );
    }
  } else {
    password = configuredPassword ?? randomBytes(15).toString('base64url');
    const passwordHash = await bcrypt.hash(password, 12);
    id = randomUUID();
    await withTransaction(async (tx) => {
      await tx.query(
        `INSERT INTO users (id, email, password_hash, full_name, status, identity_status, onboarding_complete)
         VALUES ($1, $2, $3, $4, 'ACTIVE', 'NOT_STARTED', true)`,
        [id, email, passwordHash, signInId],
      );
      await tx.query(
        `INSERT INTO user_roles (user_id, role) VALUES ($1, 'ADMIN') ON CONFLICT DO NOTHING`,
        [id],
      );
    });
    created = true;
  }

  await db().query(
    `INSERT INTO user_roles (user_id, role) VALUES ($1, 'ADMIN') ON CONFLICT DO NOTHING`,
    [id],
  );

  return { email, signInId, password: created ? password : null, created, renamed, rotated };
}

async function main() {
  line('Kalla-Lai · Supabase backend setup');
  line('------------------------------------------------------------');
  line(`Project URL      : ${supabase.url ?? '(not set)'}`);
  line(`Project ref      : ${supabase.projectRef ?? '(not set)'}`);
  line(`Publishable key  : ${supabase.publishableKey ? `${supabase.publishableKey.slice(0, 18)}…` : '(not set)'}`);
  line(`Secret key       : ${supabase.secretKey ? 'configured (server-only)' : 'not set (optional)'}`);
  line(`Postgres URL     : ${supabase.dbUrl ? 'configured' : '(not set)'}`);
  if (supabase.warning) {
    line(`Config issue     : ${supabase.warning}`);
  }
  if (supabase.dbUrl) {
    // Show the host only; never echo the password.
    try {
      line(`Database host    : ${new URL(supabase.dbUrl).hostname}`);
    } catch {
      // A malformed URL will fail loudly when initDb() connects.
    }
  }
  line('');

  // Step 1: public Data API reachability.
  if (supabase.dataApiConfigured) {
    const probe = await probeSupabaseDataApi(true);
    line(`Data API         : ${probe.reachable ? 'OK' : 'FAILED'} (HTTP ${probe.statusCode ?? 'n/a'})`);
    line(`  ${probe.message}`);
  } else {
    line('Data API         : SKIPPED');
    line('  Set SUPABASE_PROJECT_REF (20-char project id) or SUPABASE_URL in server/.env.');
    line('  The publishable key is already configured; Supabase does not encode the');
    line('  project URL inside it, so it must be supplied separately.');
  }

  if (checkOnly) {
    line('');
    line('Check-only mode: no database changes made.');
    return;
  }

  if (!supabase.dbUrl) {
    line('');
    line('Nothing else to do. In server/.env either:');
    line('  a) paste the full connection string from Dashboard -> Connect as');
    line('     SUPABASE_DB_URL, or');
    line('  b) keep SUPABASE_DB_PASSWORD and fill in SUPABASE_PROJECT_REF plus');
    line('     SUPABASE_DB_HOST (the pooler host), and the API builds the URL.');
    line('Then run `npm run supabase:setup` again.');
    return;
  }

  // Step 2: core schema (same migrations used by the local engine).
  line('');
  line('Applying core schema migrations to Supabase Postgres…');
  await initDb();
  const core = await migrate();
  line(`  ${core} new migration(s) applied.`);

  // Step 3: RLS + staff profile policies.
  line('Applying Supabase RLS / admin profile policies…');
  const policies = await applySupabaseMigrations();
  line(`  ${policies} new policy migration(s) applied.`);

  // Step 4: one usable admin account.
  const admin = await ensureAdmin();
  line('');
  line('Admin account');
  line(`  sign-in ID : ${admin.signInId}`);
  line(`  email      : ${admin.email}`);
  if (admin.created && admin.password) {
    line(`  password   : ${admin.password}`);
    line('  IMPORTANT: save this password now; it is shown only once.');
  } else if (config.SUPABASE_ADMIN_PASSWORD) {
    line('  password   : set from SUPABASE_ADMIN_PASSWORD in server/.env');
  } else {
    line('  password   : unchanged (set SUPABASE_ADMIN_PASSWORD to rotate it)');
  }
  if (admin.renamed) line('  renamed the previously bootstrapped admin; old sessions revoked.');
  else if (admin.rotated) line('  password applied; old sessions revoked.');
  else if (!admin.created) line('  existing account kept; ADMIN role ensured.');

  line('');
  line('Done. Double-click start-local.bat (or use the already-running stack),');
  line('then open the admin console from the account menu of a staff session.');
  line('GET /v1/supabase/status reports the live connection state.');
}

main()
  .then(() => closeDb())
  .catch(async (error) => {
    // eslint-disable-next-line no-console
    console.error('\n[supabase:setup] failed:', error);
    await closeDb().catch(() => undefined);
    process.exit(1);
  });
