import { Router } from 'express';
import { z } from 'zod';
import { db, withTransaction, type Db } from '../db/index.js';
import { recordAudit } from '../lib/audit.js';
import {
  authenticate,
  authenticateOptional,
  requireEmployer,
  requireWorker,
} from '../lib/auth.js';
import { newId } from '../lib/crypto.js';
import { errors } from '../lib/errors.js';
import { asyncHandler } from '../lib/http.js';
import { notify } from '../lib/notify.js';
import { cacheGet, cacheSet, bumpDiscoveryGeneration, getDiscoveryGeneration } from '../lib/cache.js';
import { sha256 } from '../lib/crypto.js';
import { jobDto, offerDto, shiftDto } from '../lib/serializers.js';
import { parseBody, parseQuery, idempotent } from '../lib/validation.js';
import { hub } from '../realtime.js';

const router = Router();

const slug = z
  .string()
  .min(2)
  .max(80)
  .regex(/^[a-z0-9-]+$/);

const jobInput = z
  .object({
    role: z.string().min(2).max(120),
    description: z.string().min(10).max(4000),
    workMode: z.enum(['ON_SITE', 'REMOTE', 'HYBRID']).default('ON_SITE'),
    address: z.string().max(300).optional(),
    area: z.string().max(160).optional(),
    latitude: z.number().min(-90).max(90).optional(),
    longitude: z.number().min(-180).max(180).optional(),
    dispatchRadiusKm: z.number().min(0.5).max(100).default(10),
    compensationType: z.enum(['HOURLY', 'DAILY', 'PROJECT', 'MILESTONE']).default('HOURLY'),
    rateNpr: z.number().int().min(0).max(100_000_000),
    currency: z.string().length(3).default('NPR'),
    negotiable: z.boolean().default(true),
    requiredSkills: z.array(slug).max(20).default([]),
    qualifications: z.array(z.string().min(2).max(160)).max(20).default([]),
    category: z.string().trim().min(2).max(80).optional(),
    contactPhone: z.string().trim().min(6).max(32).optional(),
    workingHours: z.string().trim().min(2).max(160).optional(),
    employmentType: z
      .enum(['FULL_TIME', 'PART_TIME', 'CONTRACT', 'TEMPORARY', 'INTERNSHIP'])
      .default('FULL_TIME'),
    openings: z.number().int().min(1).max(1000).default(1),
    salaryIncrement: z.boolean().default(false),
    incrementNote: z.string().trim().max(300).optional(),
    googleMapsLink: z.string().url().max(500).optional(),
  })
  .strict();

const jobPatch = jobInput.partial();

const listJobsQuery = z.object({
  status: z.enum(['DRAFT', 'PUBLISHED', 'CANCELLED', 'FILLED', 'CLOSED']).optional(),
});

const discoveryQuery = z
  .object({
    lat: z.coerce.number().min(-90).max(90).optional(),
    lng: z.coerce.number().min(-180).max(180).optional(),
    radiusKm: z.coerce.number().min(1).max(100).default(25),
    skills: z.string().max(500).optional(),
    q: z.string().max(120).optional(),
    minRateNpr: z.coerce.number().int().min(0).optional(),
    workMode: z.enum(['ON_SITE', 'REMOTE', 'HYBRID']).optional(),
    page: z.coerce.number().int().min(1).max(1000).default(1),
    limit: z.coerce.number().int().min(1).max(50).default(20),
  })
  .refine((value) => (value.lat === undefined) === (value.lng === undefined), {
    message: 'lat and lng must be supplied together',
    path: ['lat'],
  });

const applySchema = z.object({ message: z.string().max(2000).optional() }).strict();

const applicationDecision = z
  .object({
    decision: z.enum(['SHORTLISTED', 'ACCEPTED', 'REJECTED']),
  })
  .strict();

const offerInput = z
  .object({
    workerId: z.string().uuid(),
    rateNpr: z.number().int().min(0).max(100_000_000),
    startsAt: z.coerce.date(),
    endsAt: z.coerce.date(),
    message: z.string().max(1000).optional(),
  })
  .strict()
  .refine((value) => value.endsAt.getTime() > value.startsAt.getTime(), {
    message: 'endsAt must be after startsAt',
    path: ['endsAt'],
  });

