/**
 * End-to-end smoke test for a running API. Exercises the primary worker and
 * employer journey against real HTTP endpoints and a real database.
 *
 *   npm run smoke
 */
import { createHmac } from 'node:crypto';

const base = process.env.API_BASE_URL ?? 'http://127.0.0.1:8080';
const webhookSecret = process.env.PAYMENT_WEBHOOK_SECRET ?? 'dev-only-webhook-secret';

interface ApiError {
  error: { code: string; message: string };
}

async function request<T = any>(
  method: string,
  path: string,
  options: { token?: string; body?: unknown; headers?: Record<string, string> } = {},
): Promise<T> {
  const response = await fetch(`${base}${path}`, {
    method,
    headers: {
      'content-type': 'application/json',
      ...(options.token ? { authorization: `Bearer ${options.token}` } : {}),
      ...options.headers,
    },
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
  });
  const text = await response.text();
  const json = text ? JSON.parse(text) : null;
  if (!response.ok) {
    throw new Error(`${method} ${path} -> ${response.status}: ${JSON.stringify(json)}`);
  }
  return json as T;
}

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(`Assertion failed: ${message}`);
}

async function main() {
  const health = await request<{ status: string }>('GET', '/healthz');
  assert(health.status === 'ok', 'health endpoint');

  const discovery = await request<{ items: any[]; total: number }>(
    'GET',
    '/v1/discovery/jobs?lat=27.68&lng=85.33&radiusKm=25&limit=10',
  );
  assert(Array.isArray(discovery.items), 'discovery returns items');
  assert(discovery.items.length > 0, 'discovery has seeded jobs');

  const workerLogin = await request<{ accessToken: string; refreshToken: string }>(
    'POST',
    '/v1/auth/login',
    { body: { email: 'worker@kallalai.demo', password: 'DemoPass123!' } },
  );
  const employerLogin = await request<{ accessToken: string }>('POST', '/v1/auth/login', {
    body: { email: 'employer@kallalai.demo', password: 'DemoPass123!' },
  });
  const moderatorLogin = await request<{ accessToken: string }>('POST', '/v1/auth/login', {
    body: { email: 'moderator@kallalai.demo', password: 'DemoPass123!' },
  });

  const worker = workerLogin.accessToken;
  const employer = employerLogin.accessToken;
  const moderator = moderatorLogin.accessToken;

  const session = await request<{ user: { roles: string[] } }>('GET', '/v1/auth/session', {
    token: worker,
  });
  assert(session.user.roles.includes('WORKER'), 'worker role present');

  const job = await request<{ job: { id: string } }>('POST', '/v1/jobs', {
    token: employer,
    body: {
      role: 'Smoke Test Technician',
      description: 'Synthetic job created by the automated smoke test.',
      workMode: 'ON_SITE',
      address: 'Smoke test site, Kathmandu',
      area: 'Baneshwor, Kathmandu',
      latitude: 27.689,
      longitude: 85.343,
      dispatchRadiusKm: 8,
      compensationType: 'HOURLY',
      rateNpr: 1750,
      requiredSkills: ['electrical-safety'],
    },
  });
  await request('POST', `/v1/jobs/${job.job.id}/publish`, { token: employer });

  await request('POST', `/v1/jobs/${job.job.id}/applications`, {
    token: worker,
    body: { message: 'Smoke test application' },
  });

  const applications = await request<{ items: any[] }>(
    'GET',
    `/v1/jobs/${job.job.id}/applications`,
    { token: employer },
  );
  assert(applications.items.length === 1, 'application visible to owner');

  await request('POST', `/v1/applications/${applications.items[0].id}/decision`, {
    token: employer,
    body: { decision: 'ACCEPTED' },
  });

  const startsAt = new Date(Date.now() + 60 * 60 * 1000).toISOString();
  const endsAt = new Date(Date.now() + 6 * 60 * 60 * 1000).toISOString();
  const offer = await request<{ offer: { id: string } }>(
    'POST',
    `/v1/jobs/${job.job.id}/offers`,
    {
      token: employer,
      body: {
        workerId: '11111111-1111-4111-8111-111111111111',
        rateNpr: 1750,
        startsAt,
        endsAt,
        message: 'Smoke test offer',
      },
    },
  );

  const idempotencyKey = `smoke-${Date.now()}`;
  const accepted = await request<{ shiftId: string }>('POST', `/v1/offers/${offer.offer.id}/accept`, {
    token: worker,
    headers: { 'idempotency-key': idempotencyKey },
  });
  const replay = await request<{ shiftId: string }>('POST', `/v1/offers/${offer.offer.id}/accept`, {
    token: worker,
    headers: { 'idempotency-key': idempotencyKey },
  });
  assert(accepted.shiftId === replay.shiftId, 'idempotent offer acceptance');

  const shiftId = accepted.shiftId;
  await request('POST', `/v1/shifts/${shiftId}/on-my-way`, { token: worker });
  await request('POST', `/v1/shifts/${shiftId}/start`, { token: worker });
  await request('POST', `/v1/shifts/${shiftId}/attendance`, {
    token: worker,
    body: { eventType: 'ARRIVED', latitude: 27.689, longitude: 85.343 },
  });
  await request('POST', `/v1/shifts/${shiftId}/completion`, {
    token: worker,
    body: { note: 'Smoke test completion' },
  });

  const approved = await request<{ invoice: { id: string; amountNpr: number } }>(
    'POST',
    `/v1/shifts/${shiftId}/approve`,
    { token: employer },
  );
  const invoiceId = approved.invoice.id;
  assert(approved.invoice.amountNpr === 1750, 'invoice amount matches offer');

  const settlement = await request<{ transactionId: string }>(
    'POST',
    `/v1/invoices/${invoiceId}/approve`,
    { token: employer, headers: { 'idempotency-key': `settle-${idempotencyKey}` } },
  );

  const payload = JSON.stringify({
    provider: 'DEMO',
    providerEventId: `smoke-event-${Date.now()}`,
    type: 'payment.settled',
    transactionId: settlement.transactionId,
    amountNpr: 1750,
    providerRef: 'smoke-ref',
  });
  const signature = createHmac('sha256', webhookSecret).update(payload).digest('hex');
  const webhookResponse = await fetch(`${base}/v1/payments/webhook`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-kalla-signature': signature },
    body: payload,
  });
  assert(webhookResponse.ok, `webhook accepted (${webhookResponse.status})`);

  const invoice = await request<{ invoice: { status: string } }>(
    'GET',
    `/v1/invoices/${invoiceId}`,
    { token: worker },
  );
  assert(invoice.invoice.status === 'PAID', 'invoice settled after webhook');

  const review = await request<{ reviewId: string }>('POST', '/v1/reviews', {
    token: worker,
    body: { shiftId, rating: 5, text: 'Smoke test review' },
  });
  assert(review.reviewId, 'review created');

  const stats = await request<{ publishedJobs: number }>('GET', '/v1/admin/stats', {
    token: moderator,
  });
  assert(stats.publishedJobs >= 0, 'moderator can read stats');

  // Negative authorization: another employer must not read this job's applications.
  const otherEmployer = await request<{ accessToken?: string }>('POST', '/v1/auth/register', {
    body: {
      email: `negative-${Date.now()}@kallalai.demo`,
      password: 'DemoPass123!',
      fullName: 'Negative Test Employer',
      role: 'EMPLOYER',
    },
  });
  const denied = await fetch(`${base}/v1/jobs/${job.job.id}/applications`, {
    headers: { authorization: `Bearer ${otherEmployer.accessToken}` },
  });
  assert(denied.status === 403, `cross-tenant access denied (got ${denied.status})`);

  console.log('Smoke test passed: auth, discovery, hiring, shift, invoice, webhook, reviews, RBAC.');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
