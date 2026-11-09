import { Router } from 'express';
import { z } from 'zod';
import { config } from '../config.js';
import { db, withTransaction } from '../db/index.js';
import { recordAudit } from '../lib/audit.js';
import { authenticate, requireRoles, requireStaff, requireWorker } from '../lib/auth.js';
import { hmac, newId, safeEqual } from '../lib/crypto.js';
import { errors } from '../lib/errors.js';
import { asyncHandler } from '../lib/http.js';
import { notify } from '../lib/notify.js';
import { invoiceDto } from '../lib/serializers.js';
import { parseBody } from '../lib/validation.js';
import { idempotent } from '../lib/validation.js';
import { hub } from '../realtime.js';

const router = Router();

const disputeSchema = z.object({
  reason: z.string().min(10).max(2000),
  evidenceRef: z.string().max(300).optional(),
});

const resolveSchema = z.object({
  resolution: z.string().min(5).max(2000),
  outcome: z.enum(['RESOLVED', 'REJECTED']),
});

const webhookSchema = z.object({
  provider: z.literal('DEMO'),
  providerEventId: z.string().min(6).max(200),
  type: z.literal('payment.settled'),
  transactionId: z.string().uuid(),
  amountNpr: z.number().int().positive(),
  providerRef: z.string().max(200).optional(),
});

async function invoiceForParticipant(id: string, userId: string) {
  const result = await db().query(
    `SELECT i.*, j.role, ep.display_name AS employer_name, wp.public_name AS worker_name
       FROM invoices i
       JOIN shifts s ON s.id = i.shift_id
       JOIN jobs j ON j.id = s.job_id
       JOIN employer_profiles ep ON ep.user_id = i.employer_id
       JOIN worker_profiles wp ON wp.user_id = i.worker_id
      WHERE i.id = $1 AND (i.employer_id = $2 OR i.worker_id = $2)`,
    [id, userId],
  );
  return result.rows[0];
}

router.get(
  '/invoices/me',
  authenticate,
  asyncHandler(async (req, res) => {
    const result = await db().query(
      `SELECT i.*, j.role FROM invoices i
        JOIN shifts s ON s.id = i.shift_id
        JOIN jobs j ON j.id = s.job_id
       WHERE i.employer_id = $1 OR i.worker_id = $1
       ORDER BY i.created_at DESC LIMIT 100`,
      [req.user!.id],
    );
    res.json({ items: result.rows.map(invoiceDto) });
  }),
);

router.get(
  '/invoices/:id',
  authenticate,
  asyncHandler(async (req, res) => {
    const invoice = await invoiceForParticipant(req.params.id, req.user!.id);
    if (!invoice) throw errors.notFound('Invoice not found.');
    const ledger = await db().query(
      `SELECT id, entry_type, amount_npr, currency, description, created_at
         FROM ledger_entries WHERE invoice_id = $1 ORDER BY created_at`,
      [invoice.id],
    );
    const disputes = await db().query(
      `SELECT id, raised_by, reason, status, resolution, created_at, resolved_at
         FROM disputes WHERE invoice_id = $1 ORDER BY created_at DESC`,
      [invoice.id],
    );
    res.json({ invoice: invoiceDto(invoice), ledger: ledger.rows, disputes: disputes.rows });
  }),
);

