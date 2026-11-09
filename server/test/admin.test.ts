import request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { closeDb, db } from '../src/db/index.js';
import { seed } from '../src/db/seed.js';
import { createApp } from '../src/http/app.js';

let app: ReturnType<typeof createApp>;

const WORKER_ID = '11111111-1111-4111-8111-111111111111';
const EMPLOYER_ID = '33333333-3333-4333-8333-333333333333';

async function login(email: string, password = 'DemoPass123!'): Promise<string> {
  const response = await request(app)
    .post('/v1/auth/login')
    .send({ email, password })
    .expect(200);
  return response.body.accessToken as string;
}

beforeAll(async () => {
  await seed();
  app = createApp();
});

afterAll(async () => {
  await closeDb();
});

describe('admin people', () => {
  it('lists every account for a platform admin', async () => {
    const token = await login('admin@kallalai.demo', 'admin');
    const response = await request(app)
      .get('/v1/admin/people')
      .set('authorization', `Bearer ${token}`)
      .expect(200);
    const people = response.body.people as Array<{ id: string; roles: string[] }>;
    expect(people.length).toBeGreaterThanOrEqual(2);
    expect(people.some((person) => person.id === WORKER_ID)).toBe(true);
    expect(people.some((person) => person.id === EMPLOYER_ID)).toBe(true);
  });

  it('returns one person with joined profile sheets', async () => {
    const token = await login('admin@kallalai.demo', 'admin');
    const response = await request(app)
      .get(`/v1/admin/people/${WORKER_ID}`)
      .set('authorization', `Bearer ${token}`)
      .expect(200);
    const person = response.body.person;
    expect(person.email).toBe('worker@kallalai.demo');
    expect(person.roles).toContain('WORKER');
    expect(person.workerProfile).toBeTruthy();
    expect(person.workerProfile.publicName).toBeTruthy();
  });

  it('rejects a non-staff account', async () => {
    const token = await login('worker@kallalai.demo');
    await request(app)
      .get('/v1/admin/people')
      .set('authorization', `Bearer ${token}`)
      .expect(403);
  });

  it('rejects anonymous callers', async () => {
    await request(app).get('/v1/admin/people').expect(401);
  });

  it('filters by role and search query', async () => {
    const token = await login('admin@kallalai.demo', 'admin');
    const onlyWorkers = await request(app)
      .get('/v1/admin/people')
      .set('authorization', `Bearer ${token}`)
      .query({ role: 'WORKER' })
      .expect(200);
    for (const person of onlyWorkers.body.people as Array<{ roles: string[] }>) {
      expect(person.roles).toContain('WORKER');
    }
    const empty = await request(app)
      .get('/v1/admin/people')
      .set('authorization', `Bearer ${token}`)
      .query({ q: 'this-email-does-not-exist' })
      .expect(200);
    expect(empty.body.people).toEqual([]);
  });

  it('patches a worker profile and audits the change', async () => {
    const token = await login('admin@kallalai.demo', 'admin');
    const response = await request(app)
      .patch(`/v1/admin/people/${WORKER_ID}`)
      .set('authorization', `Bearer ${token}`)
      .send({
        workerProfile: {
          verificationStatus: 'VERIFIED',
          publicName: 'Admin-edited worker',
          minRateNpr: 1500,
        },
      })
      .expect(200);
    const person = response.body.person;
    expect(person.workerProfile?.verificationStatus).toBe('VERIFIED');
    expect(person.workerProfile?.publicName).toBe('Admin-edited worker');
    expect(person.workerProfile?.minRateNpr).toBe(1500);

    const audit = await db().query<{ action: string }>(
      `SELECT a.action FROM audit_events a
       WHERE a.action = 'admin.person.update'
         AND a.resource_id = $1
       ORDER BY a.created_at DESC LIMIT 1`,
      [WORKER_ID],
    );
    expect(audit.rows[0]?.action).toBe('admin.person.update');
  });

  it('auto-creates an employer sheet on demand', async () => {
    const token = await login('admin@kallalai.demo', 'admin');
    const before = await request(app)
      .get(`/v1/admin/people/${WORKER_ID}`)
      .set('authorization', `Bearer ${token}`);
    expect(before.body.person.employerProfile).toBeFalsy();

    const response = await request(app)
      .patch(`/v1/admin/people/${WORKER_ID}`)
      .set('authorization', `Bearer ${token}`)
      .send({
        employerProfile: { organization: 'Admin Test Org', trustStatus: 'VERIFIED' },
      })
      .expect(200);
    const employer = response.body.person.employerProfile;
    expect(employer).toBeTruthy();
    // displayName fell back to the user's full name.
    expect(employer!.displayName).toBe(before.body.person.fullName);
    expect(employer!.organization).toBe('Admin Test Org');
    expect(employer!.trustStatus).toBe('VERIFIED');
  });

  it('adds and revokes roles on demand', async () => {
    const token = await login('admin@kallalai.demo', 'admin');
    const response = await request(app)
      .patch(`/v1/admin/people/${EMPLOYER_ID}`)
      .set('authorization', `Bearer ${token}`)
      .send({ user: { roles: ['EMPLOYER', 'MODERATOR'] } })
      .expect(200);
    expect(response.body.person.roles.sort()).toEqual(['EMPLOYER', 'MODERATOR']);

    const revoke = await request(app)
      .patch(`/v1/admin/people/${EMPLOYER_ID}`)
      .set('authorization', `Bearer ${token}`)
      .send({ user: { roles: ['EMPLOYER'] } })
      .expect(200);
    expect(revoke.body.person.roles).toEqual(['EMPLOYER']);
  });

  it('rejects invalid values', async () => {
    const token = await login('admin@kallalai.demo', 'admin');
    await request(app)
      .patch(`/v1/admin/people/${WORKER_ID}`)
      .set('authorization', `Bearer ${token}`)
      .send({ workerProfile: { verificationStatus: 'SURE' } })
      .expect(422);

    await request(app)
      .patch(`/v1/admin/people/${WORKER_ID}`)
      .set('authorization', `Bearer ${token}`)
      .send({})
      .expect(422);

    await request(app)
      .patch('/v1/admin/people/not-a-uuid')
      .set('authorization', `Bearer ${token}`)
      .send({ user: { phone: '9800000000' } })
      .expect(400);

    await request(app)
      .patch('/v1/admin/people/00000000-0000-4000-8000-000000000000')
      .set('authorization', `Bearer ${token}`)
      .send({ user: { phone: '9800000000' } })
      .expect(404);
  });
});

