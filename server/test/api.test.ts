import { createHmac } from 'node:crypto';
import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { closeDb, db } from '../src/db/index.js';
import { seed } from '../src/db/seed.js';
import { createApp } from '../src/http/app.js';
import { config } from '../src/config.js';

let app: ReturnType<typeof createApp>;

const WORKER_ID = '11111111-1111-4111-8111-111111111111';
const EMPLOYER_ID = '33333333-3333-4333-8333-333333333333';

async function login(email: string): Promise<string> {
  const response = await request(app)
    .post('/v1/auth/login')
    .send({ email, password: 'DemoPass123!' })
    .expect(200);
  return response.body.accessToken as string;
}

async function createJob(token: string, overrides: Record<string, unknown> = {}) {
  const response = await request(app)
    .post('/v1/jobs')
    .set('authorization', `Bearer ${token}`)
    .send({
      role: 'Test Technician',
      description: 'Automated test job for the Kalla-Lai marketplace flow.',
      workMode: 'ON_SITE',
      address: 'Test site',
      area: 'Baneshwor, Kathmandu',
      latitude: 27.689,
      longitude: 85.343,
      rateNpr: 1750,
      requiredSkills: ['electrical-safety'],
      ...overrides,
    })
    .expect(201);
  return response.body.job as { id: string };
}

beforeAll(async () => {
  await seed();
  app = createApp();
});

afterAll(async () => {
  await closeDb();
});

describe('authentication', () => {
  it('requires Firebase server configuration before accepting ID tokens', async () => {
    const demo = config.DEMO_MODE;
    config.DEMO_MODE = false;
    try {
      await request(app)
        .post('/v1/auth/firebase')
        .send({ idToken: 'not-a-real-token', role: 'WORKER' })
        .expect(503);
    } finally {
      config.DEMO_MODE = demo;
    }
  });

  it('logs in seeded users and returns roles', async () => {
    const response = await request(app)
      .post('/v1/auth/login')
      .send({ email: 'worker@kallalai.demo', password: 'DemoPass123!' })
      .expect(200);
    expect(response.body.user.roles).toContain('WORKER');
    expect(response.body.accessToken).toBeTruthy();
    expect(response.body.refreshToken).toBeTruthy();
    expect(response.body.user.passwordHash).toBeUndefined();
  });

  it('accepts a short sign-in ID as well as a full email', async () => {
    const byId = await request(app)
      .post('/v1/auth/login')
      .send({ email: 'worker', password: 'DemoPass123!' })
      .expect(200);
    expect(byId.body.user.roles).toContain('WORKER');

    const byEmail = await request(app)
      .post('/v1/auth/login')
      .send({ email: 'worker@kallalai.demo', password: 'DemoPass123!' })
      .expect(200);
    expect(byEmail.body.user.id).toBe(byId.body.user.id);
  });

  it('rejects wrong credentials without revealing account existence', async () => {
    const wrong = await request(app)
      .post('/v1/auth/login')
      .send({ email: 'worker@kallalai.demo', password: 'incorrect-password' })
      .expect(401);
    const missing = await request(app)
      .post('/v1/auth/login')
      .send({ email: 'nobody@kallalai.demo', password: 'incorrect-password' })
      .expect(401);
    expect(wrong.body.error.message).toBe(missing.body.error.message);
  });

  it('rotates refresh tokens and revokes the old one', async () => {
    const loginResponse = await request(app)
      .post('/v1/auth/login')
      .send({ email: 'worker@kallalai.demo', password: 'DemoPass123!' })
      .expect(200);
    const refreshResponse = await request(app)
      .post('/v1/auth/refresh')
      .send({ refreshToken: loginResponse.body.refreshToken })
      .expect(200);
    expect(refreshResponse.body.refreshToken).not.toBe(loginResponse.body.refreshToken);
    await request(app)
      .post('/v1/auth/refresh')
      .send({ refreshToken: loginResponse.body.refreshToken })
      .expect(401);
  });

  it('registers a new account and blocks duplicate email', async () => {
    const email = `new-${Date.now()}@kallalai.demo`;
    const payload = {
      email,
      password: 'DemoPass123!',
      fullName: 'New Worker',
      role: 'WORKER',
    };
    const created = await request(app).post('/v1/auth/register').send(payload).expect(201);
    expect(created.body.user.roles).toEqual(['WORKER']);
    await request(app).post('/v1/auth/register').send(payload).expect(409);
  });
});