router.post(
  '/invoices/:id/approve',
  authenticate,
  requireRoles('EMPLOYER'),
  asyncHandler(async (req, res) => {
    const invoiceId = req.params.id;
    const result = await idempotent(req, `POST /v1/invoices/${invoiceId}/approve`, async (tx) => {
      const invoiceResult = await tx.query<{
        id: string;
        employer_id: string;
        worker_id: string;
        amount_npr: string;
        currency: string;
        status: string;
        role: string;
      }>(
        `SELECT i.id, i.employer_id, i.worker_id, i.amount_npr, i.currency, i.status, j.role
           FROM invoices i JOIN shifts s ON s.id = i.shift_id JOIN jobs j ON j.id = s.job_id
          WHERE i.id = $1 FOR UPDATE`,
        [invoiceId],
      );
      const invoice = invoiceResult.rows[0];
      if (!invoice) throw errors.notFound('Invoice not found.');
      if (invoice.employer_id !== req.user!.id) throw errors.forbidden();
      if (
        !['AWAITING_EMPLOYER_REVIEW', 'REMINDER_SENT', 'ESCALATED', 'FLAGGED_UNPAID'].includes(
          invoice.status,
        )
      ) {
        throw errors.conflict('INVOICE_NOT_APPROVABLE', 'This invoice cannot be approved in its current state.');
      }
      const transactionId = newId();
      await tx.query(
        `UPDATE invoices SET status = 'SETTLEMENT_PROCESSING', updated_at = now() WHERE id = $1`,
        [invoice.id],
      );
      await tx.query(
        `INSERT INTO payment_transactions
           (id, invoice_id, provider, amount_npr, currency, status, idempotency_key)
         VALUES ($1, $2, 'DEMO', $3, $4, 'PROCESSING', $5)`,
        [
          transactionId,
          invoice.id,
          invoice.amount_npr,
          invoice.currency,
          req.header('idempotency-key') ?? transactionId,
        ],
      );
      await tx.query(
        `INSERT INTO ledger_entries (id, invoice_id, entry_type, amount_npr, currency, description)
         VALUES ($1, $2, 'HOLD', $3, $4, 'Shift payment approved and queued for settlement')`,
        [newId(), invoice.id, invoice.amount_npr, invoice.currency],
      );
      await notify(tx, {
        userId: invoice.worker_id,
        type: 'payment.status.updated',
        title: 'Payment processing',
        body: `The employer approved your invoice for "${invoice.role}". Settlement is processing.`,
        resourceType: 'invoice',
        resourceId: invoice.id,
      });
      await recordAudit(tx, {
        actorId: req.user!.id,
        action: 'invoice.approve',
        resourceType: 'invoice',
        resourceId: invoice.id,
        correlationId: req.requestId,
        metadata: { amountNpr: Number(invoice.amount_npr), transactionId },
      });
      return {
        status: 200,
        body: {
          invoiceId: invoice.id,
          transactionId,
          workerId: invoice.worker_id,
          status: 'SETTLEMENT_PROCESSING',
        },
      };
    });

    const workerId = (result.body as { workerId: string }).workerId;
    hub.publish([workerId], 'payment.status.updated', { type: 'invoice', id: invoiceId }, {
      status: 'SETTLEMENT_PROCESSING',
    });
    res.json(result.body);
  }),
);

router.post(
  '/invoices/:id/remind',
  authenticate,
  requireWorker,
  asyncHandler(async (req, res) => {
    const result = await withTransaction(async (tx) => {
      const invoiceResult = await tx.query<{
        id: string;
        employer_id: string;
        status: string;
        amount_npr: string;
        role: string;
      }>(
        `UPDATE invoices i SET status = 'REMINDER_SENT', reminder_sent_at = now(), updated_at = now()
           FROM shifts s, jobs j
          WHERE s.id = i.shift_id AND j.id = s.job_id
            AND i.id = $1 AND i.worker_id = $2 AND i.status = 'AWAITING_EMPLOYER_REVIEW'
          RETURNING i.id, i.employer_id, i.status, i.amount_npr, j.role`,
        [req.params.id, req.user!.id],
      );
      const invoice = invoiceResult.rows[0];
      if (!invoice) {
        throw errors.conflict('INVOICE_NOT_REMINDABLE', 'This invoice cannot be reminded in its current state.');
      }
      await notify(tx, {
        userId: invoice.employer_id,
        type: 'invoice.reminder',
        title: 'Invoice awaiting review',
        body: `Please review the invoice for "${invoice.role}".`,
        resourceType: 'invoice',
        resourceId: invoice.id,
      });
      await recordAudit(tx, {
        actorId: req.user!.id,
        action: 'invoice.remind',
        resourceType: 'invoice',
        resourceId: invoice.id,
        correlationId: req.requestId,
      });
      return invoice;
    });
    hub.publish([result.employer_id], 'payment.status.updated', { type: 'invoice', id: result.id }, {
      status: 'REMINDER_SENT',
    });
    res.json({ invoiceId: result.id, status: 'REMINDER_SENT' });
  }),
);

