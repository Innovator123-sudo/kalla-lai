import { Router } from 'express';
import { z } from 'zod';
import { db, withTransaction } from '../db/index.js';
import { recordAudit } from '../lib/audit.js';
import { authenticate, requireEmployer, requireWorker } from '../lib/auth.js';
import { newId } from '../lib/crypto.js';
import { errors } from '../lib/errors.js';
import { asyncHandler } from '../lib/http.js';
import { notify } from '../lib/notify.js';
import { invoiceDto, shiftDto } from '../lib/serializers.js';
import { parseBody } from '../lib/validation.js';
import { hub } from '../realtime.js';

const router = Router();

const completionSchema = z.object({
  note: z.string().max(2000).optional(),
  evidenceRef: z.string().max(300).optional(),
});

const attendanceSchema = z.object({
  eventType: z.enum(['ON_MY_WAY', 'ARRIVED', 'STARTED', 'COMPLETED']),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
});

const messageSchema = z.object({ body: z.string().min(1).max(4000) });

const SHIFT_JOINS = `
  FROM shifts s
  JOIN jobs j ON j.id = s.job_id
  JOIN employer_profiles ep ON ep.user_id = s.employer_id
  JOIN worker_profiles wp ON wp.user_id = s.worker_id
  LEFT JOIN invoices i ON i.shift_id = s.id`;

async function shiftForParticipant(id: string, userId: string) {
  const result = await db().query(
    `SELECT s.*, j.role, j.area, j.address, j.latitude, j.longitude, j.required_skills,
            i.id AS invoice_id, i.status AS invoice_status,
            i.amount_npr AS invoice_amount_npr, i.currency AS invoice_currency,
            CASE WHEN s.worker_id = $2 THEN ep.display_name ELSE wp.public_name END AS counterpart_name,
            CASE WHEN s.worker_id = $2 THEN ep.trust_status ELSE wp.verification_status END AS counterpart_verified
       ${SHIFT_JOINS}
      WHERE s.id = $1 AND (s.worker_id = $2 OR s.employer_id = $2)`,
    [id, userId],
  );
  return result.rows[0];
}

router.get(
  '/shifts/me',
  authenticate,
  asyncHandler(async (req, res) => {
    const result = await db().query(
      `SELECT s.*, j.role, j.area, j.address, j.latitude, j.longitude, j.required_skills,
              i.id AS invoice_id, i.status AS invoice_status,
              i.amount_npr AS invoice_amount_npr, i.currency AS invoice_currency,
              CASE WHEN s.worker_id = $1 THEN ep.display_name ELSE wp.public_name END AS counterpart_name,
              CASE WHEN s.worker_id = $1 THEN ep.trust_status ELSE wp.verification_status END AS counterpart_verified
         ${SHIFT_JOINS}
        WHERE s.worker_id = $1 OR s.employer_id = $1
        ORDER BY s.starts_at DESC LIMIT 100`,
      [req.user!.id],
    );
    res.json({ items: result.rows.map(shiftDto) });
  }),
);

router.get(
  '/shifts/:id',
  authenticate,
  asyncHandler(async (req, res) => {
    const shift = await shiftForParticipant(req.params.id, req.user!.id);
    if (!shift) throw errors.notFound('Shift not found.');
    res.json({ shift: shiftDto(shift) });
  }),
);

