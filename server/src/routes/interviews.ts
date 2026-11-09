import { Router } from 'express';
import { z } from 'zod';
import { db, withTransaction } from '../db/index.js';
import { recordAudit } from '../lib/audit.js';
import { authenticate } from '../lib/auth.js';
import { newId } from '../lib/crypto.js';
import { errors } from '../lib/errors.js';
import { asyncHandler } from '../lib/http.js';
import { notify } from '../lib/notify.js';
import { parseBody } from '../lib/validation.js';
import { hub } from '../realtime.js';

const router = Router();

const interviewInput = z
  .object({
    workerId: z.string().uuid().optional(),
    scheduledAt: z.coerce.date(),
    durationMinutes: z.number().int().min(10).max(180).default(30),
    mode: z.enum(['ON_SITE', 'PHONE', 'VIDEO']).default('ON_SITE'),
    locationNote: z.string().trim().max(300).optional(),
    message: z.string().max(1000).optional(),
  })
  .strict();

const decisionInput = z
  .object({ decision: z.enum(['CONFIRMED', 'DECLINED']) })
  .strict();

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function interviewDto(row: Record<string, any>) {
  return {
    id: row.id,
    jobId: row.job_id,
    workerId: row.worker_id,
    employerId: row.employer_id,
    proposedBy: row.proposed_by,
    scheduledAt: row.scheduled_at,
    durationMinutes: Number(row.duration_minutes),
    mode: row.mode,
    locationNote: row.location_note ?? undefined,
    message: row.message ?? undefined,
    status: row.status,
    createdAt: row.created_at,
    jobRole: row.job_role ?? undefined,
    jobArea: row.job_area ?? undefined,
    workerName: row.worker_name ?? undefined,
    employerName: row.employer_name ?? undefined,
  };
}

const INTERVIEW_SELECT = `
  SELECT i.*, j.role AS job_role, j.area AS job_area,
         wp.public_name AS worker_name, ep.display_name AS employer_name
    FROM interviews i
    JOIN jobs j ON j.id = i.job_id
    LEFT JOIN worker_profiles wp ON wp.user_id = i.worker_id
    LEFT JOIN employer_profiles ep ON ep.user_id = i.employer_id`;

/**
 * Workers propose an interview on a published job; the job's employer can
 * also invite a specific worker (workerId required). The other side then
 * confirms or declines via the decision endpoint.
 */