router.post(
  '/invoices/:id/flag-unpaid',
  authenticate,
  requireWorker,
  asyncHandler(async (req, res) => {
    const invoice = await withTransaction(async (tx) => {
      const invoiceResult = await tx.query<{
        id: string;
        employer_id: string;
        status: string;
        review_due_at: Date;
        amount_npr: string;
        role: string;
      }>(
        `SELECT i.id, i.employer_id, i.status, i.review_due_at, i.amount_npr, j.role
           FROM invoices i JOIN shifts s ON s.id = i.shift_id JOIN jobs j ON j.id = s.job_id
          WHERE i.id = $1 AND i.worker_id = $2 FOR UPDATE`,
        [req.params.id, req.user!.id],
      );
      const row = invoiceResult.rows[0];
      if (!row) throw errors.notFound('Invoice not found.');
      if (!['AWAITING_EMPLOYER_REVIEW', 'REMINDER_SENT', 'ESCALATED'].includes(row.status)) {
        throw errors.conflict('INVOICE_NOT_FLAGGABLE', 'This invoice cannot be flagged in its current state.');
      }
      if (new Date(row.review_due_at).getTime() > Date.now()) {
        throw errors.conflict(
          'REVIEW_WINDOW_OPEN',
          'The 48-hour employer review window has not elapsed yet.',
        );
      }
      await tx.query(
        `UPDATE invoices SET status = 'FLAGGED_UNPAID', escalated_at = now(), updated_at = now() WHERE id = $1`,
        [row.id],
      );
      await notify(tx, {
        userId: row.employer_id,
        type: 'invoice.flagged_unpaid',
        title: 'Unpaid work flagged',
        body: `The worker flagged unpaid work for "${row.role}". Resolve it or open a dispute.`,
        resourceType: 'invoice',
        resourceId: row.id,
      });
      await recordAudit(tx, {
        actorId: req.user!.id,
        action: 'invoice.flag_unpaid',
        resourceType: 'invoice',
        resourceId: row.id,
        correlationId: req.requestId,
      });
      return row;
    });
    hub.publish([invoice.employer_id], 'payment.status.updated', { type: 'invoice', id: invoice.id }, {
      status: 'FLAGGED_UNPAID',
    });
    res.json({ invoiceId: invoice.id, status: 'FLAGGED_UNPAID' });
  }),
);

router.post(
  '/invoices/:id/dispute',
  authenticate,
  asyncHandler(async (req, res) => {
    const body = parseBody(disputeSchema, req.body);
    const disputeId = newId();
    const dispute = await withTransaction(async (tx) => {
      const invoiceResult = await tx.query<{
        id: string;
        employer_id: string;
        worker_id: string;
        status: string;
        role: string;
      }>(
        `SELECT i.id, i.employer_id, i.worker_id, i.status, j.role
           FROM invoices i JOIN shifts s ON s.id = i.shift_id JOIN jobs j ON j.id = s.job_id
          WHERE i.id = $1 AND (i.employer_id = $2 OR i.worker_id = $2) FOR UPDATE`,
        [req.params.id, req.user!.id],
      );
      const invoice = invoiceResult.rows[0];
      if (!invoice) throw errors.notFound('Invoice not found.');
      if (['PAID', 'REFUNDED'].includes(invoice.status)) {
        throw errors.conflict('INVOICE_ALREADY_SETTLED', 'Settled invoices cannot be disputed.');
      }
      await tx.query(
        `INSERT INTO disputes (id, invoice_id, raised_by, reason, evidence_ref)
         VALUES ($1, $2, $3, $4, $5)`,
        [disputeId, invoice.id, req.user!.id, body.reason, body.evidenceRef ?? null],
      );
      await tx.query(`UPDATE invoices SET status = 'DISPUTED', updated_at = now() WHERE id = $1`, [
        invoice.id,
      ]);
      const other = invoice.worker_id === req.user!.id ? invoice.employer_id : invoice.worker_id;
      await notify(tx, {
        userId: other,
        type: 'dispute.created',
        title: 'Dispute opened',
        body: `A dispute was opened for "${invoice.role}". Support will review it.`,
        resourceType: 'dispute',
        resourceId: disputeId,
      });
      await recordAudit(tx, {
        actorId: req.user!.id,
        action: 'dispute.create',
        resourceType: 'dispute',
        resourceId: disputeId,
        correlationId: req.requestId,
        metadata: { invoiceId: invoice.id },
      });
      return { invoice, disputeId };
    });
    hub.publish([dispute.invoice.worker_id, dispute.invoice.employer_id], 'dispute.status.updated', {
      type: 'dispute',
      id: disputeId,
    }, { status: 'OPEN' });
    res.status(201).json({ disputeId, status: 'OPEN' });
  }),
);

router.get(
  '/disputes/me',
  authenticate,
  asyncHandler(async (req, res) => {
    const result = await db().query(
      `SELECT d.*, i.amount_npr, i.currency, j.role
         FROM disputes d
         JOIN invoices i ON i.id = d.invoice_id
         JOIN shifts s ON s.id = i.shift_id
         JOIN jobs j ON j.id = s.job_id
        WHERE i.employer_id = $1 OR i.worker_id = $1
        ORDER BY d.created_at DESC LIMIT 100`,
      [req.user!.id],
    );
    res.json({ items: result.rows });
  }),
);