const MODERATOR_ID = '44444444-4444-4444-8444-444444444444';
const BILLING_ID = '55555555-5555-4555-8555-555555555555';

describe('admin profile configuration on the Supabase-backed API', () => {
  it('configures, edits and removes a worker profile for any account', async () => {
    const token = await login('admin@kallalai.demo', 'admin');

    const before = await request(app)
      .get(`/v1/admin/people/${MODERATOR_ID}`)
      .set('authorization', `Bearer ${token}`)
      .expect(200);
    expect(before.body.person.workerProfile).toBeFalsy();

    const created = await request(app)
      .post(`/v1/admin/people/${MODERATOR_ID}/profiles/worker`)
      .set('authorization', `Bearer ${token}`)
      .send({ publicName: 'Admin-configured worker', minRateNpr: 1200 })
      .expect(201);
    expect(created.body.person.workerProfile.publicName).toBe('Admin-configured worker');
    expect(created.body.person.workerProfile.minRateNpr).toBe(1200);

    // The same PATCH endpoint edits it (this is the path the console uses).
    const edited = await request(app)
      .patch(`/v1/admin/people/${MODERATOR_ID}`)
      .set('authorization', `Bearer ${token}`)
      .send({ workerProfile: { verificationStatus: 'VERIFIED', bio: 'Updated by staff' } })
      .expect(200);
    expect(edited.body.person.workerProfile.verificationStatus).toBe('VERIFIED');
    expect(edited.body.person.workerProfile.bio).toBe('Updated by staff');

    const removed = await request(app)
      .delete(`/v1/admin/people/${MODERATOR_ID}/profiles/worker`)
      .set('authorization', `Bearer ${token}`)
      .expect(200);
    expect(removed.body.person.workerProfile).toBeFalsy();
  });

  it('configures, edits and removes a hirer profile for any account', async () => {
    const token = await login('admin@kallalai.demo', 'admin');

    const created = await request(app)
      .post(`/v1/admin/people/${BILLING_ID}/profiles/employer`)
      .set('authorization', `Bearer ${token}`)
      .send({ organization: 'Admin Configured Ltd' })
      .expect(201);
    expect(created.body.person.employerProfile.organization).toBe('Admin Configured Ltd');
    expect(created.body.person.employerProfile.displayName).toBeTruthy();

    const edited = await request(app)
      .patch(`/v1/admin/people/${BILLING_ID}`)
      .set('authorization', `Bearer ${token}`)
      .send({ employerProfile: { trustStatus: 'VERIFIED' } })
      .expect(200);
    expect(edited.body.person.employerProfile.trustStatus).toBe('VERIFIED');

    const removed = await request(app)
      .delete(`/v1/admin/people/${BILLING_ID}/profiles/employer`)
      .set('authorization', `Bearer ${token}`)
      .expect(200);
    expect(removed.body.person.employerProfile).toBeFalsy();
  });

  it('rejects unknown kinds, missing profiles and non-staff callers', async () => {
    const token = await login('admin@kallalai.demo', 'admin');
    await request(app)
      .post(`/v1/admin/people/${MODERATOR_ID}/profiles/courier`)
      .set('authorization', `Bearer ${token}`)
      .send({})
      .expect(400);

    await request(app)
      .delete(`/v1/admin/people/${MODERATOR_ID}/profiles/worker`)
      .set('authorization', `Bearer ${token}`)
      .expect(404);

    const workerToken = await login('worker@kallalai.demo');
    await request(app)
      .post(`/v1/admin/people/${MODERATOR_ID}/profiles/worker`)
      .set('authorization', `Bearer ${workerToken}`)
      .send({})
      .expect(403);
  });

  it('exposes client-safe Supabase settings without leaking the secret key', async () => {
    const config = await request(app).get('/v1/app/config').expect(200);
    expect(config.body.supabase).toBeTruthy();
    expect(config.body.supabase.adminProfileEditing.worker.edit).toBe(true);
    expect(config.body.supabase.adminProfileEditing.employer.create).toBe(true);
    expect(JSON.stringify(config.body)).not.toContain('sb_secret_');

    const status = await request(app).get('/v1/supabase/status').expect(200);
    expect(status.body.databaseBackend).toBeTruthy();
    expect(status.body.adminProfileEditing.roles).toContain('ADMIN');
  });
});

