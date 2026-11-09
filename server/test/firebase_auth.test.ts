import { describe, expect, it } from 'vitest';
import { verifyFirebaseIdToken } from '../src/lib/firebase_auth.js';
import { config } from '../src/config.js';

describe('Firebase token verification', () => {
  it('fails closed when the API has no Firebase project configured', async () => {
    const demo = config.DEMO_MODE;
    config.DEMO_MODE = false;
    try {
      await expect(verifyFirebaseIdToken('not-a-real-token')).rejects.toMatchObject({
        code: 'FIREBASE_AUTH_UNAVAILABLE',
        status: 503,
      });
    } finally {
      config.DEMO_MODE = demo;
    }
  });
});