describe('discovery privacy', () => {
  it('returns coarse coordinates and no street address', async () => {
    const response = await request(app)
      .get('/v1/discovery/jobs?lat=27.68&lng=85.33&radiusKm=25')
      .expect(200);
    expect(response.body.items.length).toBeGreaterThan(0);
    const job = response.body.items[0];
    expect(job.address).toBeUndefined();
    expect(Number.isFinite(job.latitude)).toBe(true);
    expect(job.latitude.toString().split('.')[1]?.length ?? 0).toBeLessThanOrEqual(3);
  });

  it('honours the radius filter', async () => {
    const far = await request(app)
      .get('/v1/discovery/jobs?lat=27.68&lng=85.33&radiusKm=1')
      .expect(200);
    expect(far.body.items.every((job: { distanceKm: number }) => job.distanceKm <= 1)).toBe(true);
  });
});

describe('worker and employer journey', () => {
  it('runs application, offer, shift, invoice, webhook and review', async () => {
    const worker = await login('worker@kallalai.demo');
    const employer = await login('employer@kallalai.demo');
    const job = await createJob(employer);

    await request(app)
      .post(`/v1/jobs/${job.id}/publish`)
      .set('authorization', `Bearer ${employer}`)
      .expect(200);

    await request(app)
      .post(`/v1/jobs/${job.id}/applications`)
      .set('authorization', `Bearer ${worker}`)
      .send({ message: 'I am available.' })
      .expect(201);

    const applications = await request(app)
      .get(`/v1/jobs/${job.id}/applications`)
      .set('authorization', `Bearer ${employer}`)
      .expect(200);
    expect(applications.body.items).toHaveLength(1);

    await request(app)
      .post(`/v1/applications/${applications.body.items[0].id}/decision`)
      .set('authorization', `Bearer ${employer}`)
      .send({ decision: 'ACCEPTED' })
      .expect(200);

    const offer = await request(app)
      .post(`/v1/jobs/${job.id}/offers`)
      .set('authorization', `Bearer ${employer}`)
      .send({
        workerId: WORKER_ID,
        rateNpr: 1750,
        startsAt: new Date(Date.now() + 3_600_000).toISOString(),
        endsAt: new Date(Date.now() + 6 * 3_600_000).toISOString(),
      })
      .expect(201);

    const idempotencyKey = `test-${Date.now()}`;
    const accepted = await request(app)
      .post(`/v1/offers/${offer.body.offer.id}/accept`)
      .set('authorization', `Bearer ${worker}`)
      .set('idempotency-key', idempotencyKey)
      .expect(200);
    const replay = await request(app)
      .post(`/v1/offers/${offer.body.offer.id}/accept`)
      .set('authorization', `Bearer ${worker}`)
      .set('idempotency-key', idempotencyKey)
      .expect(200);
    expect(replay.body.shiftId).toBe(accepted.body.shiftId);

    const shiftId = accepted.body.shiftId as string;
    await request(app)
      .post(`/v1/shifts/${shiftId}/on-my-way`)
      .set('authorization', `Bearer ${worker}`)
      .expect(200);
    await request(app)
      .post(`/v1/shifts/${shiftId}/start`)
      .set('authorization', `Bearer ${worker}`)
      .expect(200);
    await request(app)
      .post(`/v1/shifts/${shiftId}/attendance`)
      .set('authorization', `Bearer ${worker}`)
      .send({ eventType: 'ARRIVED', latitude: 27.689, longitude: 85.343 })
      .expect(201);
    await request(app)
      .post(`/v1/shifts/${shiftId}/completion`)
      .set('authorization', `Bearer ${worker}`)
      .send({ note: 'Work completed.' })
      .expect(200);

    const approved = await request(app)
      .post(`/v1/shifts/${shiftId}/approve`)
      .set('authorization', `Bearer ${employer}`)
      .expect(200);
    expect(approved.body.invoice.amountNpr).toBe(1750);
    expect(approved.body.invoice.status).toBe('AWAITING_EMPLOYER_REVIEW');

    const settlement = await request(app)
      .post(`/v1/invoices/${approved.body.invoice.id}/approve`)
      .set('authorization', `Bearer ${employer}`)
      .set('idempotency-key', `settle-${idempotencyKey}`)
      .expect(200);
    expect(settlement.body.status).toBe('SETTLEMENT_PROCESSING');

    const payload = JSON.stringify({
      provider: 'DEMO',
      providerEventId: `event-${Date.now()}`,
      type: 'payment.settled',
      transactionId: settlement.body.transactionId,
      amountNpr: 1750,
      providerRef: 'test-ref',
    });
    const signature = createHmac('sha256', 'test-webhook-secret').update(payload).digest('hex');
    await request(app)
      .post('/v1/payments/webhook')
      .set('content-type', 'application/json')
      .set('x-kalla-signature', signature)
      .send(payload)
      .expect(200);
    // Replay is idempotent.
    const duplicate = await request(app)
      .post('/v1/payments/webhook')
      .set('content-type', 'application/json')
      .set('x-kalla-signature', signature)
      .send(payload)
      .expect(200);
    expect(duplicate.body.duplicate).toBe(true);

    const invoice = await request(app)
      .get(`/v1/invoices/${approved.body.invoice.id}`)
      .set('authorization', `Bearer ${worker}`)
      .expect(200);
    expect(invoice.body.invoice.status).toBe('PAID');
    expect(invoice.body.ledger.map((entry: { entry_type: string }) => entry.entry_type)).toEqual([
      'HOLD',
      'RELEASE',
    ]);

    await request(app)
      .post('/v1/reviews')
      .set('authorization', `Bearer ${worker}`)
      .send({ shiftId, rating: 5, text: 'Clear instructions.' })
      .expect(201);
    const employerReview = await request(app)
      .post('/v1/reviews')
      .set('authorization', `Bearer ${employer}`)
      .send({ shiftId, rating: 4, text: 'Good work.' })
      .expect(201);
    expect(employerReview.body.revealed).toBe(true);

    const reviews = await request(app)
      .get(`/v1/shifts/${shiftId}/reviews`)
      .set('authorization', `Bearer ${worker}`)
      .expect(200);
    expect(reviews.body.items.every((review: { rating: number | null }) => review.rating !== null)).toBe(
      true,
    );
  });

  it('rejects a webhook with an invalid signature', async () => {
    await request(app)
      .post('/v1/payments/webhook')
      .set('content-type', 'application/json')
      .set('x-kalla-signature', 'not-a-valid-signature')
      .send('{"provider":"DEMO"}')
      .expect(401);
  });
});