router.post(
  '/shifts/:id/on-my-way',
  authenticate,
  requireWorker,
  asyncHandler(async (req, res) => {
    const shift = await withTransaction(async (tx) => {
      const result = await tx.query<{ id: string; employer_id: string; worker_id: string; status: string; role: string }>(
        `SELECT s.id, s.employer_id, s.worker_id, s.status, j.role
           FROM shifts s JOIN jobs j ON j.id = s.job_id
          WHERE s.id = $1 AND s.worker_id = $2 FOR UPDATE`,
        [req.params.id, req.user!.id],
      );
      const row = result.rows[0];
      if (!row) throw errors.notFound('Shift not found.');
      if (!['ACCEPTED', 'CONFIRMED'].includes(row.status)) {
        throw errors.conflict('SHIFT_STATE_CONFLICT', 'This shift can no longer be started from its current state.');
      }
      await tx.query(
        `UPDATE shifts SET status = 'ON_THE_WAY', on_my_way_at = now(), updated_at = now() WHERE id = $1`,
        [row.id],
      );
      await tx.query(
        `INSERT INTO attendance_events (id, shift_id, worker_id, event_type) VALUES ($1, $2, $3, 'ON_MY_WAY')`,
        [newId(), row.id, row.worker_id],
      );
      await notify(tx, {
        userId: row.employer_id,
        type: 'shift.on_the_way',
        title: 'Worker is on the way',
        body: `The worker has started commuting for "${row.role}".`,
        resourceType: 'shift',
        resourceId: row.id,
      });
      await recordAudit(tx, {
        actorId: req.user!.id,
        action: 'shift.on_my_way',
        resourceType: 'shift',
        resourceId: row.id,
        correlationId: req.requestId,
      });
      return row;
    });
    hub.publish([shift.employer_id, shift.worker_id], 'shift.status.updated', { type: 'shift', id: shift.id }, {
      status: 'ON_THE_WAY',
    });
    res.json({ shift: shiftDto(await shiftForParticipant(shift.id, req.user!.id)) });
  }),
);

router.post(
  '/shifts/:id/start',
  authenticate,
  requireWorker,
  asyncHandler(async (req, res) => {
    const shift = await withTransaction(async (tx) => {
      const result = await tx.query<{ id: string; employer_id: string; worker_id: string; status: string; role: string }>(
        `SELECT s.id, s.employer_id, s.worker_id, s.status, j.role
           FROM shifts s JOIN jobs j ON j.id = s.job_id
          WHERE s.id = $1 AND s.worker_id = $2 FOR UPDATE`,
        [req.params.id, req.user!.id],
      );
      const row = result.rows[0];
      if (!row) throw errors.notFound('Shift not found.');
      if (row.status !== 'ON_THE_WAY') {
        throw errors.conflict('SHIFT_STATE_CONFLICT', 'Mark yourself on the way before starting the shift.');
      }
      await tx.query(
        `UPDATE shifts SET status = 'IN_PROGRESS', started_at = now(), updated_at = now() WHERE id = $1`,
        [row.id],
      );
      await tx.query(
        `INSERT INTO attendance_events (id, shift_id, worker_id, event_type) VALUES ($1, $2, $3, 'STARTED')`,
        [newId(), row.id, row.worker_id],
      );
      await notify(tx, {
        userId: row.employer_id,
        type: 'shift.started',
        title: 'Shift started',
        body: `Work has started for "${row.role}".`,
        resourceType: 'shift',
        resourceId: row.id,
      });
      await recordAudit(tx, {
        actorId: req.user!.id,
        action: 'shift.start',
        resourceType: 'shift',
        resourceId: row.id,
        correlationId: req.requestId,
      });
      return row;
    });
    hub.publish([shift.employer_id, shift.worker_id], 'shift.status.updated', { type: 'shift', id: shift.id }, {
      status: 'IN_PROGRESS',
    });
    res.json({ shift: shiftDto(await shiftForParticipant(shift.id, req.user!.id)) });
  }),
);

