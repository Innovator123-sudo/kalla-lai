import 'dotenv/config';
import { z } from 'zod';

const bool = (def: boolean) =>
  z
    .string()
    .optional()
    .transform((v) => (v === undefined ? def : v === 'true' || v === '1'));

/** Treat an unfilled `.env` value (`FOO=`) as unset. */
const blankAsUndefined = (value: unknown) => (value === '' ? undefined : value);

const optionalString = z.preprocess(blankAsUndefined, z.string().optional());

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(8080),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace']).default('info'),
  // An empty DATABASE_URL must not shadow SUPABASE_DB_URL (see db/index.ts).
  DATABASE_URL: optionalString,
  FIREBASE_PROJECT_ID: z.string().optional(),
  VERIFF_BASE_URL: z.string().url().optional(),
  VERIFF_API_KEY: z.string().optional(),
  VERIFF_SHARED_SECRET: z.string().optional(),
  PGLITE_PATH: z.string().default('./.data/pglite'),
  AUTO_MIGRATE: bool(true),
  JWT_ACCESS_SECRET: z.string().min(16).default('dev-only-access-secret-change-me'),
  JWT_ACCESS_TTL_SECONDS: z.coerce.number().int().positive().default(900),
  REFRESH_TTL_DAYS: z.coerce.number().int().positive().default(30),
  CORS_ORIGINS: z
    .string()
    .default(
      'http://127.0.0.1:7357,http://localhost:7357,http://127.0.0.1:7358,http://localhost:7358,http://localhost:5173',
    ),

  // --- Supabase -----------------------------------------------------------
  // SUPABASE_DB_URL makes Supabase Postgres the system of record. The
  // publishable key is client-safe; the secret key never leaves this server.
  SUPABASE_URL: z.preprocess(blankAsUndefined, z.string().url().optional()),
  SUPABASE_PROJECT_REF: z.preprocess(
    blankAsUndefined,
    z
      .string()
      .regex(/^[a-z0-9]{20}$/, 'SUPABASE_PROJECT_REF must be the 20-character project id')
      .optional(),
  ),
  SUPABASE_PUBLISHABLE_KEY: z.preprocess(
    blankAsUndefined,
    z
      .string()
      .refine(
        (key) => key.startsWith('sb_publishable_') || key.startsWith('eyJ'),
        'SUPABASE_PUBLISHABLE_KEY must be an sb_publishable_... key (or a legacy anon JWT)',
      )
      .optional(),
  ),
  SUPABASE_SECRET_KEY: z.preprocess(blankAsUndefined, z.string().optional()),
  // Either paste the full connection string, or give the parts and let the API
  // assemble it (the password is percent-encoded automatically, so characters
  // like # or @ cannot break the URL).
  SUPABASE_DB_URL: z.preprocess(blankAsUndefined, z.string().optional()),
  SUPABASE_DB_PASSWORD: optionalString,
  SUPABASE_DB_USER: optionalString,
  SUPABASE_DB_HOST: optionalString,
  SUPABASE_DB_PORT: z.preprocess(
    blankAsUndefined,
    z.coerce.number().int().min(1).max(65535).optional(),
  ),
  SUPABASE_DB_NAME: optionalString,
  SUPABASE_ADMIN_EMAIL: z.preprocess(blankAsUndefined, z.string().email().optional()),
  SUPABASE_ADMIN_PASSWORD: z.preprocess(blankAsUndefined, z.string().min(8).optional()),

  REDIS_URL: z.string().optional(),
  PAYMENT_WEBHOOK_SECRET: z.string().default('dev-only-webhook-secret'),
  METRICS_TOKEN: z.string().optional(),
  TRUST_PROXY: bool(false),
  DEMO_MODE: bool(process.env.NODE_ENV !== 'production'),
  MIN_APP_VERSION: z
    .string()
    .regex(/^\d+\.\d+\.\d+$/, 'MIN_APP_VERSION must look like 1.4.2')
    .optional(),
  MAINTENANCE_MODE: bool(false),
});

export type Config = z.infer<typeof schema>;