router.get(
  '/disputes',
  authenticate,
  requireStaff,
  asyncHandler(async (req, res) => {
    const result = await db().query(
      `SELECT d.*, i.amount_npr, i.currency, j.role,
              ep.display_name AS employer_name, wp.public_name AS worker_name
         FROM disputes d
         JOIN invoices i ON i.id = d.invoice_id
         JOIN shifts s ON s.id = i.shift_id
         JOIN jobs j ON j.id = s.job_id
         JOIN employer_profiles ep ON ep.user_id = i.employer_id
         JOIN worker_profiles wp ON wp.user_id = i.worker_id
        WHERE ($1::text IS NULL OR d.status = $1)
        ORDER BY d.created_at ASC LIMIT 100`,
      [req.query.status ?? null],
    );
    res.json({ items: result.rows });
  }),
);

router.post(
  '/disputes/:id/resolve',
  authenticate,
  requireStaff,
  asyncHandler(async (req, res) => {
    const body = parseBody(resolveSchema, req.body);
    const resolved = await withTransaction(async (tx) => {
      const disputeResult = await tx.query<{
        id: string;
        invoice_id: string;
        status: string;
        employer_id: string;
        worker_id: string;
        role: string;
      }>(
        `SELECT d.id, d.invoice_id, d.status, i.employer_id, i.worker_id, j.role
           FROM disputes d
           JOIN invoices i ON i.id = d.invoice_id
           JOIN shifts s ON s.id = i.shift_id
           JOIN jobs j ON j.id = s.job_id
          WHERE d.id = $1 FOR UPDATE`,
        [req.params.id],
      );
      const dispute = disputeResult.rows[0];
      if (!dispute) throw errors.notFound('Dispute not found.');
      if (!['OPEN', 'UNDER_REVIEW'].includes(dispute.status)) {
        throw errors.conflict('DISPUTE_ALREADY_RESOLVED', 'This dispute is already resolved.');
      }
      await tx.query(
        `UPDATE disputes SET status = $1, resolution = $2, resolved_by = $3, resolved_at = now()
          WHERE id = $4`,
        [body.outcome, body.resolution, req.user!.id, dispute.id],
      );
      await tx.query(
        `UPDATE invoices SET status = $1, updated_at = now() WHERE id = $2`,
        [body.outcome === 'RESOLVED' ? 'SETTLEMENT_PROCESSING' : 'AWAITING_EMPLOYER_REVIEW', dispute.invoice_id],
      );
      for (const userId of [dispute.employer_id, dispute.worker_id]) {
        await notify(tx, {
          userId,
          type: 'dispute.status.updated',
          title: 'Dispute resolved',
          body: `Support resolved the dispute for "${dispute.role}".`,
          resourceType: 'dispute',
          resourceId: dispute.id,
        });
      }
      await recordAudit(tx, {
        actorId: req.user!.id,
        action: 'dispute.resolve',
        resourceType: 'dispute',
        resourceId: dispute.id,
        correlationId: req.requestId,
        metadata: { outcome: body.outcome },
      });
      return dispute;
    });
    hub.publish([resolved.employer_id, resolved.worker_id], 'dispute.status.updated', {
      type: 'dispute',
      id: resolved.id,
    }, { status: body.outcome });
    res.json({ disputeId: resolved.id, status: body.outcome });
  }),
);

/**
 * Provider webhook. The signature is verified against the raw body before any
 * state change; duplicate provider event ids are rejected idempotently.
 */