router.post(
  '/shifts/:id/completion',
  authenticate,
  requireWorker,
  asyncHandler(async (req, res) => {
    const body = parseBody(completionSchema, req.body ?? {});
    const shift = await withTransaction(async (tx) => {
      const result = await tx.query<{ id: string; employer_id: string; worker_id: string; status: string; role: string }>(
        `SELECT s.id, s.employer_id, s.worker_id, s.status, j.role
           FROM shifts s JOIN jobs j ON j.id = s.job_id
          WHERE s.id = $1 AND s.worker_id = $2 FOR UPDATE`,
        [req.params.id, req.user!.id],
      );
      const row = result.rows[0];
      if (!row) throw errors.notFound('Shift not found.');
      if (row.status !== 'IN_PROGRESS') {
        throw errors.conflict('SHIFT_STATE_CONFLICT', 'Completion can only be submitted for an active shift.');
      }
      await tx.query(
        `UPDATE shifts SET status = 'COMPLETION_SUBMITTED', completion_submitted_at = now(),
                completion_note = $2, updated_at = now()
          WHERE id = $1`,
        [row.id, body.note ?? null],
      );
      await tx.query(
        `INSERT INTO attendance_events (id, shift_id, worker_id, event_type) VALUES ($1, $2, $3, 'COMPLETED')`,
        [newId(), row.id, row.worker_id],
      );
      await notify(tx, {
        userId: row.employer_id,
        type: 'shift.completion_submitted',
        title: 'Completion submitted',
        body: `The worker submitted completion for "${row.role}". Review it to issue the invoice.`,
        resourceType: 'shift',
        resourceId: row.id,
      });
      await recordAudit(tx, {
        actorId: req.user!.id,
        action: 'shift.completion_submit',
        resourceType: 'shift',
        resourceId: row.id,
        correlationId: req.requestId,
        metadata: { hasNote: Boolean(body.note) },
      });
      return row;
    });
    hub.publish([shift.employer_id, shift.worker_id], 'shift.status.updated', { type: 'shift', id: shift.id }, {
      status: 'COMPLETION_SUBMITTED',
    });
    res.json({ shift: shiftDto(await shiftForParticipant(shift.id, req.user!.id)) });
  }),
);

router.post(
  '/shifts/:id/approve',
  authenticate,
  requireEmployer,
  asyncHandler(async (req, res) => {
    const outcome = await withTransaction(async (tx) => {
      const result = await tx.query<{
        id: string;
        employer_id: string;
        worker_id: string;
        status: string;
        role: string;
        starts_at: Date;
        ends_at: Date;
        offer_rate: string | null;
        job_rate: string;
        currency: string;
      }>(
        `SELECT s.id, s.employer_id, s.worker_id, s.status, j.role, s.starts_at, s.ends_at,
                o.rate_npr AS offer_rate, j.rate_npr AS job_rate, j.currency
           FROM shifts s
           JOIN jobs j ON j.id = s.job_id
           LEFT JOIN offers o ON o.id = s.offer_id
          WHERE s.id = $1 AND s.employer_id = $2 FOR UPDATE OF s`,
        [req.params.id, req.user!.id],
      );
      const row = result.rows[0];
      if (!row) throw errors.notFound('Shift not found.');
      if (!['COMPLETION_SUBMITTED', 'UNDER_REVIEW'].includes(row.status)) {
        throw errors.conflict('SHIFT_STATE_CONFLICT', 'There is no submitted completion to approve.');
      }
      await tx.query(
        `UPDATE shifts SET status = 'COMPLETED', approved_at = now(), updated_at = now() WHERE id = $1`,
        [row.id],
      );
      const hours =
        Math.round(
          ((new Date(row.ends_at).getTime() - new Date(row.starts_at).getTime()) / 3_600_000) * 100,
        ) / 100;
      const amount = Number(row.offer_rate ?? row.job_rate);
      const invoiceId = newId();
      const reviewDue = new Date(Date.now() + 48 * 60 * 60 * 1000);
      await tx.query(
        `INSERT INTO invoices
           (id, shift_id, employer_id, worker_id, hours, rate_npr, amount_npr, currency, review_due_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
        [invoiceId, row.id, row.employer_id, row.worker_id, hours, amount, amount, row.currency, reviewDue.toISOString()],
      );
      await notify(tx, {
        userId: row.worker_id,
        type: 'invoice.issued',
        title: 'Invoice issued',
        body: `Your invoice for "${row.role}" is awaiting employer review.`,
        resourceType: 'invoice',
        resourceId: invoiceId,
      });
      await recordAudit(tx, {
        actorId: req.user!.id,
        action: 'shift.approve',
        resourceType: 'shift',
        resourceId: row.id,
        correlationId: req.requestId,
        metadata: { invoiceId },
      });
      return { shiftId: row.id, invoiceId, workerId: row.worker_id, amount };
    });

    const invoice = await db().query('SELECT * FROM invoices WHERE id = $1', [outcome.invoiceId]);
    hub.publish([outcome.workerId], 'invoice.issued', { type: 'invoice', id: outcome.invoiceId }, {
      shiftId: outcome.shiftId,
      amountNpr: outcome.amount,
    });
    hub.publish([outcome.workerId], 'shift.status.updated', { type: 'shift', id: outcome.shiftId }, {
      status: 'COMPLETED',
    });
    res.json({
      shift: shiftDto(await shiftForParticipant(outcome.shiftId, req.user!.id)),
      invoice: invoiceDto(invoice.rows[0]),
    });
  }),
);

router.post(
  '/shifts/:id/attendance',
  authenticate,
  requireWorker,
  asyncHandler(async (req, res) => {
    const body = parseBody(attendanceSchema, req.body);
    if ((body.latitude === undefined) !== (body.longitude === undefined)) {
      throw errors.badRequest('LOCATION_INCOMPLETE', 'Provide both latitude and longitude, or neither.');
    }
    const shift = await db().query<{ id: string; status: string }>(
      'SELECT id, status FROM shifts WHERE id = $1 AND worker_id = $2',
      [req.params.id, req.user!.id],
    );
    const row = shift.rows[0];
    if (!row) throw errors.notFound('Shift not found.');
    if (!['ON_THE_WAY', 'IN_PROGRESS'].includes(row.status)) {
      throw errors.conflict('SHIFT_NOT_ACTIVE', 'Attendance can only be recorded during an active shift.');
    }
    const id = newId();
    await withTransaction(async (tx) => {
      await tx.query(
        `INSERT INTO attendance_events (id, shift_id, worker_id, event_type, latitude, longitude)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [id, row.id, req.user!.id, body.eventType, body.latitude ?? null, body.longitude ?? null],
      );
      await recordAudit(tx, {
        actorId: req.user!.id,
        action: 'shift.attendance',
        resourceType: 'shift',
        resourceId: row.id,
        correlationId: req.requestId,
        metadata: { eventType: body.eventType, hasLocation: body.latitude !== undefined },
      });
    });
    res.status(201).json({ attendanceEventId: id, eventType: body.eventType });
  }),
);

