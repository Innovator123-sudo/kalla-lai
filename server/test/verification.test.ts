import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { closeDb } from '../src/db/index.js';
import { seed } from '../src/db/seed.js';
import { createApp } from '../src/http/app.js';

let app: ReturnType<typeof createApp>;
let token: string;

beforeAll(async () => {
  await seed();
  app = createApp();
  const response = await request(app)
    .post('/v1/auth/login')
    .send({ email: 'worker@kallalai.demo', password: 'DemoPass123!' })
    .expect(200);
  token = response.body.accessToken as string;
});

afterAll(async () => {
  await closeDb();
});

describe('in-app identity verification routing', () => {
  it('reports IN_APP when Veriff is not configured', async () => {
    const response = await request(app)
      .get('/v1/verification/me')
      .set('authorization', `Bearer ${token}`)
      .expect(200);
    expect(response.body.mode).toBe('IN_APP');
  });

  it('refuses to start a Veriff session without Veriff credentials', async () => {
    const response = await request(app)
      .post('/v1/verification/sessions')
      .set('authorization', `Bearer ${token}`)
      .send({ consent: true })
      .expect(503);
    expect(response.body.error.code).toBe('VERIFF_NOT_CONFIGURED');
  });

  it('validates the document payload before running OCR', async () => {
    const response = await request(app)
      .post('/v1/verification/document')
      .set('authorization', `Bearer ${token}`)
      .send({ consent: true, documentType: 'CITIZENSHIP' })
      .expect(422);
    expect(response.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('keeps the old demo-document path as a compatibility alias', async () => {
    const response = await request(app)
      .post('/v1/verification/demo-document')
      .set('authorization', `Bearer ${token}`)
      .send({ consent: true, documentType: 'CITIZENSHIP' })
      .expect(422);
    expect(response.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('requires authentication', async () => {
    await request(app)
      .post('/v1/verification/document')
      .send({ consent: true })
      .expect(401);
  });
});
