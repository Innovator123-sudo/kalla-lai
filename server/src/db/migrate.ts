import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { closeDb, db, initDb, withTransaction } from './index.js';

function migrationsDir(): string {
  const candidates = [
    fileURLToPath(new URL('./migrations', import.meta.url)),
    path.resolve(process.cwd(), 'src/db/migrations'),
  ];
  const found = candidates.find((candidate) => existsSync(candidate));
  if (!found) throw new Error('Migration directory not found');
  return found;
}

export async function migrate(): Promise<number> {
  const directory = migrationsDir();
  const files = readdirSync(directory)
    .filter((file) => file.endsWith('.sql'))
    .sort();

  await db().exec(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      name text PRIMARY KEY,
      applied_at timestamptz NOT NULL DEFAULT now()
    );
  `);
  const applied = await db().query<{ name: string }>('SELECT name FROM schema_migrations');
  const done = new Set(applied.rows.map((row) => row.name));

  let count = 0;
  for (const file of files) {
    if (done.has(file)) continue;
    const sql = readFileSync(path.join(directory, file), 'utf8');
    await withTransaction(async (tx) => {
      await tx.exec(sql);
      await tx.query('INSERT INTO schema_migrations (name) VALUES ($1)', [file]);
    });
    count += 1;
    // eslint-disable-next-line no-console
    console.log(`[migrate] applied ${file}`);
  }
  return count;
}

const isEntrypoint = process.argv[1] && /migrate\.(ts|js)$/.test(process.argv[1]);
if (isEntrypoint) {
  initDb()
    .then(async () => {
      const applied = await migrate();
      // eslint-disable-next-line no-console
      console.log(`[migrate] complete (${applied} new migration${applied === 1 ? '' : 's'})`);
      await closeDb();
    })
    .catch(async (error) => {
      // eslint-disable-next-line no-console
      console.error('[migrate] failed:', error);
      await closeDb().catch(() => undefined);
      process.exit(1);
    });
}
