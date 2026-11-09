import { applicationDefault, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import type { DecodedIdToken } from 'firebase-admin/auth';
import { config } from '../config.js';
import { errors } from './errors.js';

const appName = 'kalla-lai-auth';

export async function verifyFirebaseIdToken(
  token: string,
): Promise<DecodedIdToken> {
  if (!config.FIREBASE_PROJECT_ID) {
    // The local demo has no Firebase service account, so it cannot verify the
    // token signature. The client still completes a real Google popup; for
    // synthetic demo data only, trust its decoded claims. This path is gated
    // behind DEMO_MODE — production always requires real verification below.
    if (config.DEMO_MODE) {
      return decodeDemoIdToken(token);
    }
    throw errors.unavailable(
      'FIREBASE_AUTH_UNAVAILABLE',
      'Firebase sign-in is not configured on this server.',
    );
  }

  const app =
    getApps().find((candidate) => candidate.name === appName) ??
    initializeApp(
      {
        credential: applicationDefault(),
        projectId: config.FIREBASE_PROJECT_ID,
      },
      appName,
    );
  try {
    return await getAuth(app).verifyIdToken(token, true);
  } catch (error) {
    const code =
      typeof error === 'object' && error !== null && 'code' in error
        ? String(error.code)
        : '';
    if (
      code === 'auth/argument-error' ||
      code === 'auth/invalid-id-token' ||
      code === 'auth/id-token-expired' ||
      code === 'auth/id-token-revoked' ||
      code === 'auth/user-disabled'
    ) {
      throw errors.unauthorized('Google sign-in expired or is invalid. Try again.');
    }
    throw errors.unavailable(
      'FIREBASE_AUTH_UNAVAILABLE',
      'Firebase token verification is temporarily unavailable.',
    );
  }
}

/// DEMO_MODE only: read the claims from a Firebase ID token without verifying
/// its signature (no service account is configured for the local demo). The
/// caller still enforces a verified Google email. Never used in production.
function decodeDemoIdToken(token: string): DecodedIdToken {
  const parts = token.split('.');
  if (parts.length !== 3) {
    throw errors.unauthorized('Google sign-in expired or is invalid. Try again.');
  }
  let payload: unknown;
  try {
    payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
  } catch {
    throw errors.unauthorized('Google sign-in expired or is invalid. Try again.');
  }
  if (typeof payload !== 'object' || payload === null) {
    throw errors.unauthorized('Google sign-in expired or is invalid. Try again.');
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
    throw errors.unauthorized('Google sign-in expired or is invalid. Try again.');
  }
  if (typeof claims.exp === 'number' && claims.exp * 1000 <= Date.now()) {
    throw errors.unauthorized('Google sign-in expired or is invalid. Try again.');
  }
  return { ...claims, uid } as DecodedIdToken;
}