export const config: Config = (() => {
  const parsed = schema.safeParse(process.env);
  if (!parsed.success) {
    // Fail fast with a readable message; never log secret values.
    const issues = parsed.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`).join('; ');
    throw new Error(`Invalid environment configuration: ${issues}`);
  }
  if (parsed.data.NODE_ENV === 'production') {
    if (parsed.data.JWT_ACCESS_SECRET === 'dev-only-access-secret-change-me') {
      throw new Error('JWT_ACCESS_SECRET must be set in production');
    }
    if (parsed.data.PAYMENT_WEBHOOK_SECRET === 'dev-only-webhook-secret') {
      throw new Error('PAYMENT_WEBHOOK_SECRET must be set in production');
    }
    if (parsed.data.DEMO_MODE) {
      throw new Error('DEMO_MODE must be false (or unset) in production — set DEMO_MODE=false in your environment');
    }
    if (!parsed.data.FIREBASE_PROJECT_ID) {
      throw new Error('FIREBASE_PROJECT_ID must be set in production');
    }
    // Veriff is optional. Hosts that only run the marketplace (or verify
    // identities elsewhere) can leave it unset; partially configured
    // credentials are almost always a mistake, so reject those.
    const veriffValues = [
      parsed.data.VERIFF_BASE_URL,
      parsed.data.VERIFF_API_KEY,
      parsed.data.VERIFF_SHARED_SECRET,
    ];
    if (veriffValues.some(Boolean) && !veriffValues.every(Boolean)) {
      throw new Error(
        'Set VERIFF_BASE_URL, VERIFF_API_KEY and VERIFF_SHARED_SECRET together, or leave all of them unset',
      );
    }
  }
  return parsed.data;
})();

/**
 * Resolved Supabase settings. A single SUPABASE_PROJECT_REF is enough to derive
 * the public API URL; the connection string is what actually switches the API
 * over to Supabase Postgres.
 */
function projectRefFromUrl(url: string | undefined): string | null {
  if (!url) return null;
  try {
    const host = new URL(url).hostname;
    const first = host.split('.')[0];
    return first && !first.includes(':') ? first : null;
  } catch {
    return null;
  }
}

/** Placeholders left over from a copy-pasted dashboard template. */
const DB_TEMPLATE =
  /PROJECT_REF|POOLER_HOST|YOUR[-_]?PASSWORD|\[[^\]]+\]|<[^>]+>/i;

/**
 * Percent-encodes the password segment of a raw connection string. A `#` in a
 * password would otherwise be parsed as a URL fragment and silently truncate
 * the host, producing a confusing "getaddrinfo ENOTFOUND" style failure.
 */
export function encodeDbPassword(raw: string): string {
  const match = /^([a-z][a-z0-9+.-]*:\/\/[^:@/]+:)([^@]*)(@.*)$/i.exec(raw);
  if (!match) return raw;
  const [, prefix, password, suffix] = match;
  let decoded = password;
  try {
    decoded = decodeURIComponent(password);
  } catch {
    // Already malformed; encode what we have.
  }
  return `${prefix}${encodeURIComponent(decoded)}${suffix}`;
}

export interface SupabaseDbParts {
  password?: string;
  user?: string;
  host?: string;
  port?: number;
  name?: string;
  projectRef?: string | null;
}

/** Builds a valid pooler/direct URL from parts, percent-encoding the password. */
export function assembleDbUrl(parts: SupabaseDbParts): string | null {
  const { password, host, projectRef } = parts;
  if (!password || (!host && !projectRef)) return null;
  const user = parts.user ?? (projectRef ? `postgres.${projectRef}` : 'postgres');
  const hostname = host ?? `db.${projectRef}.supabase.co`;
  const port = parts.port ?? (hostname.includes('pooler') ? 6543 : 5432);
  const database = parts.name ?? 'postgres';
  return `postgresql://${user}:${encodeURIComponent(password)}@${hostname}:${port}/${database}`;
}

function resolveDbUrl(): { url: string | null; warning: string | null } {
  const raw = config.SUPABASE_DB_URL?.trim();
  if (raw && !DB_TEMPLATE.test(raw)) {
    return { url: encodeDbPassword(raw), warning: null };
  }
  const templateWarning = raw
    ? 'SUPABASE_DB_URL still contains template placeholders (PROJECT_REF / POOLER_HOST). ' +
      'Replace them with the real values, or set SUPABASE_PROJECT_REF + SUPABASE_DB_HOST and let the API build the URL.'
    : null;

  const assembled = assembleDbUrl({
    password: config.SUPABASE_DB_PASSWORD,
    user: config.SUPABASE_DB_USER,
    host: config.SUPABASE_DB_HOST,
    port: config.SUPABASE_DB_PORT,
    name: config.SUPABASE_DB_NAME,
    projectRef:
      config.SUPABASE_PROJECT_REF ?? projectRefFromUrl(config.SUPABASE_URL),
  });
  return { url: assembled, warning: assembled ? null : templateWarning };
}

/**
 * Defense in depth: an automated test run must never reach a live Supabase
 * project, because the fixture seeder writes demo rows. test/setup.ts clears
 * the env vars; this guard also covers any runner that skips that file.
 */
const runningUnderTest =
  process.env.VITEST === 'true' || process.env.NODE_ENV === 'test';

const resolvedDb = runningUnderTest
  ? { url: null as string | null, warning: null as string | null }
  : resolveDbUrl();

export const supabase = {
  url: runningUnderTest
    ? null
    : config.SUPABASE_URL ??
      (config.SUPABASE_PROJECT_REF ? `https://${config.SUPABASE_PROJECT_REF}.supabase.co` : null),
  projectRef: config.SUPABASE_PROJECT_REF ?? projectRefFromUrl(config.SUPABASE_URL),
  publishableKey: config.SUPABASE_PUBLISHABLE_KEY ?? null,
  /** Server-only; used when calling Supabase services with elevated rights. */
  secretKey: config.SUPABASE_SECRET_KEY ?? null,
  dbUrl: resolvedDb.url,
  /** Human-readable configuration problem, safe to show to staff. */
  warning: resolvedDb.warning,
  get dataApiConfigured(): boolean {
    return Boolean(this.url && this.publishableKey);
  },
  get databaseConfigured(): boolean {
    return Boolean(this.dbUrl);
  },
  get active(): boolean {
    return this.databaseConfigured || this.dataApiConfigured;
  },
};

export const corsOrigins = config.CORS_ORIGINS.split(',')
  .map((s) => s.trim())
  .filter(Boolean);
