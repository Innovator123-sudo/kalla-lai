/**
 * Blueprint verification (Flutter_Backend_Blueprint.pdf §5, §6, §7.7, §8):
 * system endpoints, force-update gate, maintenance kill switch, refresh
 * reuse detection, idempotent creates, strict input, BOLA/RBAC negatives,
 * tampered tokens, body limits and safe error shapes.
 */
import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { config } from '../src/config.js';
import { closeDb, db } from '../src/db/index.js';
import { seed } from '../src/db/seed.js';
import { createApp } from '../src/http/app.js';
import { compareAppVersions } from '../src/lib/guards.js';

let app: ReturnType<typeof createApp>;

async function login(email: string) {
  const response = await request(app)
    .post('/v1/auth/login')
    .send({ email, password: 'DemoPass123!' })
    .expect(200);
  return response.body as { accessToken: string; refreshToken: string };
}

const jobBody = {
  role: 'Blueprint Test Job',
  description: 'Synthetic job used by the blueprint verification suite.',
  workMode: 'ON_SITE',
  area: 'Baneshwor, Kathmandu',
  latitude: 27.689,
  longitude: 85.343,
  rateNpr: 1500,
};

beforeAll(async () => {
  await seed();
  app = createApp();
});

afterAll(async () => {
  await closeDb();
});

describe('Group A: system and app configuration', () => {
  it('health is alive without dependencies and ready checks the database', async () => {
    const health = await request(app).get('/healthz').expect(200);
    expect(health.body.status).toBe('ok');
    const ready = await request(app).get('/readyz').expect(200);
    expect(ready.body.database).toBe(true);
  });

  it('app/config is public, cacheable and exposes the kill switches', async () => {
    const response = await request(app).get('/v1/app/config').expect(200);
    expect(response.headers['cache-control']).toBe('public, max-age=60');
    expect(response.body.maintenanceMode).toBe(false);
    expect(response.body.minimumAppVersion).toBe('1.0.0');
    expect(response.body.demoMode).toBe(true);
    expect(response.body.features.demoVerification).toBe(true);
  });

  it('compares app versions numerically and ignores build suffixes', () => {
    expect(compareAppVersions('0.9.9', '1.0.0')).toBe(-1);
    expect(compareAppVersions('1.0.0', '1.0.0')).toBe(0);
    expect(compareAppVersions('1.2.3+45', '1.2.3')).toBe(0);
    expect(compareAppVersions('1.10.0', '1.9.0')).toBe(1);
  });

  it('answers 426 for outdated clients that send X-App-Version', async () => {
    const old = await request(app)
      .get('/v1/discovery/jobs')
      .set('x-app-version', '0.9.0')
      .expect(426);
    expect(old.body.error.code).toBe('UPGRADE_REQUIRED');
    await request(app).get('/v1/discovery/jobs').set('x-app-version', '1.0.0').expect(200);
    await request(app).get('/v1/discovery/jobs').set('x-app-version', '2.1.0+99').expect(200);
    // Clients that predate the header keep working.
    await request(app).get('/v1/discovery/jobs').expect(200);
    // The config endpoint itself must stay reachable so the app can learn why.
    await request(app).get('/v1/app/config').set('x-app-version', '0.1.0').expect(200);
  });

  it('maintenance mode sheds /v1 traffic but keeps app/config reachable', async () => {
    config.MAINTENANCE_MODE = true;
    try {
      const blocked = await request(app).get('/v1/discovery/jobs').expect(503);
      expect(blocked.body.error.code).toBe('MAINTENANCE');
      expect(blocked.headers['retry-after']).toBe('60');
      const configResponse = await request(app).get('/v1/app/config').expect(200);
      expect(configResponse.body.maintenanceMode).toBe(true);
    } finally {
      config.MAINTENANCE_MODE = false;
    }
  });
});

