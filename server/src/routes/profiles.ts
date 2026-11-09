import { Router } from 'express';
import { z } from 'zod';
import { db, withTransaction } from '../db/index.js';
import { recordAudit } from '../lib/audit.js';
import { authenticate, requireRoles, requireStaff } from '../lib/auth.js';
import { newId } from '../lib/crypto.js';
import { errors } from '../lib/errors.js';
import { asyncHandler } from '../lib/http.js';
import { notify } from '../lib/notify.js';
import { parseBody, parseQuery } from '../lib/validation.js';
import { hub } from '../realtime.js';
import { rolesFor } from './auth.js';

const router = Router();

const coords = z
  .object({
    latitude: z.number().min(-90).max(90),
    longitude: z.number().min(-180).max(180),
  })
  .partial();

const workerPatch = z
  .object({
    publicName: z.string().min(2).max(120),
    baseArea: z.string().max(160),
    latitude: z.number().min(-90).max(90),
    longitude: z.number().min(-180).max(180),
    minRateNpr: z.number().int().min(0).max(10_000_000),
    rateNegotiable: z.boolean(),
    availability: z.string().max(500),
    bio: z.string().max(2000),
    tagline: z.string().max(160),
    languages: z.array(z.string().min(1).max(60)).max(20),
    categories: z.array(z.string().min(1).max(60)).max(30),
    promoVideoUrl: z.string().max(300),
    cvUrl: z.string().max(300),
    portfolioUrls: z.array(z.string().min(1).max(300)).max(10),
  })
  .partial();

const employerPatch = z
  .object({
    displayName: z.string().min(2).max(160),
    organization: z.string().max(160),
    profilePictureUrl: z.string().max(300),
    bio: z.string().max(2000),
    tagline: z.string().max(160),
    baseArea: z.string().max(160),
    latitude: z.number().min(-90).max(90),
    longitude: z.number().min(-180).max(180),
    contactPhone: z.string().max(40),
    websiteUrl: z.string().max(300),
    categories: z.array(z.string().min(1).max(60)).max(30),
    languages: z.array(z.string().min(1).max(60)).max(20),
    portfolioUrls: z.array(z.string().min(1).max(300)).max(10),
  })
  .partial();

const skillSchema = z.object({
  slug: z
    .string()
    .min(2)
    .max(80)
    .regex(/^[a-z0-9-]+$/, 'Use lowercase letters, numbers and dashes.'),
  name: z.string().min(2).max(120).optional(),
  yearsExperience: z.number().min(0).max(60).default(0),
});

const verificationSchema = z.object({
  documentType: z.enum(['CITIZENSHIP', 'PASSPORT', 'DRIVING_LICENSE', 'OTHER']),
  // Opaque vault reference only. Never accept or store raw document bytes here.
  documentRef: z.string().min(6).max(200),
});

const decisionSchema = z.object({
  decision: z.enum(['VERIFIED', 'REJECTED', 'NEEDS_REVIEW']),
  reason: z.string().min(3).max(500),
});

const listVerificationQuery = z.object({
  state: z.enum(['PENDING', 'NEEDS_REVIEW', 'VERIFIED', 'REJECTED']).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(50),
});

router.get(
  '/me',
  authenticate,
  asyncHandler(async (req, res) => {
    const [user, roles, worker, employer] = await Promise.all([
      db().query<{ id: string; email: string; full_name: string; phone: string | null; status: string }>(
        'SELECT id, email, full_name, phone, status FROM users WHERE id = $1',
        [req.user!.id],
      ),
      rolesFor(req.user!.id),
      db().query('SELECT * FROM worker_profiles WHERE user_id = $1', [req.user!.id]),
      db().query('SELECT * FROM employer_profiles WHERE user_id = $1', [req.user!.id]),
    ]);
    res.json({
      user: user.rows[0],
      roles,
      workerProfile: worker.rows[0] ?? null,
      employerProfile: employer.rows[0] ?? null,
    });
  }),
);

