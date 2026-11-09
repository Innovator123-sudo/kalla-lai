import { Router } from 'express';
import { z } from 'zod';
import { db, withTransaction } from '../db/index.js';
import { recordAudit } from '../lib/audit.js';
import { authenticate, requireStaff } from '../lib/auth.js';
import { newId } from '../lib/crypto.js';
import { errors } from '../lib/errors.js';
import { asyncHandler } from '../lib/http.js';
import { notify } from '../lib/notify.js';
import { parseBody } from '../lib/validation.js';
import { hub } from '../realtime.js';

const router = Router();

const reviewSchema = z.object({
  shiftId: z.string().uuid(),
  rating: z.number().int().min(1).max(5),
  text: z.string().max(2000).optional(),
});

async function shiftParticipants(shiftId: string, userId: string) {
  const result = await db().query<{
    id: string;
    worker_id: string;
    employer_id: string;
    status: string;
    role: string;
  }>(
    `SELECT s.id, s.worker_id, s.employer_id, s.status, j.role
       FROM shifts s JOIN jobs j ON j.id = s.job_id
      WHERE s.id = $1 AND (s.worker_id = $2 OR s.employer_id = $2)`,
    [shiftId, userId],
  );
  return result.rows[0];
}

router.post(
  '/reviews',
  authenticate,
  asyncHandler(async (req, res) => {
    const body = parseBody(reviewSchema, req.body);
    const result = await withTransaction(async (tx) => {
      const shift = await shiftParticipants(body.shiftId, req.user!.id);
      if (!shift) throw errors.notFound('Shift not found.');
      if (shift.status !== 'COMPLETED') {
        throw errors.conflict('SHIFT_NOT_COMPLETED', 'Reviews can only be submitted after a completed shift.');
      }
      const recipientId = shift.worker_id === req.user!.id ? shift.employer_id : shift.worker_id;
      const reviewId = newId();
      try {
        await tx.query(
          `INSERT INTO reviews (id, shift_id, author_id, recipient_id, rating, text)
           VALUES ($1, $2, $3, $4, $5, $6)`,
          [reviewId, shift.id, req.user!.id, recipientId, body.rating, body.text ?? null],
        );
      } catch (error) {
        if ((error as { code?: string }).code === '23505') {
          throw errors.conflict('REVIEW_ALREADY_SUBMITTED', 'You already reviewed this shift.');
        }
        throw error;
      }
      const counterpart = await tx.query<{ id: string }>(
        `SELECT id FROM reviews WHERE shift_id = $1 AND author_id = $2`,
        [shift.id, recipientId],
      );
      let revealed = false;
      if (counterpart.rows[0]) {
        revealed = true;
        await tx.query(
          `UPDATE reviews SET revealed_at = now() WHERE shift_id = $1 AND revealed_at IS NULL`,
          [shift.id],
        );
      }
      await notify(tx, {
        userId: recipientId,
        type: 'review.submitted',
        title: 'New review',
        body: revealed
          ? 'A review was submitted and both reviews are now visible.'
          : 'A review was submitted. It stays hidden until you review the same shift or seven days pass.',
        resourceType: 'shift',
        resourceId: shift.id,
      });
      await recordAudit(tx, {
        actorId: req.user!.id,
        action: 'review.create',
        resourceType: 'review',
        resourceId: reviewId,
        correlationId: req.requestId,
        metadata: { shiftId: shift.id, revealed },
      });
      return { reviewId, recipientId, revealed };
    });

    hub.publish([result.recipientId], 'review.created', { type: 'review', id: result.reviewId }, {
      shiftId: body.shiftId,
      revealed: result.revealed,
    });
    res.status(201).json({ reviewId: result.reviewId, revealed: result.revealed });
  }),
);

router.get(
  '/reviews/me',
  authenticate,
  asyncHandler(async (req, res) => {
    const [received, authored] = await Promise.all([
      db().query(
        `SELECT r.id, r.shift_id, r.rating, r.text, r.revealed_at, r.created_at,
                j.role, u.full_name AS author_name
           FROM reviews r
           JOIN shifts s ON s.id = r.shift_id
           JOIN jobs j ON j.id = s.job_id
           JOIN users u ON u.id = r.author_id
          WHERE r.recipient_id = $1 ORDER BY r.created_at DESC LIMIT 100`,
        [req.user!.id],
      ),
      db().query(
        `SELECT r.id, r.shift_id, r.rating, r.text, r.revealed_at, r.created_at, j.role
           FROM reviews r
           JOIN shifts s ON s.id = r.shift_id
           JOIN jobs j ON j.id = s.job_id
          WHERE r.author_id = $1 ORDER BY r.created_at DESC LIMIT 100`,
        [req.user!.id],
      ),
    ]);
    res.json({
      received: received.rows.map((row) => ({
        ...row,
        rating: row.revealed_at ? row.rating : null,
        text: row.revealed_at ? row.text : null,
        pendingReveal: !row.revealed_at,
      })),
      authored: authored.rows,
    });
  }),
);