router.get(
  '/shifts/:id/messages',
  authenticate,
  asyncHandler(async (req, res) => {
    const shift = await shiftForParticipant(req.params.id, req.user!.id);
    if (!shift) throw errors.notFound('Shift not found.');
    const result = await db().query(
      `SELECT m.id, m.sender_id, m.body, m.created_at FROM messages m
        WHERE m.shift_id = $1 ORDER BY m.created_at ASC LIMIT 200`,
      [shift.id],
    );
    res.json({ items: result.rows });
  }),
);

router.post(
  '/shifts/:id/messages',
  authenticate,
  asyncHandler(async (req, res) => {
    const body = parseBody(messageSchema, req.body);
    const shift = await shiftForParticipant(req.params.id, req.user!.id);
    if (!shift) throw errors.notFound('Shift not found.');
    const id = newId();
    await withTransaction(async (tx) => {
      await tx.query(
        `INSERT INTO messages (id, shift_id, sender_id, body) VALUES ($1, $2, $3, $4)`,
        [id, shift.id, req.user!.id, body.body.trim()],
      );
      const recipient =
        shift.worker_id === req.user!.id ? shift.employer_id : shift.worker_id;
      await notify(tx, {
        userId: recipient,
        type: 'message.created',
        title: 'New message',
        body: 'You have a new shift message. Open the app to read it.',
        resourceType: 'shift',
        resourceId: shift.id,
      });
      await recordAudit(tx, {
        actorId: req.user!.id,
        action: 'message.create',
        resourceType: 'shift',
        resourceId: shift.id,
        correlationId: req.requestId,
      });
    });
    const message = await db().query('SELECT * FROM messages WHERE id = $1', [id]);
    hub.publish([shift.worker_id, shift.employer_id], 'message.created', { type: 'shift', id: shift.id }, {
      messageId: id,
      senderId: req.user!.id,
    });
    res.status(201).json({ message: message.rows[0] });
  }),
);

export default router;
