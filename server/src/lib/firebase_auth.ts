import jwt from 'jsonwebtoken';
import { config } from '../config.js';
import { errors } from './errors.js';

/**
 * Claims we rely on from a Firebase ID token.
 *
 * We verify the RS256 signature against Google's public Secure Token
 * certificates instead of the Admin SDK. The Admin SDK requires a service
 * account (or Application Default Credentials), which serverless hosts such as
 * Vercel do not provide by default.
 */
export interface FirebaseIdentity {
  uid: string;
  email?: string;
  email_verified?: boolean;
  name?: string;
  picture?: string;
  firebase?: {
    sign_in_provider?: string;
    identities?: Record<string, unknown>;
  };
  [claim: string]: unknown;
}

const CERT_URL =
  'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';
const CERT_TTL_MS = 60 * 60 * 1000;

let certificateCache: {
  fetchedAt: number;
  values: Record<string, string>;
} | null = null;

async function fetchCertificates(force = false): Promise<Record<string, string>> {
  if (
    !force &&
    certificateCache &&
    Date.now() - certificateCache.fetchedAt < CERT_TTL_MS
  ) {
    return certificateCache.values;
  }

  let response: Response;
  try {
    response = await fetch(CERT_URL, { signal: AbortSignal.timeout(5_000) });
  } catch {
    throw errors.unavailable(
      'FIREBASE_AUTH_UNAVAILABLE',
      'Firebase token verification is temporarily unavailable.',
    );
  }
  if (!response.ok) {
    throw errors.unavailable(
      'FIREBASE_AUTH_UNAVAILABLE',
      'Firebase token verification is temporarily unavailable.',
    );
  }

  let values: Record<string, string>;
  try {
    values = (await response.json()) as Record<string, string>;
  } catch {
    throw errors.unavailable(
      'FIREBASE_AUTH_UNAVAILABLE',
      'Firebase token verification is temporarily unavailable.',
    );
  }
  certificateCache = { fetchedAt: Date.now(), values };
  return values;
}

export async function verifyFirebaseIdToken(
  token: string,
): Promise<FirebaseIdentity> {
  if (!config.FIREBASE_PROJECT_ID) {
    // The local demo has no Firebase project, so it cannot verify the token
    // signature. The client still completes a real Google popup; for synthetic
    // demo data only, trust its decoded claims. Never used in production.
    if (config.DEMO_MODE) {
      return decodeDemoIdToken(token);
    }
    throw errors.unavailable(
      'FIREBASE_AUTH_UNAVAILABLE',
      'Firebase sign-in is not configured on this server.',
    );
  }

  let keyId = '';
  try {
    const decoded = jwt.decode(token, { complete: true });
    keyId = typeof decoded?.header.kid === 'string' ? decoded.header.kid : '';
  } catch {
    keyId = '';
  }

  let certificates = await fetchCertificates();
  let certificate = keyId ? certificates[keyId] : undefined;
  if (!certificate) {
    // Google rotates signing keys; retry once with a fresh certificate set.
    certificates = await fetchCertificates(true);
    certificate = keyId ? certificates[keyId] : undefined;
  }
  if (!certificate) {
    throw errors.unauthorized(
      'Google sign-in expired or is invalid. Try again.',
    );
  }

  try {
    const payload = jwt.verify(token, certificate, {
      algorithms: ['RS256'],
      audience: config.FIREBASE_PROJECT_ID,
      issuer: `https://securetoken.google.com/${config.FIREBASE_PROJECT_ID}`,
      clockTolerance: 60,
    });
    if (typeof payload === 'string') {
      throw new Error('Unexpected string payload.');
    }

    const uid =
      typeof payload.user_id === 'string'
        ? payload.user_id
        : typeof payload.sub === 'string'
          ? payload.sub
          : '';
    if (!uid) throw new Error('Firebase token has no subject.');

    return { ...payload, uid } as FirebaseIdentity;
  } catch (error) {
    if (
      error instanceof jwt.TokenExpiredError ||
      error instanceof jwt.NotBeforeError ||
      error instanceof jwt.JsonWebTokenError
    ) {
      throw errors.unauthorized(
        'Google sign-in expired or is invalid. Try again.',
      );
    }
    throw errors.unavailable(
      'FIREBASE_AUTH_UNAVAILABLE',
      'Firebase token verification is temporarily unavailable.',
    );
  }
}

/// DEMO_MODE only: read the claims from a Firebase ID token without verifying
/// its signature (no Firebase project is configured for the local demo). The
/// caller still enforces a verified Google email. Never used in production.
function decodeDemoIdToken(token: string): FirebaseIdentity {
  const parts = token.split('.');
  if (parts.length !== 3) {
    throw errors.unauthorized(
      'Google sign-in expired or is invalid. Try again.',
    );
  }
  let payload: unknown;
  try {
    payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
  } catch {
    throw errors.unauthorized(
      'Google sign-in expired or is invalid. Try again.',
    );
  }
  if (typeof payload !== 'object' || payload === null) {
    throw errors.unauthorized(
      'Google sign-in expired or is invalid. Try again.',
    );
  }
  const claims = payload as Record<string, unknown>;
  // Firebase ID tokens carry the user id in `user_id`/`sub`; firebase-admin only
  // synthesizes the `uid` field during real verification, so do the same here.
  const uid =
    typeof claims.uid === 'string'
      ? claims.uid
      : typeof claims.user_id === 'string'
        ? claims.user_id
        : typeof claims.sub === 'string'
          ? claims.sub
          : '';
  if (!uid || typeof claims.email !== 'string') {
    throw errors.unauthorized(
      'Google sign-in expired or is invalid. Try again.',
    );
  }
  if (typeof claims.exp === 'number' && claims.exp * 1000 <= Date.now()) {
    throw errors.unauthorized(
      'Google sign-in expired or is invalid. Try again.',
    );
  }
  return { ...claims, uid } as FirebaseIdentity;
}