router.post(
  '/jobs/:id/interviews',
  authenticate,
  asyncHandler(async (req, res) => {
    const body = parseBody(interviewInput, req.body);
    if (body.scheduledAt.getTime() <= Date.now()) {
      throw errors.badRequest('INTERVIEW_IN_PAST', 'Pick a future date and time for the interview.');
    }
    const jobResult = await db().query<{
      id: string;
      employer_id: string;
      role: string;
      status: string;
    }>('SELECT id, employer_id, role, status FROM jobs WHERE id = $1', [req.params.id]);
    const job = jobResult.rows[0];
    if (!job) throw errors.notFound('Job not found.');
    if (job.status !== 'PUBLISHED') {
      throw errors.conflict('JOB_NOT_OPEN', 'Interviews can only be booked on published jobs.');
    }

    const user = req.user!;
    const isOwner = job.employer_id === user.id;
    let workerId: string;
    if (isOwner) {
      if (!user.roles.includes('EMPLOYER')) throw errors.forbidden();
      if (!body.workerId) {
        throw errors.badRequest('WORKER_REQUIRED', 'Choose which worker to invite.');
      }
      workerId = body.workerId;
      const worker = await db().query('SELECT 1 FROM worker_profiles WHERE user_id = $1', [workerId]);
      if (!worker.rows[0]) throw errors.notFound('Worker not found.');
    } else {
      if (!user.roles.includes('WORKER')) throw errors.forbidden();
      if (body.workerId && body.workerId !== user.id) throw errors.forbidden();
      workerId = user.id;
    }

    const interviewId = newId();
    try {
      await withTransaction(async (tx) => {
        const open = await tx.query(
          `SELECT 1 FROM interviews
            WHERE job_id = $1 AND worker_id = $2 AND status IN ('PROPOSED', 'CONFIRMED')`,
          [job.id, workerId],
        );
        if (open.rows[0]) {
          throw errors.conflict('INTERVIEW_ALREADY_OPEN', 'An interview for this job is already proposed or confirmed.');
        }
        await tx.query(
          `INSERT INTO interviews
             (id, job_id, worker_id, employer_id, proposed_by, scheduled_at,
              duration_minutes, mode, location_note, message)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
          [
            interviewId,
            job.id,
            workerId,
            job.employer_id,
            user.id,
            body.scheduledAt.toISOString(),
            body.durationMinutes,
            body.mode,
            body.locationNote ?? null,
            body.message ?? null,
          ],
        );
        await notify(tx, {
          userId: isOwner ? workerId : job.employer_id,
          type: 'interview.proposed',
          title: 'Interview proposed',
          body: isOwner
            ? `You are invited to an interview for "${job.role}". Confirm or decline it.`
            : `A worker proposed an interview for "${job.role}". Confirm or decline it.`,
          resourceType: 'interview',
          resourceId: interviewId,
        });
        await recordAudit(tx, {
          actorId: user.id,
          action: 'interview.propose',
          resourceType: 'interview',
          resourceId: interviewId,
          correlationId: req.requestId,
          metadata: { jobId: job.id },
        });
      });
    } catch (error) {
      if ((error as { code?: string }).code === '23505') {
        throw errors.conflict('INTERVIEW_ALREADY_OPEN', 'An interview for this job is already proposed or confirmed.');
      }
      throw error;
    }
    const created = await db().query(`${INTERVIEW_SELECT} WHERE i.id = $1`, [interviewId]);
    hub.publish([workerId, job.employer_id], 'interview.updated', { type: 'interview', id: interviewId }, {
      jobId: job.id,
      status: 'PROPOSED',
    });
    res.status(201).json({ interview: interviewDto(created.rows[0]) });
  }),
);

router.get(
  '/interviews/me',
  authenticate,
  asyncHandler(async (req, res) => {
    const result = await db().query(
      `${INTERVIEW_SELECT}
        WHERE i.worker_id = $1 OR i.employer_id = $1
        ORDER BY i.scheduled_at DESC LIMIT 100`,
      [req.user!.id],
    );
    res.json({ items: result.rows.map(interviewDto) });
  }),
);

router.post(
  '/interviews/:id/decision',
  authenticate,
  asyncHandler(async (req, res) => {
    const body = parseBody(decisionInput, req.body);
    const updated = await withTransaction(async (tx) => {
      const result = await tx.query<{
        id: string;
        proposed_by: string;
        worker_id: string;
        employer_id: string;
        job_role: string;
      }>(
        `SELECT i.id, i.proposed_by, i.worker_id, i.employer_id, j.role AS job_role
           FROM interviews i JOIN jobs j ON j.id = i.job_id
          WHERE i.id = $1 AND i.status = 'PROPOSED'
            AND (i.worker_id = $2 OR i.employer_id = $2)
          FOR UPDATE`,
        [req.params.id, req.user!.id],
      );
      const interview = result.rows[0];
      if (!interview) {
        throw errors.conflict('INTERVIEW_NOT_DECIDABLE', 'This interview is not awaiting your decision.');
      }
      if (interview.proposed_by === req.user!.id) {
        throw errors.forbidden('Only the invited side can confirm or decline. You can cancel instead.');
      }
      await tx.query(
        `UPDATE interviews SET status = $1, updated_at = now() WHERE id = $2`,
        [body.decision, interview.id],
      );
      await notify(tx, {
        userId: interview.proposed_by,
        type: 'interview.decided',
        title: body.decision === 'CONFIRMED' ? 'Interview confirmed' : 'Interview declined',
        body:
          body.decision === 'CONFIRMED'
            ? `Your interview for "${interview.job_role}" was confirmed.`
            : `Your interview for "${interview.job_role}" was declined.`,
        resourceType: 'interview',
        resourceId: interview.id,
      });
      await recordAudit(tx, {
        actorId: req.user!.id,
        action: 'interview.decide',
        resourceType: 'interview',
        resourceId: interview.id,
        correlationId: req.requestId,
        metadata: { decision: body.decision },
      });
      return interview;
    });
    hub.publish([updated.worker_id, updated.employer_id], 'interview.updated', { type: 'interview', id: updated.id }, {
      status: body.decision,
    });
    res.json({ interviewId: updated.id, status: body.decision });
  }),
);

router.post(
  '/interviews/:id/cancel',
  authenticate,
  asyncHandler(async (req, res) => {
    const updated = await withTransaction(async (tx) => {
      const result = await tx.query<{
        id: string;
        worker_id: string;
        employer_id: string;
        job_role: string;
      }>(
        `SELECT i.id, i.worker_id, i.employer_id, j.role AS job_role
           FROM interviews i JOIN jobs j ON j.id = i.job_id
          WHERE i.id = $1 AND i.status IN ('PROPOSED', 'CONFIRMED')
            AND (i.worker_id = $2 OR i.employer_id = $2)
          FOR UPDATE`,
        [req.params.id, req.user!.id],
      );
      const interview = result.rows[0];
      if (!interview) throw errors.conflict('INTERVIEW_NOT_CANCELLABLE', 'This interview can no longer be cancelled.');
      await tx.query(
        `UPDATE interviews SET status = 'CANCELLED', updated_at = now() WHERE id = $1`,
        [interview.id],
      );
      const counterpart =
        interview.worker_id === req.user!.id ? interview.employer_id : interview.worker_id;
      await notify(tx, {
        userId: counterpart,
        type: 'interview.cancelled',
        title: 'Interview cancelled',
        body: `The interview for "${interview.job_role}" was cancelled.`,
        resourceType: 'interview',
        resourceId: interview.id,
      });
      await recordAudit(tx, {
        actorId: req.user!.id,
        action: 'interview.cancel',
        resourceType: 'interview',
        resourceId: interview.id,
        correlationId: req.requestId,
      });
      return interview;
    });
    hub.publish([updated.worker_id, updated.employer_id], 'interview.updated', { type: 'interview', id: updated.id }, {
      status: 'CANCELLED',
    });
    res.json({ interviewId: updated.id, status: 'CANCELLED' });
  }),
);

export default router;