describe('Figure 4: refresh rotation and stolen-token detection', () => {
  it('reusing a rotated refresh token revokes every session of the user', async () => {
    const first = await login('worker@kallalai.demo');
    const second = await login('worker@kallalai.demo');

    const rotated = await request(app)
      .post('/v1/auth/refresh')
      .send({ refreshToken: first.refreshToken })
      .expect(200);
    expect(rotated.body.refreshToken).not.toBe(first.refreshToken);

    // Replay the already-used token: stolen-token alarm.
    await request(app)
      .post('/v1/auth/refresh')
      .send({ refreshToken: first.refreshToken })
      .expect(401);

    // Every other session of that user must now be dead too.
    await request(app)
      .post('/v1/auth/refresh')
      .send({ refreshToken: second.refreshToken })
      .expect(401);
    await request(app)
      .post('/v1/auth/refresh')
      .send({ refreshToken: rotated.body.refreshToken })
      .expect(401);

    const audit = await db().query(
      `SELECT 1 FROM audit_events WHERE action = 'auth.refresh_reuse' LIMIT 1`,
    );
    expect(audit.rows.length).toBe(1);
  });
});

describe('safe retries: Idempotency-Key on creates', () => {
  it('returns the first answer on replay and conflicts on a different body', async () => {
    const employer = await login('employer@kallalai.demo');
    const key = `blueprint-${Date.now()}`;
    const send = (body: Record<string, unknown>) =>
      request(app)
        .post('/v1/jobs')
        .set('authorization', `Bearer ${employer.accessToken}`)
        .set('idempotency-key', key)
        .send(body);

    const first = await send(jobBody).expect(201);
    const replay = await send(jobBody).expect(201);
    expect(replay.body.job.id).toBe(first.body.job.id);

    const conflict = await send({ ...jobBody, rateNpr: 9999 }).expect(409);
    expect(conflict.body.error.code).toBe('IDEMPOTENCY_CONFLICT');

    const count = await db().query(
      `SELECT count(*)::int AS n FROM idempotency_keys WHERE key = $1`,
      [key],
    );
    expect(count.rows[0].n).toBe(1);
  });
});

describe('input validation and mass assignment', () => {
  it('rejects unknown fields on register, login and job create', async () => {
    await request(app)
      .post('/v1/auth/register')
      .send({
        email: `strict-${Date.now()}@kallalai.demo`,
        password: 'DemoPass123!',
        fullName: 'Strict Test',
        role: 'WORKER',
        roles: ['ADMIN'],
      })
      .expect(422);
    await request(app)
      .post('/v1/auth/login')
      .send({ email: 'worker@kallalai.demo', password: 'DemoPass123!', admin: true })
      .expect(422);
    const employer = await login('employer@kallalai.demo');
    await request(app)
      .post('/v1/jobs')
      .set('authorization', `Bearer ${employer.accessToken}`)
      .send({ ...jobBody, employerId: '11111111-1111-4111-8111-111111111111' })
      .expect(422);
  });

  it('caps pagination limits', async () => {
    await request(app).get('/v1/discovery/jobs?limit=10000').expect(422);
    await request(app).get('/v1/discovery/jobs?limit=50').expect(200);
  });

  it('answers 413 for oversized bodies and 400 for broken JSON', async () => {
    await request(app)
      .post('/v1/auth/login')
      .send({ email: 'worker@kallalai.demo', password: 'x'.repeat(1_100_000) })
      .expect(413);
    const broken = await request(app)
      .post('/v1/auth/login')
      .set('content-type', 'application/json')
      .send('{"email":')
      .expect(400);
    expect(broken.body.error.code).toBe('INVALID_JSON');
  });

  it('treats SQL-looking input as plain data', async () => {
    const employer = await login('employer@kallalai.demo');
    const created = await request(app)
      .post('/v1/jobs')
      .set('authorization', `Bearer ${employer.accessToken}`)
      .send({ ...jobBody, area: "'; DROP TABLE users; --" })
      .expect(201);
    expect(created.body.job.id).toBeTruthy();
    // The users table survived; authentication still works.
    await login('worker@kallalai.demo');
  });
});