router.patch(
  '/workers/me',
  authenticate,
  requireRoles('WORKER', 'ADMIN', 'MODERATOR', 'BILLING_ADMIN'),
  asyncHandler(async (req, res) => {
    // Staff without a worker profile yet: create one on first save so they
    // can configure their own worker sheet without going through the admin
    // console. This mirrors the register flow's worker-profile creation.
    if (req.user!.roles.includes('ADMIN') || req.user!.roles.includes('MODERATOR') || req.user!.roles.includes('BILLING_ADMIN')) {
      const existing = await db().query<{ user_id: string }>(
        'SELECT user_id FROM worker_profiles WHERE user_id = $1',
        [req.user!.id],
      );
      if (!existing.rows[0]) {
        const fullName = await db().query<{ full_name: string }>(
          'SELECT full_name FROM users WHERE id = $1',
          [req.user!.id],
        );
        await db().query(
          `INSERT INTO worker_profiles (user_id, public_name, verification_status)
           VALUES ($1, $2, 'PENDING')`,
          [req.user!.id, fullName.rows[0]?.full_name ?? 'Staff'],
        );
      }
    }
    const body = parseBody(workerPatch, req.body);
    const columnMap: Record<string, string> = {
      publicName: 'public_name',
      baseArea: 'base_area',
      latitude: 'latitude',
      longitude: 'longitude',
      minRateNpr: 'min_rate_npr',
      rateNegotiable: 'rate_negotiable',
      availability: 'availability',
      bio: 'bio',
      tagline: 'tagline',
      languages: 'languages',
      categories: 'categories',
      promoVideoUrl: 'promo_video_url',
      cvUrl: 'cv_url',
      portfolioUrls: 'portfolio_urls',
    };
    const entries = Object.entries(body).filter(([, value]) => value !== undefined);
    if (entries.length === 0) throw errors.badRequest('NO_FIELDS', 'No supported fields were supplied.');
    const sets = entries.map(([key], index) => `${columnMap[key]} = $${index + 1}`);
    const values = entries.map(([, value]) => value);
    await db().query(
      `UPDATE worker_profiles SET ${sets.join(', ')}, updated_at = now()
        WHERE user_id = $${entries.length + 1}`,
      [...values, req.user!.id],
    );
    const profile = await db().query('SELECT * FROM worker_profiles WHERE user_id = $1', [req.user!.id]);
    res.json({ workerProfile: profile.rows[0] });
  }),
);

router.patch(
  '/employers/me',
  authenticate,
  requireRoles('EMPLOYER', 'ADMIN', 'MODERATOR', 'BILLING_ADMIN'),
  asyncHandler(async (req, res) => {
    // Staff without an employer profile yet: create one on first save.
    if (req.user!.roles.includes('ADMIN') || req.user!.roles.includes('MODERATOR') || req.user!.roles.includes('BILLING_ADMIN')) {
      const existing = await db().query<{ user_id: string }>(
        'SELECT user_id FROM employer_profiles WHERE user_id = $1',
        [req.user!.id],
      );
      if (!existing.rows[0]) {
        const fullName = await db().query<{ full_name: string }>(
          'SELECT full_name FROM users WHERE id = $1',
          [req.user!.id],
        );
        await db().query(
          `INSERT INTO employer_profiles (user_id, display_name)
           VALUES ($1, $2)`,
          [req.user!.id, fullName.rows[0]?.full_name ?? 'Staff'],
        );
      }
    }
    const body = parseBody(employerPatch, req.body);
    const entries = Object.entries(body).filter(([, value]) => value !== undefined);
    if (entries.length === 0) throw errors.badRequest('NO_FIELDS', 'No supported fields were supplied.');
    const columnMap: Record<string, string> = {
      displayName: 'display_name',
      organization: 'organization',
      profilePictureUrl: 'profile_picture_url',
      bio: 'bio',
      tagline: 'tagline',
      baseArea: 'base_area',
      latitude: 'latitude',
      longitude: 'longitude',
      contactPhone: 'contact_phone',
      websiteUrl: 'website_url',
      categories: 'categories',
      languages: 'languages',
      portfolioUrls: 'portfolio_urls',
    };
    const sets = entries.map(([key], index) => `${columnMap[key]} = $${index + 1}`);
    const values = entries.map(([, value]) => value);
    await db().query(
      `UPDATE employer_profiles SET ${sets.join(', ')}, updated_at = now()
        WHERE user_id = $${entries.length + 1}`,
      [...values, req.user!.id],
    );
    const profile = await db().query('SELECT * FROM employer_profiles WHERE user_id = $1', [
      req.user!.id,
    ]);
    res.json({ employerProfile: profile.rows[0] });
  }),
);