// eslint-disable-next-line @typescript-eslint/no-explicit-any
async function loadJob(id: string, tx: Db = db()): Promise<any> {
  const result = await tx.query(
    `SELECT j.*, ep.display_name AS employer_display_name,
            ep.trust_status AS employer_trust_status,
            (SELECT round(avg(r.rating)::numeric, 2) FROM reviews r
              WHERE r.recipient_id = j.employer_id AND r.revealed_at IS NOT NULL) AS employer_rating_avg,
            (SELECT count(*)::int FROM reviews r
              WHERE r.recipient_id = j.employer_id AND r.revealed_at IS NOT NULL) AS employer_rating_count
       FROM jobs j JOIN employer_profiles ep ON ep.user_id = j.employer_id
      WHERE j.id = $1`,
    [id],
  );
  return result.rows[0];
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
async function loadShift(id: string, tx: Db = db()): Promise<any> {
  const result = await tx.query(
    `SELECT s.*, j.role, j.area, j.address, j.latitude, j.longitude, j.required_skills,
            i.id AS invoice_id, i.status AS invoice_status, i.amount_npr AS invoice_amount_npr,
            i.currency AS invoice_currency
       FROM shifts s
       JOIN jobs j ON j.id = s.job_id
       LEFT JOIN invoices i ON i.shift_id = s.id
      WHERE s.id = $1`,
    [id],
  );
  return result.rows[0];
}

router.post(
  '/jobs',
  authenticate,
  requireEmployer,
  asyncHandler(async (req, res) => {
    const body = parseBody(jobInput, req.body);
    if (body.workMode === 'ON_SITE' && (body.latitude === undefined || body.longitude === undefined)) {
      throw errors.badRequest('LOCATION_REQUIRED', 'On-site jobs require latitude and longitude.');
    }
    const id = newId();
    const result = await idempotent(req, 'POST /v1/jobs', async (tx) => {
      await tx.query(
        `INSERT INTO jobs
           (id, employer_id, role, description, work_mode, address, area, latitude, longitude,
            dispatch_radius_km, compensation_type, rate_npr, currency, negotiable,
            required_skills, qualifications, category, contact_phone, working_hours,
            employment_type, openings, salary_increment, increment_note, google_maps_link)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24)`,
        [
          id,
          req.user!.id,
          body.role,
          body.description,
          body.workMode,
          body.address ?? null,
          body.area ?? null,
          body.latitude ?? null,
          body.longitude ?? null,
          body.dispatchRadiusKm,
          body.compensationType,
          body.rateNpr,
          body.currency.toUpperCase(),
          body.negotiable,
          body.requiredSkills,
          body.qualifications,
          body.category ?? null,
          body.contactPhone ?? null,
          body.workingHours ?? null,
          body.employmentType,
          body.openings,
          body.salaryIncrement,
          body.incrementNote ?? null,
          body.googleMapsLink ?? null,
        ],
      );
      await recordAudit(tx, {
        actorId: req.user!.id,
        action: 'job.create',
        resourceType: 'job',
        resourceId: id,
        correlationId: req.requestId,
      });
      const job = await loadJob(id, tx);
      return { status: 201, body: { job: jobDto(job, { exactLocation: true }) } };
    });
    res.status(result.status).json(result.body);
  }),
);

router.get(
  '/jobs/me',
  authenticate,
  requireEmployer,
  asyncHandler(async (req, res) => {
    const query = parseQuery(listJobsQuery, req.query);
    const result = await db().query(
      `SELECT j.*, ep.display_name AS employer_display_name, ep.trust_status AS employer_trust_status,
              (SELECT round(avg(r.rating)::numeric, 2) FROM reviews r
                WHERE r.recipient_id = j.employer_id AND r.revealed_at IS NOT NULL) AS employer_rating_avg,
              (SELECT count(*)::int FROM reviews r
                WHERE r.recipient_id = j.employer_id AND r.revealed_at IS NOT NULL) AS employer_rating_count,
              (SELECT count(*)::int FROM applications a WHERE a.job_id = j.id) AS application_count,
              (SELECT count(*)::int FROM shifts s WHERE s.job_id = j.id) AS shift_count
         FROM jobs j JOIN employer_profiles ep ON ep.user_id = j.employer_id
        WHERE j.employer_id = $1 AND ($2::text IS NULL OR j.status = $2)
        ORDER BY j.created_at DESC LIMIT 100`,
      [req.user!.id, query.status ?? null],
    );
    res.json({
      items: result.rows.map((row) => ({
        ...jobDto(row, { exactLocation: true }),
        applicationCount: Number(row.application_count),
        shiftCount: Number(row.shift_count),
      })),
    });
  }),
);

router.get(
  '/jobs/:id',
  authenticateOptional,
  asyncHandler(async (req, res) => {
    const job = await loadJob(req.params.id);
    if (!job) throw errors.notFound('Job not found.');
    const userId = req.user?.id;
    let isOwner = job.employer_id === userId;
    if (!isOwner && userId) {
      const participant = await db().query(
        'SELECT 1 FROM shifts WHERE job_id = $1 AND worker_id = $2 LIMIT 1',
        [job.id, userId],
      );
      isOwner = participant.rows.length > 0;
    }
    if (job.status === 'DRAFT' && job.employer_id !== userId) throw errors.notFound('Job not found.');
    res.json({ job: jobDto(job, { exactLocation: isOwner }) });
  }),
);

router.patch(
  '/jobs/:id',
  authenticate,
  requireEmployer,
  asyncHandler(async (req, res) => {
    const body = parseBody(jobPatch, req.body);
    const job = await loadJob(req.params.id);
    if (!job) throw errors.notFound('Job not found.');
    if (job.employer_id !== req.user!.id) throw errors.forbidden();
    if (job.status !== 'DRAFT') throw errors.conflict('JOB_NOT_EDITABLE', 'Only draft jobs can be edited.');

    const columnMap: Record<string, string> = {
      role: 'role',
      description: 'description',
      workMode: 'work_mode',
      address: 'address',
      area: 'area',
      latitude: 'latitude',
      longitude: 'longitude',
      dispatchRadiusKm: 'dispatch_radius_km',
      compensationType: 'compensation_type',
      rateNpr: 'rate_npr',
      currency: 'currency',
      negotiable: 'negotiable',
      requiredSkills: 'required_skills',
      qualifications: 'qualifications',
      category: 'category',
      contactPhone: 'contact_phone',
      workingHours: 'working_hours',
      employmentType: 'employment_type',
      openings: 'openings',
      salaryIncrement: 'salary_increment',
      incrementNote: 'increment_note',
      googleMapsLink: 'google_maps_link',
    };
    const entries = Object.entries(body).filter(([, value]) => value !== undefined);
    if (entries.length === 0) throw errors.badRequest('NO_FIELDS', 'No supported fields were supplied.');
    const sets = entries.map(([key], index) => `${columnMap[key]} = $${index + 1}`);
    await db().query(
      `UPDATE jobs SET ${sets.join(', ')}, updated_at = now() WHERE id = $${entries.length + 1}`,
      [...entries.map(([, value]) => value), job.id],
    );
    const updated = await loadJob(job.id);
    res.json({ job: jobDto(updated, { exactLocation: true }) });
  }),
);

router.post(
  '/jobs/:id/publish',
  authenticate,
  requireEmployer,
  asyncHandler(async (req, res) => {
    const job = await loadJob(req.params.id);
    if (!job) throw errors.notFound('Job not found.');
    if (job.employer_id !== req.user!.id) throw errors.forbidden();
    if (job.status !== 'DRAFT') {
      throw errors.conflict('JOB_NOT_PUBLISHABLE', 'Only draft jobs can be published.');
    }
    if (job.work_mode === 'ON_SITE' && (job.latitude === null || job.longitude === null)) {
      throw errors.badRequest('LOCATION_REQUIRED', 'On-site jobs require coordinates before publishing.');
    }
    await withTransaction(async (tx) => {
      await tx.query(
        `UPDATE jobs SET status = 'PUBLISHED', published_at = now(), updated_at = now() WHERE id = $1`,
        [job.id],
      );
      await recordAudit(tx, {
        actorId: req.user!.id,
        action: 'job.publish',
        resourceType: 'job',
        resourceId: job.id,
        correlationId: req.requestId,
      });
    });

    const recipients = await matchingWorkerIds(job.required_skills ?? []);
    bumpDiscoveryGeneration();
    for (const workerId of recipients) {
      hub.publish([workerId], 'job.published', { type: 'job', id: job.id }, {
        role: job.role,
        area: job.area,
        rateNpr: Number(job.rate_npr),
      });
    }
    res.json({ job: jobDto(await loadJob(job.id), { exactLocation: true }), notifiedWorkers: recipients.length });
  }),
);

async function matchingWorkerIds(skills: string[]): Promise<string[]> {
  const result = await db().query<{ user_id: string }>(
    `SELECT DISTINCT ur.user_id
       FROM user_roles ur JOIN worker_profiles wp ON wp.user_id = ur.user_id
      WHERE ur.role = 'WORKER' AND wp.verification_status = 'VERIFIED'
        AND ($1::text[] = '{}'::text[] OR EXISTS (
          SELECT 1 FROM worker_skills ws JOIN skills s ON s.id = ws.skill_id
           WHERE ws.user_id = ur.user_id AND s.slug = ANY($1::text[])))
      LIMIT 500`,
    [skills],
  );
  return result.rows.map((row) => row.user_id);
}

router.post(
  '/jobs/:id/cancel',
  authenticate,
  requireEmployer,
  asyncHandler(async (req, res) => {
    const job = await loadJob(req.params.id);
    if (!job) throw errors.notFound('Job not found.');
    if (job.employer_id !== req.user!.id) throw errors.forbidden();
    if (!['DRAFT', 'PUBLISHED'].includes(job.status)) {
      throw errors.conflict('JOB_NOT_CANCELLABLE', 'This job can no longer be cancelled.');
    }
    await withTransaction(async (tx) => {
      await tx.query(`UPDATE jobs SET status = 'CANCELLED', updated_at = now() WHERE id = $1`, [job.id]);
      const applications = await tx.query<{ worker_id: string }>(
        `UPDATE applications SET status = 'REJECTED', updated_at = now()
          WHERE job_id = $1 AND status IN ('APPLIED', 'SHORTLISTED') RETURNING worker_id`,
        [job.id],
      );
      for (const application of applications.rows) {
        await notify(tx, {
          userId: application.worker_id,
          type: 'job.cancelled',
          title: 'A job you applied to was cancelled',
          body: `The employer cancelled "${job.role}".`,
          resourceType: 'job',
          resourceId: job.id,
        });
      }
      await recordAudit(tx, {
        actorId: req.user!.id,
        action: 'job.cancel',
        resourceType: 'job',
        resourceId: job.id,
        correlationId: req.requestId,
      });
    });
    bumpDiscoveryGeneration();
    res.json({ job: jobDto(await loadJob(job.id), { exactLocation: true }) });
  }),
);

router.get(
  '/discovery/jobs',
  asyncHandler(async (req, res) => {
    const query = parseQuery(discoveryQuery, req.query);
    const skills = query.skills
      ? query.skills
          .split(',')
          .map((value) => value.trim().toLowerCase())
          .filter(Boolean)
          .slice(0, 20)
      : null;
    const offset = (query.page - 1) * query.limit;
    // Round to ~100 m for both the cache key and the query. This keeps cache
    // cardinality bounded and avoids retaining precise worker coordinates.
    const lat = query.lat === undefined ? null : Math.round(query.lat * 1000) / 1000;
    const lng = query.lng === undefined ? null : Math.round(query.lng * 1000) / 1000;
    const radius = query.lat !== undefined ? query.radiusKm : null;

    const cacheKey = `discovery:v2:gen${getDiscoveryGeneration()}:${sha256(
      JSON.stringify([
        lat,
        lng,
        radius,
        skills,
        query.q ?? null,
        query.minRateNpr ?? null,
        query.workMode ?? null,
        query.page,
        query.limit,
      ]),
    )}`;
    const cached = await cacheGet(cacheKey);
    if (cached) {
      res.setHeader('Cache-Control', 'public, max-age=20');
      res.type('application/json').send(cached);
      return;
    }

    const result = await db().query(
      `SELECT * FROM (
         SELECT j.*, ep.display_name AS employer_display_name,
                ep.trust_status AS employer_trust_status,
                (SELECT round(avg(r.rating)::numeric, 2) FROM reviews r
                  WHERE r.recipient_id = j.employer_id AND r.revealed_at IS NOT NULL) AS employer_rating_avg,
                (SELECT count(*)::int FROM reviews r
                  WHERE r.recipient_id = j.employer_id AND r.revealed_at IS NOT NULL) AS employer_rating_count,
                CASE WHEN $1::float8 IS NOT NULL
                       AND j.latitude IS NOT NULL AND j.longitude IS NOT NULL
                     THEN 6371 * acos(least(1, greatest(-1,
                       cos(radians($1::float8)) * cos(radians(j.latitude)) *
                       cos(radians(j.longitude) - radians($2::float8)) +
                       sin(radians($1::float8)) * sin(radians(j.latitude)))))
                     ELSE NULL END AS distance_km,
                count(*) OVER () AS total_count
           FROM jobs j JOIN employer_profiles ep ON ep.user_id = j.employer_id
          WHERE j.status = 'PUBLISHED'
            AND ($4::text[] IS NULL OR j.required_skills && $4::text[])
            AND ($5::text IS NULL OR j.role ILIKE '%' || $5::text || '%'
                                  OR j.description ILIKE '%' || $5::text || '%')
            AND ($6::bigint IS NULL OR j.rate_npr >= $6::bigint)
            AND ($7::text IS NULL OR j.work_mode = $7::text)
       ) t
       WHERE ($3::float8 IS NULL OR t.distance_km IS NULL OR t.distance_km <= $3::float8)
       ORDER BY CASE WHEN t.distance_km IS NULL THEN 1 ELSE 0 END,
                t.distance_km ASC NULLS LAST, t.published_at DESC
       LIMIT $8 OFFSET $9`,
      [lat, lng, radius, skills, query.q ?? null, query.minRateNpr ?? null, query.workMode ?? null, query.limit, offset],
    );

    const total = result.rows[0]?.total_count ? Number(result.rows[0].total_count) : 0;
    const payload = {
      items: result.rows.map((row) =>
        jobDto(row, { distanceKm: row.distance_km === null ? undefined : Number(row.distance_km) }),
      ),
      page: query.page,
      limit: query.limit,
      total,
      hasMore: offset + result.rows.length < total,
    };
    // Short TTL: discovery can be a few seconds stale, but never authoritative.
    await cacheSet(cacheKey, JSON.stringify(payload), 20);
    res.setHeader('Cache-Control', 'public, max-age=20');
    res.json(payload);
  }),
);

router.post(
  '/jobs/:id/applications',
  authenticate,
  requireWorker,
  asyncHandler(async (req, res) => {
    const body = parseBody(applySchema, req.body ?? {});
    const identity = await db().query<{ identity_status: string }>(
      'SELECT identity_status FROM users WHERE id = $1',
      [req.user!.id],
    );
    if (identity.rows[0]?.identity_status !== 'VERIFIED') {
      throw errors.conflict(
        'WORKER_NOT_VERIFIED',
        'Complete identity verification before applying for jobs.',
      );
    }
    const job = await loadJob(req.params.id);
    if (!job) throw errors.notFound('Job not found.');
    if (job.status !== 'PUBLISHED') throw errors.conflict('JOB_NOT_OPEN', 'This job is not accepting applications.');
    const applicationId = newId();
    try {
      await withTransaction(async (tx) => {
        await tx.query(
          `INSERT INTO applications (id, job_id, worker_id, message) VALUES ($1, $2, $3, $4)`,
          [applicationId, job.id, req.user!.id, body.message ?? null],
        );
        await notify(tx, {
          userId: job.employer_id,
          type: 'application.created',
          title: 'New job application',
          body: `A worker applied for "${job.role}".`,
          resourceType: 'application',
          resourceId: applicationId,
        });
        await recordAudit(tx, {
          actorId: req.user!.id,
          action: 'application.create',
          resourceType: 'application',
          resourceId: applicationId,
          correlationId: req.requestId,
        });
      });
    } catch (error) {
      if ((error as { code?: string }).code === '23505') {
        throw errors.conflict('ALREADY_APPLIED', 'You have already applied to this job.');
      }
      throw error;
    }
    hub.publish([job.employer_id], 'application.updated', { type: 'application', id: applicationId }, {
      jobId: job.id,
      status: 'APPLIED',
    });
    res.status(201).json({ applicationId, status: 'APPLIED' });
  }),
);

router.get(
  '/jobs/:id/applications',
  authenticate,
  requireEmployer,
  asyncHandler(async (req, res) => {
    const job = await loadJob(req.params.id);
    if (!job) throw errors.notFound('Job not found.');
    if (job.employer_id !== req.user!.id) throw errors.forbidden();
    const result = await db().query(
      `SELECT a.id, a.status, a.message, a.created_at, a.worker_id,
              u.full_name, wp.public_name, wp.verification_status, wp.base_area,
              wp.min_rate_npr, wp.rate_negotiable, wp.bio
         FROM applications a
         JOIN users u ON u.id = a.worker_id
         LEFT JOIN worker_profiles wp ON wp.user_id = a.worker_id
        WHERE a.job_id = $1 ORDER BY a.created_at DESC LIMIT 100`,
      [job.id],
    );
    res.json({ items: result.rows });
  }),
);

router.get(
  '/me/applications',
  authenticate,
  requireWorker,
  asyncHandler(async (req, res) => {
    const result = await db().query(
      `SELECT a.id, a.status, a.message, a.created_at,
              j.id AS job_id, j.role, j.area, j.rate_npr, j.currency, j.status AS job_status,
              ep.display_name AS employer_display_name, ep.trust_status AS employer_trust_status
         FROM applications a
         JOIN jobs j ON j.id = a.job_id
         JOIN employer_profiles ep ON ep.user_id = j.employer_id
        WHERE a.worker_id = $1 ORDER BY a.created_at DESC LIMIT 100`,
      [req.user!.id],
    );
    res.json({ items: result.rows });
  }),
);

router.post(
  '/applications/:id/decision',
  authenticate,
  requireEmployer,
  asyncHandler(async (req, res) => {
    const body = parseBody(applicationDecision, req.body);
    const updated = await withTransaction(async (tx) => {
      const result = await tx.query<{
        id: string;
        job_id: string;
        worker_id: string;
        employer_id: string;
        role: string;
      }>(
        `SELECT a.id, a.job_id, a.worker_id, j.employer_id, j.role
           FROM applications a JOIN jobs j ON j.id = a.job_id
          WHERE a.id = $1 FOR UPDATE`,
        [req.params.id],
      );
      const application = result.rows[0];
      if (!application) throw errors.notFound('Application not found.');
      if (application.employer_id !== req.user!.id) throw errors.forbidden();
      await tx.query(
        `UPDATE applications SET status = $1, updated_at = now() WHERE id = $2`,
        [body.decision, application.id],
      );
      if (body.decision === 'ACCEPTED') {
        await tx.query(
          `UPDATE applications SET status = 'REJECTED', updated_at = now()
            WHERE job_id = $1 AND id <> $2 AND status IN ('APPLIED', 'SHORTLISTED')`,
          [application.job_id, application.id],
        );
      }
      await notify(tx, {
        userId: application.worker_id,
        type: 'application.updated',
        title: 'Application update',
        body:
          body.decision === 'ACCEPTED'
            ? `Your application for "${application.role}" was accepted. The employer can now send an offer.`
            : `Your application for "${application.role}" is now ${body.decision.toLowerCase()}.`,
        resourceType: 'application',
        resourceId: application.id,
      });
      await recordAudit(tx, {
        actorId: req.user!.id,
        action: 'application.decide',
        resourceType: 'application',
        resourceId: application.id,
        correlationId: req.requestId,
        metadata: { decision: body.decision },
      });
      return application;
    });
    hub.publish([updated.worker_id], 'application.updated', { type: 'application', id: updated.id }, {
      jobId: updated.job_id,
      status: body.decision,
    });
    res.json({ applicationId: updated.id, status: body.decision });
  }),
);

router.post(
  '/jobs/:jobId/offers',
  authenticate,
  requireEmployer,
  asyncHandler(async (req, res) => {
    const body = parseBody(offerInput, req.body);
    const job = await loadJob(req.params.jobId);
    if (!job) throw errors.notFound('Job not found.');
    if (job.employer_id !== req.user!.id) throw errors.forbidden();
    if (job.status !== 'PUBLISHED') throw errors.conflict('JOB_NOT_OPEN', 'Offers require a published job.');
    const worker = await db().query<{ verification_status: string }>(
      'SELECT verification_status FROM worker_profiles WHERE user_id = $1',
      [body.workerId],
    );
    if (!worker.rows[0]) throw errors.notFound('Worker not found.');
    if (worker.rows[0].verification_status !== 'VERIFIED') {
      throw errors.conflict('WORKER_NOT_VERIFIED', 'Only verified workers can receive offers.');
    }
    const offerId = newId();
    await withTransaction(async (tx) => {
      await tx.query(
        `INSERT INTO offers (id, job_id, employer_id, worker_id, rate_npr, starts_at, ends_at, message)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
        [
          offerId,
          job.id,
          req.user!.id,
          body.workerId,
          body.rateNpr,
          body.startsAt.toISOString(),
          body.endsAt.toISOString(),
          body.message ?? null,
        ],
      );
      await notify(tx, {
        userId: body.workerId,
        type: 'offer.created',
        title: 'New work offer',
        body: `You received an offer for "${job.role}" in ${job.area ?? 'your area'}.`,
        resourceType: 'offer',
        resourceId: offerId,
      });
      await recordAudit(tx, {
        actorId: req.user!.id,
        action: 'offer.create',
        resourceType: 'offer',
        resourceId: offerId,
        correlationId: req.requestId,
      });
    });
    hub.publish([body.workerId], 'offer.created', { type: 'offer', id: offerId }, {
      jobId: job.id,
      role: job.role,
      rateNpr: body.rateNpr,
    });
    const offer = await db().query(
      `SELECT o.*, j.role, j.area, j.required_skills FROM offers o JOIN jobs j ON j.id = o.job_id WHERE o.id = $1`,
      [offerId],
    );
    res.status(201).json({ offer: offerDto(offer.rows[0]) });
  }),
);

router.get(
  '/offers/me',
  authenticate,
  requireWorker,
  asyncHandler(async (req, res) => {
    const result = await db().query(
      `SELECT o.*, j.role, j.area, j.required_skills,
              ep.display_name AS employer_display_name, ep.trust_status AS employer_trust_status
         FROM offers o
         JOIN jobs j ON j.id = o.job_id
         JOIN employer_profiles ep ON ep.user_id = o.employer_id
        WHERE o.worker_id = $1 ORDER BY o.created_at DESC LIMIT 100`,
      [req.user!.id],
    );
    res.json({ items: result.rows.map(offerDto) });
  }),
);

router.post(
  '/offers/:id/accept',
  authenticate,
  requireWorker,
  asyncHandler(async (req, res) => {
    const offerId = req.params.id;
    const result = await idempotent(req, `POST /v1/offers/${offerId}/accept`, async (tx) => {
      const offerResult = await tx.query<{
        id: string;
        job_id: string;
        employer_id: string;
        worker_id: string;
        rate_npr: string;
        starts_at: Date;
        ends_at: Date;
        status: string;
        role: string;
      }>(
        `SELECT o.*, j.role FROM offers o JOIN jobs j ON j.id = o.job_id
          WHERE o.id = $1 FOR UPDATE`,
        [offerId],
      );
      const offer = offerResult.rows[0];
      if (!offer) throw errors.notFound('Offer not found.');
      if (offer.worker_id !== req.user!.id) throw errors.forbidden();
      if (offer.status !== 'CREATED') {
        throw errors.conflict('OFFER_NOT_OPEN', `This offer is already ${offer.status.toLowerCase()}.`);
      }
      const verification = await tx.query<{ verification_status: string }>(
        'SELECT verification_status FROM worker_profiles WHERE user_id = $1',
        [req.user!.id],
      );
      if (verification.rows[0]?.verification_status !== 'VERIFIED') {
        throw errors.forbidden('Complete identity verification before accepting work.');
      }
      await tx.query(
        `UPDATE offers SET status = 'ACCEPTED', responded_at = now() WHERE id = $1`,
        [offer.id],
      );
      const shiftId = newId();
      await tx.query(
        `INSERT INTO shifts (id, job_id, worker_id, employer_id, offer_id, starts_at, ends_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7)`,
        [shiftId, offer.job_id, offer.worker_id, offer.employer_id, offer.id, offer.starts_at, offer.ends_at],
      );
      await tx.query(`UPDATE jobs SET status = 'FILLED', updated_at = now() WHERE id = $1`, [offer.job_id]);
      await notify(tx, {
        userId: offer.employer_id,
        type: 'offer.accepted',
        title: 'Offer accepted',
        body: `The worker accepted your offer for "${offer.role}".`,
        resourceType: 'shift',
        resourceId: shiftId,
      });
      await recordAudit(tx, {
        actorId: req.user!.id,
        action: 'offer.accept',
        resourceType: 'offer',
        resourceId: offer.id,
        correlationId: req.requestId,
        metadata: { shiftId },
      });
      return { status: 200, body: { offerId: offer.id, shiftId, status: 'ACCEPTED' } };
    });

    if (result.status === 200) {
      const shift = await loadShift((result.body as { shiftId: string }).shiftId);
      hub.publish([shift.employer_id, shift.worker_id], 'shift.status.updated', { type: 'shift', id: shift.id }, {
        status: shift.status,
      });
      res.json({ ...(result.body as object), shift: shiftDto(shift) });
      return;
    }
    res.status(result.status).json(result.body);
  }),
);

router.post(
  '/offers/:id/decline',
  authenticate,
  requireWorker,
  asyncHandler(async (req, res) => {
    const result = await db().query<{ id: string; employer_id: string; role: string; worker_id: string }>(
      `UPDATE offers o SET status = 'DECLINED', responded_at = now()
         FROM jobs j
        WHERE j.id = o.job_id AND o.id = $1 AND o.worker_id = $2 AND o.status = 'CREATED'
        RETURNING o.id, o.employer_id, o.worker_id, j.role`,
      [req.params.id, req.user!.id],
    );
    const offer = result.rows[0];
    if (!offer) throw errors.conflict('OFFER_NOT_OPEN', 'This offer is not open for this account.');
    await withTransaction(async (tx) => {
      await notify(tx, {
        userId: offer.employer_id,
        type: 'offer.declined',
        title: 'Offer declined',
        body: `The worker declined your offer for "${offer.role}".`,
        resourceType: 'offer',
        resourceId: offer.id,
      });
      await recordAudit(tx, {
        actorId: req.user!.id,
        action: 'offer.decline',
        resourceType: 'offer',
        resourceId: offer.id,
        correlationId: req.requestId,
      });
    });
    hub.publish([offer.employer_id], 'offer.updated', { type: 'offer', id: offer.id }, {
      status: 'DECLINED',
    });
    res.json({ offerId: offer.id, status: 'DECLINED' });
  }),
);

export default router;