describe('authorization boundaries', () => {
  it('blocks workers from employer endpoints', async () => {
    const worker = await login('worker@kallalai.demo');
    await request(app)
      .post('/v1/jobs')
      .set('authorization', `Bearer ${worker}`)
      .send({ role: 'Nope', description: 'Should not be allowed at all.' })
      .expect(403);
  });

  it('blocks cross-employer application access', async () => {
    const employer = await login('employer@kallalai.demo');
    const job = await createJob(employer);
    const other = await request(app)
      .post('/v1/auth/register')
      .send({
        email: `other-${Date.now()}@kallalai.demo`,
        password: 'DemoPass123!',
        fullName: 'Other Employer',
        role: 'EMPLOYER',
      })
      .expect(201);
    await request(app)
      .get(`/v1/jobs/${job.id}/applications`)
      .set('authorization', `Bearer ${other.body.accessToken}`)
      .expect(403);
  });

  it('refuses offers to unverified workers', async () => {
    const employer = await login('employer@kallalai.demo');
    const job = await createJob(employer);
    await request(app)
      .post(`/v1/jobs/${job.id}/publish`)
      .set('authorization', `Bearer ${employer}`)
      .expect(200);
    const response = await request(app)
      .post(`/v1/jobs/${job.id}/offers`)
      .set('authorization', `Bearer ${employer}`)
      .send({
        workerId: '22222222-2222-4222-8222-222222222222',
        rateNpr: 1500,
        startsAt: new Date(Date.now() + 3_600_000).toISOString(),
        endsAt: new Date(Date.now() + 7_200_000).toISOString(),
      })
      .expect(409);
    expect(response.body.error.code).toBe('WORKER_NOT_VERIFIED');
  });

  it('refuses applications from workers without identity verification', async () => {
    const employer = await login('employer@kallalai.demo');
    const job = await createJob(employer);
    await request(app)
      .post(`/v1/jobs/${job.id}/publish`)
      .set('authorization', `Bearer ${employer}`)
      .expect(200);
    const pendingWorker = await login('worker2@kallalai.demo');
    const response = await request(app)
      .post(`/v1/jobs/${job.id}/applications`)
      .set('authorization', `Bearer ${pendingWorker}`)
      .send({ message: 'Please consider me.' })
      .expect(409);
    expect(response.body.error.code).toBe('WORKER_NOT_VERIFIED');
  });

  it('stores the optional entry survey after sign-in', async () => {
    const token = await login('worker@kallalai.demo');
    await request(app)
      .post('/v1/entry/survey')
      .set('authorization', `Bearer ${token}`)
      .send({
        intent: 'WORKER',
        acquisitionSource: 'FRIEND_FAMILY',
        timeline: 'THIS_WEEK',
        experience: 'SOME',
      })
      .expect(201);

    const stored = await request(app)
      .get('/v1/entry/survey/me')
      .set('authorization', `Bearer ${token}`)
      .expect(200);
    expect(stored.body.survey.acquisition_source).toBe('FRIEND_FAMILY');

    await request(app)
      .post('/v1/entry/survey')
      .set('authorization', `Bearer ${token}`)
      .send({
        intent: 'WORKER',
        acquisitionSource: 'GOOGLE_SEARCH',
        timeline: 'EXPLORING',
        experience: 'EXPERIENCED',
      })
      .expect(201);
    const updated = await request(app)
      .get('/v1/entry/survey/me')
      .set('authorization', `Bearer ${token}`)
      .expect(200);
    expect(updated.body.survey.acquisition_source).toBe('GOOGLE_SEARCH');
    expect(updated.body.survey.timeline).toBe('EXPLORING');

    const audit = await db().query<{ action: string; resource_type: string }>(
      `SELECT action, resource_type FROM audit_events
        WHERE actor_id = $1 AND action = 'entry.survey.saved'
        ORDER BY created_at DESC LIMIT 1`,
      [WORKER_ID],
    );
    expect(audit.rows[0]).toEqual({
      action: 'entry.survey.saved',
      resource_type: 'entry_survey',
    });
  });

  it('hides shifts from unrelated workers', async () => {
    const worker2 = await login('worker2@kallalai.demo');
    await request(app)
      .get('/v1/shifts/88888888-8888-4888-8888-888888888881')
      .set('authorization', `Bearer ${worker2}`)
      .expect(404);
  });

  it('exposes health and metrics endpoints', async () => {
    await request(app).get('/healthz').expect(200);
    await request(app).get('/readyz').expect(200);
    const metrics = await request(app).get('/metrics').expect(200);
    expect(metrics.text).toContain('kalla_lai_http_requests_total');
  });
});