router.get(
  '/workers/me/skills',
  authenticate,
  requireRoles('WORKER', 'ADMIN', 'MODERATOR', 'BILLING_ADMIN'),
  asyncHandler(async (req, res) => {
    const result = await db().query(
      `SELECT s.slug, s.name, ws.years_experience
         FROM worker_skills ws JOIN skills s ON s.id = ws.skill_id
        WHERE ws.user_id = $1 ORDER BY s.name`,
      [req.user!.id],
    );
    res.json({ items: result.rows });
  }),
);

router.post(
  '/workers/me/skills',
  authenticate,
  requireRoles('WORKER', 'ADMIN', 'MODERATOR', 'BILLING_ADMIN'),
  asyncHandler(async (req, res) => {
    const body = parseBody(skillSchema, req.body);
    const skillId = await withTransaction(async (tx) => {
      const existing = await tx.query<{ id: number }>('SELECT id FROM skills WHERE slug = $1', [
        body.slug,
      ]);
      if (existing.rows[0]) return existing.rows[0].id;
      const created = await tx.query<{ id: number }>(
        'INSERT INTO skills (slug, name) VALUES ($1, $2) RETURNING id',
        [body.slug, body.name ?? body.slug],
      );
      return created.rows[0]!.id;
    });
    await db().query(
      `INSERT INTO worker_skills (user_id, skill_id, years_experience)
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id, skill_id) DO UPDATE SET years_experience = EXCLUDED.years_experience`,
      [req.user!.id, skillId, body.yearsExperience],
    );
    res.status(201).json({ slug: body.slug, name: body.name ?? body.slug, yearsExperience: body.yearsExperience });
  }),
);

router.delete(
  '/workers/me/skills/:slug',
  authenticate,
  requireRoles('WORKER', 'ADMIN', 'MODERATOR', 'BILLING_ADMIN'),
  asyncHandler(async (req, res) => {
    await db().query(
      `DELETE FROM worker_skills ws
        USING skills s
        WHERE ws.skill_id = s.id AND ws.user_id = $1 AND s.slug = $2`,
      [req.user!.id, req.params.slug],
    );
    res.status(204).end();
  }),
);

router.get(
  '/workers/:id',
  asyncHandler(async (req, res) => {
    const result = await db().query<{
      user_id: string;
      public_name: string;
      base_area: string | null;
      min_rate_npr: string | null;
      rate_negotiable: boolean;
      bio: string | null;
      tagline: string | null;
      languages: string[];
      categories: string[];
      promo_video_url: string | null;
      cv_url: string | null;
      portfolio_urls: string[];
      verification_status: string;
      created_at: Date;
    }>(
      `SELECT user_id, public_name, base_area, min_rate_npr, rate_negotiable, bio,
              tagline, languages, categories, promo_video_url, cv_url, portfolio_urls,
              verification_status, created_at
         FROM worker_profiles WHERE user_id = $1`,
      [req.params.id],
    );
    const profile = result.rows[0];
    if (!profile) throw errors.notFound('Worker profile not found.');
    const skills = await db().query(
      `SELECT s.slug, s.name, ws.years_experience
         FROM worker_skills ws JOIN skills s ON s.id = ws.skill_id
        WHERE ws.user_id = $1 ORDER BY s.name`,
      [req.params.id],
    );
    // Deliberately excludes email, phone, identity documents and raw evidence.
    res.json({ worker: { ...profile, skills: skills.rows } });
  }),
);

router.post(
  '/verification/cases',
  authenticate,
  requireRoles('WORKER', 'ADMIN', 'MODERATOR', 'BILLING_ADMIN'),
  asyncHandler(async (req, res) => {
    const body = parseBody(verificationSchema, req.body);
    const profile = await db().query<{ verification_status: string }>(
      'SELECT verification_status FROM worker_profiles WHERE user_id = $1',
      [req.user!.id],
    );
    if (profile.rows[0]?.verification_status === 'VERIFIED') {
      throw errors.conflict('ALREADY_VERIFIED', 'This worker is already verified.');
    }
    const open = await db().query(
      `SELECT 1 FROM verification_cases
        WHERE user_id = $1 AND state IN ('PENDING', 'NEEDS_REVIEW')`,
      [req.user!.id],
    );
    if (open.rows.length > 0) {
      throw errors.conflict('CASE_ALREADY_OPEN', 'A verification case is already awaiting review.');
    }
    const caseId = newId();
    await withTransaction(async (tx) => {
      await tx.query(
        `INSERT INTO verification_cases (id, user_id, state, document_type, document_ref)
         VALUES ($1, $2, 'PENDING', $3, $4)`,
        [caseId, req.user!.id, body.documentType, body.documentRef],
      );
      await tx.query(
        `UPDATE worker_profiles SET verification_status = 'PENDING', updated_at = now()
          WHERE user_id = $1`,
        [req.user!.id],
      );
      await recordAudit(tx, {
        actorId: req.user!.id,
        action: 'verification.submit',
        resourceType: 'verification_case',
        resourceId: caseId,
        correlationId: req.requestId,
        metadata: { documentType: body.documentType },
      });
    });
    res.status(201).json({ caseId, state: 'PENDING' });
  }),
);

