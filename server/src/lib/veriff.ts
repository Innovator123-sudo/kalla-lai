import { createHmac, timingSafeEqual } from 'node:crypto';
import { z } from 'zod';
import { config } from '../config.js';
import { errors } from './errors.js';

const sessionResponseSchema = z.object({
  status: z.literal('success'),
  verification: z.object({
    id: z.string().uuid(),
    url: z.string().url(),
  }),
});

export function isVeriffSignatureValid(
  rawBody: Buffer,
  signature: string | undefined,
  secret: string,
): boolean {
  if (!signature || !/^[a-f0-9]{64}$/i.test(signature)) return false;
  const expected = createHmac('sha256', secret).update(rawBody).digest();
  const actual = Buffer.from(signature, 'hex');
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}

export async function createVeriffSession(userId: string): Promise<{
  sessionId: string;
  url: string;
}> {
  const { VERIFF_API_KEY, VERIFF_BASE_URL, VERIFF_SHARED_SECRET } = config;
  if (!VERIFF_API_KEY || !VERIFF_BASE_URL || !VERIFF_SHARED_SECRET) {
    throw errors.unavailable(
      'VERIFICATION_UNAVAILABLE',
      'Identity verification is not configured. Contact support.',
    );
  }

  const endpoint = new URL('/v1/sessions', VERIFF_BASE_URL);
  let response: Response;
  try {
    response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-auth-client': VERIFF_API_KEY,
      },
      body: JSON.stringify({
        verification: {
          vendorData: userId,
          endUserId: userId,
        },
      }),
      signal: AbortSignal.timeout(10_000),
    });
  } catch {
    throw errors.unavailable(
      'VERIFICATION_PROVIDER_ERROR',
      'The identity verification provider could not be reached. Try again later.',
    );
  }
  if (!response.ok) {
    throw errors.unavailable(
      'VERIFICATION_PROVIDER_ERROR',
      'The identity verification provider could not start a session. Try again later.',
    );
  }

  let responseBody: unknown;
  try {
    responseBody = await response.json();
  } catch {
    throw errors.unavailable(
      'VERIFICATION_PROVIDER_ERROR',
      'The identity verification provider returned an invalid response.',
    );
  }
  const parsed = sessionResponseSchema.safeParse(responseBody);
  if (!parsed.success) {
    throw errors.unavailable(
      'VERIFICATION_PROVIDER_ERROR',
      'The identity verification provider returned an invalid session.',
    );
  }
  const url = new URL(parsed.data.verification.url);
  if (
    url.protocol !== 'https:' ||
    (url.hostname !== 'veriff.com' && !url.hostname.endsWith('.veriff.com'))
  ) {
    throw errors.unavailable(
      'VERIFICATION_PROVIDER_ERROR',
      'The identity verification provider returned an unsafe session URL.',
    );
  }
  return { sessionId: parsed.data.verification.id, url: url.toString() };
}