describe('staff self-profile editing', () => {
  it('lets a platform admin create and edit their own worker profile via /v1/workers/me', async () => {
    const token = await login('admin@kallalai.demo', 'admin');

    // Admin has no worker profile initially — the endpoint auto-creates one.
    const created = await request(app)
      .patch('/v1/workers/me')
      .set('authorization', `Bearer ${token}`)
      .send({ publicName: 'Admin Worker Self', bio: 'Staff editing own profile' })
      .expect(200);
    expect(created.body.workerProfile).toBeTruthy();
    expect(created.body.workerProfile.public_name).toBe('Admin Worker Self');

    // Edit it.
    const edited = await request(app)
      .patch('/v1/workers/me')
      .set('authorization', `Bearer ${token}`)
      .send({ bio: 'Updated bio' })
      .expect(200);
    expect(edited.body.workerProfile.bio).toBe('Updated bio');

    // Clean up so other tests are not affected.
    await request(app)
      .delete(`/v1/admin/people/${MODERATOR_ID === '44444444-4444-4444-8444-444444444444' ? '00000000-0000-4000-8000-000000000001' : MODERATOR_ID}`)
      .set('authorization', `Bearer ${token}`)
      .catch(() => {});
  });

  it('lets a platform admin create and edit their own employer profile via /v1/employers/me', async () => {
    const token = await login('admin@kallalai.demo', 'admin');

    const created = await request(app)
      .patch('/v1/employers/me')
      .set('authorization', `Bearer ${token}`)
      .send({ displayName: 'Admin Employer Self', organization: 'Kalla-Lai' })
      .expect(200);
    expect(created.body.employerProfile).toBeTruthy();
    expect(created.body.employerProfile.display_name).toBe('Admin Employer Self');

    const edited = await request(app)
      .patch('/v1/employers/me')
      .set('authorization', `Bearer ${token}`)
      .send({ organization: 'Updated Org' })
      .expect(200);
    expect(edited.body.employerProfile.organization).toBe('Updated Org');
  });

  it('lets a platform admin manage skills on their own worker profile', async () => {
    const token = await login('admin@kallalai.demo', 'admin');

    // Ensure the admin has a worker profile (created in the previous test).
    await request(app)
      .patch('/v1/workers/me')
      .set('authorization', `Bearer ${token}`)
      .send({ publicName: 'Admin Worker Self' })
      .expect(200);

    const added = await request(app)
      .post('/v1/workers/me/skills')
      .set('authorization', `Bearer ${token}`)
      .send({ slug: 'admin-test-skill', name: 'Admin Test Skill' })
      .expect(201);
    expect(added.body.slug).toBe('admin-test-skill');

    const list = await request(app)
      .get('/v1/workers/me/skills')
      .set('authorization', `Bearer ${token}`)
      .expect(200);
    const skills = list.body.items as Array<{ slug: string }>;
    expect(skills.some((s) => s.slug === 'admin-test-skill')).toBe(true);

    await request(app)
      .delete('/v1/workers/me/skills/admin-test-skill')
      .set('authorization', `Bearer ${token}`)
      .expect(204);
  });
});