router.get(
  '/shifts/:id/reviews',
  authenticate,
  asyncHandler(async (req, res) => {
    const shift = await shiftParticipants(req.params.id, req.user!.id);
    if (!shift) throw errors.notFound('Shift not found.');
    const result = await db().query(
      `SELECT r.*, u.full_name AS author_name FROM reviews r JOIN users u ON u.id = r.author_id
        WHERE r.shift_id = $1`,
      [shift.id],
    );
    res.json({
      items: result.rows.map((row) => {
        const mine = row.author_id === req.user!.id;
        const visible = mine || row.revealed_at !== null;
        return {
          ...row,
          rating: visible ? row.rating : null,
          text: visible ? row.text : null,
          pendingReveal: !visible,
        };
      }),
    });
  }),
);

/* ------------------------------- inbox -------------------------------- */

router.get(
  '/notifications',
  authenticate,
  asyncHandler(async (req, res) => {
    const unreadOnly = req.query.unreadOnly === 'true';
    const limit = Math.min(Number(req.query.limit ?? 50) || 50, 100);
    const result = await db().query(
      `SELECT id, type, title, body, resource_type, resource_id, read_at, created_at
         FROM notifications
        WHERE user_id = $1 AND ($2::boolean = false OR read_at IS NULL)
        ORDER BY created_at DESC LIMIT $3`,
      [req.user!.id, unreadOnly, limit],
    );
    res.json({ items: result.rows, unreadCount: result.rows.filter((row) => !row.read_at).length });
  }),
);

router.post(
  '/notifications/:id/read',
  authenticate,
  asyncHandler(async (req, res) => {
    const result = await db().query(
      `UPDATE notifications SET read_at = now() WHERE id = $1 AND user_id = $2 RETURNING id`,
      [req.params.id, req.user!.id],
    );
    if (!result.rows[0]) throw errors.notFound('Notification not found.');
    res.json({ notificationId: req.params.id, read: true });
  }),
);

router.post(
  '/notifications/read-all',
  authenticate,
  asyncHandler(async (req, res) => {
    await db().query(
      `UPDATE notifications SET read_at = now() WHERE user_id = $1 AND read_at IS NULL`,
      [req.user!.id],
    );
    res.json({ read: true });
  }),
);

/* ------------------------------- admin -------------------------------- */

router.get(
  '/admin/audit-events',
  authenticate,
  requireStaff,
  asyncHandler(async (req, res) => {
    const limit = Math.min(Number(req.query.limit ?? 100) || 100, 500);
    const action = typeof req.query.action === 'string' ? req.query.action : null;
    const result = await db().query(
      `SELECT id, actor_id, action, resource_type, resource_id, outcome, correlation_id, metadata, created_at
         FROM audit_events
        WHERE ($1::text IS NULL OR action = $1)
        ORDER BY created_at DESC LIMIT $2`,
      [action, limit],
    );
    res.json({ items: result.rows });
  }),
);

router.get(
  '/admin/stats',
  authenticate,
  requireStaff,
  asyncHandler(async (_req, res) => {
    const result = await db().query<{
      users: string;
      jobs: string;
      published_jobs: string;
      shifts: string;
      invoices: string;
      disputes_open: string;
    }>(
      `SELECT
         (SELECT count(*) FROM users) AS users,
         (SELECT count(*) FROM jobs) AS jobs,
         (SELECT count(*) FROM jobs WHERE status = 'PUBLISHED') AS published_jobs,
         (SELECT count(*) FROM shifts) AS shifts,
         (SELECT count(*) FROM invoices) AS invoices,
         (SELECT count(*) FROM disputes WHERE status IN ('OPEN', 'UNDER_REVIEW')) AS disputes_open`,
    );
    const row = result.rows[0]!;
    res.json({
      users: Number(row.users),
      jobs: Number(row.jobs),
      publishedJobs: Number(row.published_jobs),
      shifts: Number(row.shifts),
      invoices: Number(row.invoices),
      openDisputes: Number(row.disputes_open),
    });
  }),
);

/**
 * Double-blind reviews reveal after seven days even if the counterpart never
 * submits. A scheduler (CronJob in production) calls this endpoint.
 */
router.post(
  '/admin/reviews/reveal-due',
  authenticate,
  requireStaff,
  asyncHandler(async (_req, res) => {
    const result = await db().query<{ id: string }>(
      `UPDATE reviews SET revealed_at = now()
        WHERE revealed_at IS NULL AND created_at < now() - interval '7 days'
        RETURNING id`,
    );
    res.json({ revealed: result.rows.length });
  }),
);

export default router;