router.post(
  '/payments/webhook',
  asyncHandler(async (req, res) => {
    const raw = Buffer.isBuffer(req.body) ? req.body.toString('utf8') : JSON.stringify(req.body);
    const signature = req.header('x-kalla-signature') ?? '';
    const expected = hmac(config.PAYMENT_WEBHOOK_SECRET, raw);
    if (!signature || !safeEqual(signature, expected)) {
      throw errors.unauthorized('Invalid webhook signature.');
    }
    let parsedJson: unknown;
    try {
      parsedJson = JSON.parse(raw);
    } catch {
      throw errors.badRequest('INVALID_JSON', 'Webhook body must be valid JSON.');
    }
    const body = parseBody(webhookSchema, parsedJson);

    const outcome = await withTransaction(async (tx) => {
      try {
        await tx.query(
          `INSERT INTO provider_events (id, provider, provider_event_id, event_type, payload)
           VALUES ($1, $2, $3, $4, $5::jsonb)`,
          [newId(), body.provider, body.providerEventId, body.type, raw],
        );
      } catch (error) {
        if ((error as { code?: string }).code === '23505') {
          return { duplicate: true } as const;
        }
        throw error;
      }
      const transaction = await tx.query<{
        id: string;
        invoice_id: string;
        amount_npr: string;
        status: string;
      }>(
        `SELECT id, invoice_id, amount_npr, status FROM payment_transactions
          WHERE id = $1 AND provider = $2 FOR UPDATE`,
        [body.transactionId, body.provider],
      );
      const payment = transaction.rows[0];
      if (!payment) throw errors.notFound('Payment transaction not found.');
      if (Number(payment.amount_npr) !== body.amountNpr) {
        throw errors.badRequest('AMOUNT_MISMATCH', 'Webhook amount does not match the payment transaction.');
      }
      const invoiceResult = await tx.query<{
        id: string;
        amount_npr: string;
        currency: string;
        status: string;
        employer_id: string;
        worker_id: string;
        role: string;
      }>(
        `SELECT i.id, i.amount_npr, i.currency, i.status, i.employer_id, i.worker_id, j.role
           FROM invoices i JOIN shifts s ON s.id = i.shift_id JOIN jobs j ON j.id = s.job_id
          WHERE i.id = $1 FOR UPDATE`,
        [payment.invoice_id],
      );
      const invoice = invoiceResult.rows[0]!;
      await tx.query(
        `UPDATE payment_transactions SET status = 'SETTLED', provider_ref = $2, updated_at = now()
          WHERE id = $1`,
        [payment.id, body.providerRef ?? body.providerEventId],
      );
      await tx.query(
        `UPDATE invoices SET status = 'PAID', paid_at = now(), updated_at = now() WHERE id = $1`,
        [invoice.id],
      );
      await tx.query(
        `INSERT INTO ledger_entries (id, invoice_id, entry_type, amount_npr, currency, description)
         VALUES ($1, $2, 'RELEASE', $3, $4, 'Settlement confirmed by payment provider')`,
        [newId(), invoice.id, invoice.amount_npr, invoice.currency],
      );
      await tx.query(
        `UPDATE provider_events SET processed_at = now() WHERE provider = $1 AND provider_event_id = $2`,
        [body.provider, body.providerEventId],
      );
      for (const userId of [invoice.worker_id, invoice.employer_id]) {
        await notify(tx, {
          userId,
          type: 'payment.status.updated',
          title: 'Payment settled',
          body: `Settlement for "${invoice.role}" is complete.`,
          resourceType: 'invoice',
          resourceId: invoice.id,
        });
      }
      await recordAudit(tx, {
        action: 'payment.webhook.settled',
        resourceType: 'payment_transaction',
        resourceId: payment.id,
        correlationId: req.requestId,
        metadata: { provider: body.provider, providerEventId: body.providerEventId },
      });
      return { duplicate: false, invoiceId: invoice.id, workerId: invoice.worker_id, employerId: invoice.employer_id };
    });

    if (outcome.duplicate) {
      res.json({ received: true, duplicate: true });
      return;
    }
    hub.publish([outcome.workerId, outcome.employerId], 'payment.status.updated', {
      type: 'invoice',
      id: outcome.invoiceId,
    }, { status: 'PAID' });
    res.json({ received: true, duplicate: false });
  }),
);

router.post(
  '/payments/:id/refund',
  authenticate,
  requireRoles('BILLING_ADMIN'),
  asyncHandler(async (req, res) => {
    const refund = await withTransaction(async (tx) => {
      const result = await tx.query<{ id: string; invoice_id: string; amount_npr: string; status: string }>(
        `SELECT * FROM payment_transactions WHERE id = $1 FOR UPDATE`,
        [req.params.id],
      );
      const payment = result.rows[0];
      if (!payment) throw errors.notFound('Payment transaction not found.');
      if (payment.status !== 'SETTLED') {
        throw errors.conflict('PAYMENT_NOT_REFUNDABLE', 'Only settled payments can be refunded.');
      }
      await tx.query(`UPDATE payment_transactions SET status = 'REFUNDED', updated_at = now() WHERE id = $1`, [
        payment.id,
      ]);
      await tx.query(`UPDATE invoices SET status = 'REFUNDED', updated_at = now() WHERE id = $1`, [
        payment.invoice_id,
      ]);
      await tx.query(
        `INSERT INTO ledger_entries (id, invoice_id, entry_type, amount_npr, currency, description)
         VALUES ($1, $2, 'REFUND', $3, 'NPR', 'Refund issued by billing administrator')`,
        [newId(), payment.invoice_id, payment.amount_npr],
      );
      await recordAudit(tx, {
        actorId: req.user!.id,
        action: 'payment.refund',
        resourceType: 'payment_transaction',
        resourceId: payment.id,
        correlationId: req.requestId,
      });
      return payment;
    });
    res.json({ transactionId: refund.id, status: 'REFUNDED' });
  }),
);

export default router;
