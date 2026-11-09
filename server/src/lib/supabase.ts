import { supabase } from '../config.js';

/**
 * Minimal Supabase Data API (PostgREST) helper.
 *
 * The new `sb_publishable_...` keys are opaque strings, not JWTs, so they must
 * be sent on the `apikey` header rather than as an `Authorization: Bearer`
 * token. Keeping this dependency-free (global fetch, Node 22+) means the API
 * can talk to Supabase without shipping another client library.
 *
 * The Express API is still the authoritative backend: business writes go
 * through the `pg` pool (SUPABASE_DB_URL) where server-side authorization
 * applies. This helper is for public/supabase-native calls and health checks.
 */

export interface SupabaseProbe {
  configured: boolean;
  reachable: boolean | null;
  url: string | null;
  projectRef: string | null;
  keyType: 'publishable' | 'legacy-anon' | null;
  statusCode: number | null;
  message: string;
}

/** Public headers for a Supabase REST/Storage request. Never includes the secret key. */
export function supabasePublicHeaders(extra: Record<string, string> = {}): Record<string, string> {
  const key = supabase.publishableKey;
  return {
    accept: 'application/json',
    ...(key ? { apikey: key } : {}),
    ...extra,
  };
}

/**
 * Server-only headers for privileged calls. Falls back to the publishable key
 * when no secret key is configured, which then remains subject to RLS.
 */
export function supabaseServerHeaders(extra: Record<string, string> = {}): Record<string, string> {
  const key = supabase.secretKey ?? supabase.publishableKey;
  return {
    accept: 'application/json',
    ...(key ? { apikey: key } : {}),
    ...extra,
  };
}

let cachedProbe: { at: number; value: SupabaseProbe } | null = null;
const PROBE_TTL_MS = 30_000;

/**
 * Verifies that SUPABASE_URL and the publishable key actually work together.
 * A 401/403 still proves the project is reachable but the key is wrong; a
 * network failure means the URL/ref is wrong or egress is blocked.
 */
export async function probeSupabaseDataApi(force = false): Promise<SupabaseProbe> {
  if (!force && cachedProbe && Date.now() - cachedProbe.at < PROBE_TTL_MS) {
    return cachedProbe.value;
  }

  const keyType = supabase.publishableKey
    ? supabase.publishableKey.startsWith('sb_publishable_')
      ? ('publishable' as const)
      : ('legacy-anon' as const)
    : null;

  const base: Omit<SupabaseProbe, 'configured' | 'reachable' | 'statusCode' | 'message'> = {
    url: supabase.url,
    projectRef: supabase.projectRef,
    keyType,
  };

  if (!supabase.dataApiConfigured) {
    const value: SupabaseProbe = {
      ...base,
      configured: false,
      reachable: null,
      statusCode: null,
      message:
        'Set SUPABASE_PROJECT_REF (or SUPABASE_URL) in server/.env next to the publishable key.',
    };
    cachedProbe = { at: Date.now(), value };
    return value;
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 6_000);
  try {
    // Use Auth settings, not /rest/v1/. Supabase now requires a SECRET key for
    // the REST root/OpenAPI document, so it answers 401 for a perfectly valid
    // publishable key. /auth/v1/settings accepts the publishable key on the
    // `apikey` header and returns 200 only when the key belongs to this project.
    const response = await fetch(`${supabase.url}/auth/v1/settings`, {
      headers: supabasePublicHeaders(),
      signal: controller.signal,
    });
    const reachable = response.status === 200;
    const value: SupabaseProbe = {
      ...base,
      configured: true,
      reachable,
      statusCode: response.status,
      message: response.ok
        ? 'Supabase project reachable and the publishable key was accepted.'
        : response.status === 401 || response.status === 403
          ? 'Project reachable but the publishable key was rejected. Check the key in Supabase -> Settings -> API Keys (it may belong to another project).'
          : `Supabase returned HTTP ${response.status}.`,
    };
    cachedProbe = { at: Date.now(), value };
    return value;
  } catch (error) {
    const value: SupabaseProbe = {
      ...base,
      configured: true,
      reachable: false,
      statusCode: null,
      message: `Could not reach ${supabase.url}: ${(error as Error).message}`,
    };
    cachedProbe = { at: Date.now(), value };
    return value;
  } finally {
    clearTimeout(timer);
  }
}

export function clearSupabaseProbeCache(): void {
  cachedProbe = null;
}