describe('authentication negatives', () => {
  it('rejects tampered and algorithm-none tokens', async () => {
    const { accessToken } = await login('worker@kallalai.demo');
    const [header, payload, signature] = accessToken.split('.');
    const flipped = payload.slice(0, 4) + (payload[4] === 'A' ? 'B' : 'A') + payload.slice(5);
    await request(app)
      .get('/v1/auth/session')
      .set('authorization', `Bearer ${header}.${flipped}.${signature}`)
      .expect(401);

    const b64 = (value: object) => Buffer.from(JSON.stringify(value)).toString('base64url');
    const none = `${b64({ alg: 'none', typ: 'JWT' })}.${b64({ sub: '33333333-3333-4333-8333-333333333333', iss: 'kalla-lai' })}.`;
    await request(app).get('/v1/auth/session').set('authorization', `Bearer ${none}`).expect(401);
    await request(app).get('/v1/auth/session').expect(401);
  });

  it('sets no-store and security headers on sensitive answers', async () => {
    const response = await request(app)
      .post('/v1/auth/login')
      .send({ email: 'worker@kallalai.demo', password: 'DemoPass123!' })
      .expect(200);
    expect(response.headers['cache-control']).toBe('no-store');
    expect(response.headers['x-request-id']).toBeTruthy();
    expect(response.headers['x-content-type-options']).toBe('nosniff');
    expect(response.headers['content-security-policy']).toContain("default-src 'none'");

    const session = await request(app)
      .get('/v1/auth/session')
      .set('authorization', `Bearer ${response.body.accessToken}`)
      .expect(200);
    expect(session.headers['cache-control']).toBe('no-store');
  });

  it('error answers carry a requestId and never a stack trace', async () => {
    const response = await request(app).get('/v1/does-not-exist').expect(404);
    expect(response.body.error.requestId).toBeTruthy();
    expect(response.body.error.stack).toBeUndefined();
    expect(JSON.stringify(response.body)).not.toContain('/src/');
  });
});

describe('BOLA and function-level authorization', () => {
  it('normal users get 403 on every admin endpoint', async () => {
    const worker = await login('worker@kallalai.demo');
    const auth = `Bearer ${worker.accessToken}`;
    await request(app).get('/v1/admin/stats').set('authorization', auth).expect(403);
    await request(app).get('/v1/admin/audit-events').set('authorization', auth).expect(403);
    await request(app).post('/v1/admin/reviews/reveal-due').set('authorization', auth).expect(403);
    await request(app).get('/v1/admin/stats').expect(401);
    const moderator = await login('moderator@kallalai.demo');
    await request(app)
      .get('/v1/admin/stats')
      .set('authorization', `Bearer ${moderator.accessToken}`)
      .expect(200);
  });

  it("one employer cannot read or edit another employer's draft job", async () => {
    const owner = await login('employer@kallalai.demo');
    const created = await request(app)
      .post('/v1/jobs')
      .set('authorization', `Bearer ${owner.accessToken}`)
      .send(jobBody)
      .expect(201);
    const jobId = created.body.job.id as string;

    const stranger = await request(app)
      .post('/v1/auth/register')
      .send({
        email: `stranger-${Date.now()}@kallalai.demo`,
        password: 'DemoPass123!',
        fullName: 'Stranger Employer',
        role: 'EMPLOYER',
      })
      .expect(201);
    const auth = `Bearer ${stranger.body.accessToken}`;

    // Drafts are invisible to non-owners (404, not 403, so IDs cannot be probed).
    await request(app).get(`/v1/jobs/${jobId}`).set('authorization', auth).expect(404);
    await request(app)
      .patch(`/v1/jobs/${jobId}`)
      .set('authorization', auth)
      .send({ rateNpr: 1 })
      .expect(403);
    await request(app)
      .post(`/v1/jobs/${jobId}/publish`)
      .set('authorization', auth)
      .expect(403);
  });
});