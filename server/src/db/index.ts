import { mkdirSync } from 'node:fs';
import path from 'node:path';
import { Pool } from 'pg';
import type { QueryResultRow } from 'pg';
import { config, supabase } from '../config.js';

export interface Db {
  query<T extends QueryResultRow = QueryResultRow>(
    sql: string,
    params?: unknown[],
  ): Promise<{ rows: T[] }>;
  exec(sql: string): Promise<void>;
}

let pool: Pool | null = null;
let pglite: {
  query: (sql: string, params?: unknown[]) => Promise<{ rows: unknown[] }>;
  exec: (sql: string) => Promise<unknown>;
  close: () => Promise<void>;
} | null = null;

let transactionQueue: Promise<unknown> = Promise.resolve();
let activeBackend: 'SUPABASE' | 'POSTGRES' | 'PGLOCAL' = 'PGLOCAL';

/** Which store this process is actually using; surfaced by /v1/app/config. */
export function databaseBackend(): 'SUPABASE' | 'POSTGRES' | 'PGLOCAL' {
  return activeBackend;
}

export async function initDb(): Promise<void> {
  if (pool || pglite) return;

  // A resolved Supabase connection string wins: it is the authoritative store
  // for every table, including the worker/employer sheets admins configure.
  const databaseUrl = supabase.dbUrl ?? config.DATABASE_URL;
  if (databaseUrl) {
    const isSupabase = Boolean(supabase.dbUrl) || /supabase\./i.test(databaseUrl);
    activeBackend = isSupabase ? 'SUPABASE' : 'POSTGRES';
    pool = new Pool({
      connectionString: databaseUrl,
      max: 10,
      idleTimeoutMillis: 30_000,
      connectionTimeoutMillis: 12_000,
      keepAlive: true,
      // Cancel runaway queries and forgotten transactions (blueprint §12.3).
      statement_timeout: 15_000,
      idle_in_transaction_session_timeout: 30_000,
      // Supabase Postgres always requires TLS; local dev keeps it optional.
      ssl: isSupabase || config.NODE_ENV === 'production' ? { rejectUnauthorized: false } : undefined,
    });
    pool.on('error', (err) => {
      // eslint-disable-next-line no-console
      console.error(JSON.stringify({ level: 'error', msg: 'postgres pool error', err: err.message }));
    });
    return;
  }

  // Local / test mode without Docker: run a real PostgreSQL engine compiled to
  // WebAssembly (PGlite). Production always uses DATABASE_URL -> PostgreSQL.
  if (config.PGLITE_PATH !== 'memory://') {
    mkdirSync(path.dirname(config.PGLITE_PATH), { recursive: true });
  }
  const { PGlite } = await import('@electric-sql/pglite');
  const client = new PGlite(config.PGLITE_PATH);
  await client.waitReady;
  pglite = client as unknown as NonNullable<typeof pglite>;
}

const pgDb: Db = {
  async query<T extends QueryResultRow>(sql: string, params?: unknown[]) {
    if (!pool) throw new Error('Database not initialised');
    const result = await pool.query<T>(sql, params as never[]);
    return { rows: result.rows };
  },
  async exec(sql: string) {
    if (!pool) throw new Error('Database not initialised');
    await pool.query(sql);
  },
};

const wasmDb: Db = {
  async query<T extends QueryResultRow>(sql: string, params?: unknown[]) {
    if (!pglite) throw new Error('Database not initialised');
    const result = await pglite.query(sql, params);
    return { rows: result.rows as T[] };
  },
  async exec(sql: string) {
    if (!pglite) throw new Error('Database not initialised');
    await pglite.exec(sql);
  },
};

export function db(): Db {
  if (pool) return pgDb;
  if (pglite) return wasmDb;
  throw new Error('Database not initialised');
}

export async function withTransaction<T>(fn: (tx: Db) => Promise<T>): Promise<T> {
  if (!pool) {
    // PGlite runs in-process with a single connection; serialise transactions
    // so concurrent requests cannot interleave BEGIN/COMMIT.
    const run = transactionQueue.then(async () => {
      const tx = db();
      await tx.exec('BEGIN');
      try {
        const result = await fn(tx);
        await tx.exec('COMMIT');
        return result;
      } catch (error) {
        await tx.exec('ROLLBACK');
        throw error;
      }
    });
    transactionQueue = run.catch(() => undefined);
    return run as Promise<T>;
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const tx: Db = {
      async query(sql, params) {
        const result = await client.query(sql, params as never[]);
        return { rows: result.rows };
      },
      async exec(sql) {
        await client.query(sql);
      },
    };
    const result = await fn(tx);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function closeDb(): Promise<void> {
  if (pool) {
    await pool.end();
    pool = null;
  }
  if (pglite) {
    await pglite.close();
    pglite = null;
  }
}

export async function pingDb(): Promise<boolean> {
  try {
    await db().query('SELECT 1');
    return true;
  } catch {
    return false;
  }
}