router.get(
  '/verification/cases/me',
  authenticate,
  requireRoles('WORKER', 'ADMIN', 'MODERATOR', 'BILLING_ADMIN'),
  asyncHandler(async (req, res) => {
    const result = await db().query(
      `SELECT id, state, document_type, decision_reason, created_at, reviewed_at
         FROM verification_cases WHERE user_id = $1 ORDER BY created_at DESC LIMIT 20`,
      [req.user!.id],
    );
    res.json({ items: result.rows });
  }),
);

router.get(
  '/verification/cases',
  authenticate,
  requireStaff,
  asyncHandler(async (req, res) => {
    const query = parseQuery(listVerificationQuery, req.query);
    const result = await db().query(
      `SELECT vc.id, vc.user_id, u.full_name, wp.public_name, vc.state, vc.document_type,
              vc.document_ref, vc.decision_reason, vc.created_at
         FROM verification_cases vc
         JOIN users u ON u.id = vc.user_id
         LEFT JOIN worker_profiles wp ON wp.user_id = vc.user_id
        WHERE ($1::text IS NULL OR vc.state = $1)
        ORDER BY vc.created_at ASC LIMIT $2`,
      [query.state ?? null, query.limit],
    );
    res.json({ items: result.rows });
  }),
);

router.post(
  '/verification/cases/:id/decision',
  authenticate,
  requireStaff,
  asyncHandler(async (req, res) => {
    const body = parseBody(decisionSchema, req.body);
    const updated = await withTransaction(async (tx) => {
      const result = await tx.query<{ id: string; user_id: string }>(
        `UPDATE verification_cases
            SET state = $1, decision_reason = $2, reviewed_by = $3, reviewed_at = now(), updated_at = now()
          WHERE id = $4 AND state IN ('PENDING', 'NEEDS_REVIEW')
          RETURNING id, user_id`,
        [body.decision, body.reason, req.user!.id, req.params.id],
      );
      const row = result.rows[0];
      if (!row) throw errors.conflict('CASE_NOT_REVIEWABLE', 'This case is not awaiting review.');
      await tx.query(
        `UPDATE worker_profiles SET verification_status = $1, updated_at = now() WHERE user_id = $2`,
        [body.decision === 'VERIFIED' ? 'VERIFIED' : body.decision === 'REJECTED' ? 'REJECTED' : 'PENDING', row.user_id],
      );
      await tx.query(
        `UPDATE users SET identity_status = $1, updated_at = now() WHERE id = $2`,
        [
          body.decision === 'VERIFIED'
            ? 'VERIFIED'
            : body.decision === 'REJECTED'
                ? 'REJECTED'
                : 'NEEDS_ACTION',
          row.user_id,
        ],
      );
      await notify(tx, {
        userId: row.user_id,
        type: 'verification.decided',
        title: body.decision === 'VERIFIED' ? 'Verification approved' : 'Verification update',
        body:
          body.decision === 'VERIFIED'
            ? 'Your identity verification is complete. You can now accept work.'
            : `Your verification needs attention: ${body.reason}`,
        resourceType: 'verification_case',
        resourceId: row.id,
      });
      await recordAudit(tx, {
        actorId: req.user!.id,
        action: 'verification.decide',
        resourceType: 'verification_case',
        resourceId: row.id,
        correlationId: req.requestId,
        metadata: { decision: body.decision },
      });
      return row;
    });
    hub.publish([updated.user_id], 'verification.updated', { type: 'verification_case', id: updated.id }, {
      state: body.decision,
    });
    res.json({ caseId: updated.id, state: body.decision });
  }),
);

export default router;
