import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { z } from 'zod';
import { config } from '../config.js';
import { db, withTransaction } from '../db/index.js';
import { recordAudit } from '../lib/audit.js';
import { authenticate } from '../lib/auth.js';
import { AppError, errors } from '../lib/errors.js';
import { asyncHandler } from '../lib/http.js';
import { parseBody } from '../lib/validation.js';
import { newId } from '../lib/crypto.js';
import { createVeriffSession, isVeriffSignatureValid } from '../lib/veriff.js';
import { runDemoDocumentVerification } from '../lib/demo_verification.js';

const router = Router();
const consentVersion = 'identity-verification-v1';
const sessionSchema = z.object({ consent: z.literal(true) });

// The in-app demo document flow is offered only when DEMO_MODE is on and no
// real Veriff credentials are configured. Otherwise the client uses Veriff.
function verificationMode(): 'DEMO' | 'VERIFF' {
  return config.DEMO_MODE && !config.VERIFF_API_KEY ? 'DEMO' : 'VERIFF';
}

const demoDocumentSchema = z.object({
  consent: z.literal(true),
  documentType: z.enum(['CITIZENSHIP', 'NID', 'PASSPORT', 'DRIVING_LICENSE', 'VOTER_ID']),
  documentImage: z.string().min(100).max(16_000_000),
  documentBackImage: z.string().min(100).max(16_000_000).optional(),
  selfieImage: z.string().min(100).max(16_000_000),
});
const sessionLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 5,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
});

// The demo flow is synthetic and already rejects already-verified accounts, so
// it gets a generous per-user budget instead of the tight IP-keyed Veriff one
// (which local testing on a single IP would otherwise exhaust).
const demoDocumentLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 30,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  keyGenerator: (req) => req.user?.id ?? 'anonymous',
});

router.get(
  '/me',
  authenticate,
  asyncHandler(async (req, res) => {
    const user = await db().query<{
      onboarding_complete: boolean;
      identity_status: string;
    }>(
      'SELECT onboarding_complete, identity_status FROM users WHERE id = $1 AND status = $2',
      [req.user!.id, 'ACTIVE'],
    );
    if (!user.rows[0]) throw errors.notFound('Account not found.');
    res.json({
      onboardingComplete: user.rows[0].onboarding_complete,
      identityStatus: user.rows[0].identity_status,
      mode: verificationMode(),
    });
  }),
);

router.post(
  '/onboarding',
  authenticate,
  asyncHandler(async (req, res) => {
    const body = z
      .object({
        fullName: z.string().trim().min(2).max(120),
        phone: z.string().trim().min(6).max(32),
        worker: z
          .object({
            baseArea: z.string().trim().min(2).max(160),
            education: z.string().trim().min(2).max(240),
            skillsSummary: z.string().trim().min(2).max(1000),
          })
          .optional(),
        employer: z
          .object({
            organization: z.string().trim().min(2).max(160),
            worksiteArea: z.string().trim().min(2).max(300),
            hiringSummary: z.string().trim().min(2).max(1000),
          })
          .optional(),
      })
      .refine(
        (value) =>
          (!req.user!.roles.includes('WORKER') || value.worker !== undefined) &&
          (!req.user!.roles.includes('EMPLOYER') || value.employer !== undefined),
        'Provide the onboarding details required for your account role.',
      )
      .safeParse(req.body);
    if (!body.success) {
      throw errors.validation(body.error.flatten(), 'Complete the required profile fields.');
    }

    await withTransaction(async (tx) => {
      await tx.query(
        'UPDATE users SET full_name = $1, phone = $2, onboarding_complete = true, updated_at = now() WHERE id = $3',
        [body.data.fullName, body.data.phone, req.user!.id],
      );
      if (body.data.worker && req.user!.roles.includes('WORKER')) {
        await tx.query(
          `UPDATE worker_profiles
              SET public_name = $1, base_area = $2, education = $3, skills_summary = $4, updated_at = now()
            WHERE user_id = $5`,
          [
            body.data.fullName,
            body.data.worker.baseArea,
            body.data.worker.education,
            body.data.worker.skillsSummary,
            req.user!.id,
          ],
        );
      }
      if (body.data.employer && req.user!.roles.includes('EMPLOYER')) {
        await tx.query(
          `UPDATE employer_profiles
              SET display_name = $1, organization = $2, worksite_area = $3, hiring_summary = $4, updated_at = now()
            WHERE user_id = $5`,
          [
            body.data.fullName,
            body.data.employer.organization,
            body.data.employer.worksiteArea,
            body.data.employer.hiringSummary,
            req.user!.id,
          ],
        );
      }
      await recordAudit(tx, {
        actorId: req.user!.id,
        action: 'profile.onboarding_complete',
        resourceType: 'user',
        resourceId: req.user!.id,
        correlationId: req.requestId,
      });
    });
    res.json({ onboardingComplete: true });
  }),
);

router.post(
  '/sessions',
  authenticate,
  sessionLimiter,
  asyncHandler(async (req, res) => {
    const body = sessionSchema.safeParse(req.body);
    if (!body.success) {
      throw errors.validation(
        body.error.flatten(),
        'Consent is required before starting identity verification.',
      );
    }
    const user = await db().query<{ identity_status: string; onboarding_complete: boolean }>(
      'SELECT identity_status, onboarding_complete FROM users WHERE id = $1 AND status = $2',
      [req.user!.id, 'ACTIVE'],
    );
    const row = user.rows[0];
    if (!row) throw errors.notFound('Account not found.');
    if (!row.onboarding_complete) {
      throw errors.forbidden('Complete your profile before identity verification.');
    }
    if (row.identity_status === 'VERIFIED') {
      throw errors.conflict('ALREADY_VERIFIED', 'Your identity is already verified.');
    }
    if (row.identity_status === 'PENDING') {
      await db().query(
        `UPDATE identity_verifications
            SET state = 'NEEDS_ACTION', decided_at = now(), updated_at = now()
          WHERE user_id = $1 AND state = 'PENDING'`,
        [req.user!.id],
      );
      await db().query(
        `UPDATE users SET identity_status = 'NEEDS_ACTION', updated_at = now()
          WHERE id = $1`,
        [req.user!.id],
      );
    }

    const session = await createVeriffSession(req.user!.id);
    await withTransaction(async (tx) => {
      await tx.query(
        `INSERT INTO identity_verifications
           (id, user_id, provider, provider_session_id, consent_version, consented_at)
         VALUES ($1, $2, 'VERIFF', $3, $4, now())`,
        [newId(), req.user!.id, session.sessionId, consentVersion],
      );
      await tx.query(
        `UPDATE users SET identity_status = 'PENDING', updated_at = now() WHERE id = $1`,
        [req.user!.id],
      );
      await recordAudit(tx, {
        actorId: req.user!.id,
        action: 'identity.verification_started',
        resourceType: 'identity_verification',
        resourceId: session.sessionId,
        correlationId: req.requestId,
        metadata: { provider: 'VERIFF', consentVersion },
      });
    });
    res.status(201).json({
      sessionUrl: session.url,
      onboardingComplete: true,
      identityStatus: 'PENDING',
    });
  }),
);

router.post(
  '/veriff-webhook',
  asyncHandler(async (req, res) => {
    const secret = config.VERIFF_SHARED_SECRET;
    if (!secret) throw errors.unavailable('VERIFICATION_UNAVAILABLE', 'Verification webhook is not configured.');
    if (!Buffer.isBuffer(req.body)) {
      throw errors.badRequest('INVALID_WEBHOOK', 'Expected a raw webhook payload.');
    }
    const signature = req.header('x-hmac-signature')?.trim();
    if (!isVeriffSignatureValid(req.body, signature, secret)) {
      throw errors.unauthorized('Invalid verification webhook signature.');
    }

    let payload: unknown;
    try {
      payload = JSON.parse(req.body.toString('utf8'));
    } catch {
      throw errors.badRequest('INVALID_WEBHOOK', 'Invalid verification webhook JSON.');
    }
    const parsed = z
      .object({
        verification: z.object({
          id: z.string().uuid(),
          status: z.string(),
        }),
      })
      .safeParse(payload);
    if (!parsed.success) {
      throw errors.badRequest('INVALID_WEBHOOK', 'Missing verification session result.');
    }

    const decision = {
      approved: 'VERIFIED',
      declined: 'REJECTED',
      resubmission_requested: 'NEEDS_ACTION',
    }[parsed.data.verification.status];
    if (!decision) {
      res.status(200).json({ received: true });
      return;
    }

    await withTransaction(async (tx) => {
      const updated = await tx.query<{ id: string; user_id: string }>(
        `UPDATE identity_verifications
            SET state = $1, decided_at = now(), updated_at = now()
          WHERE provider = 'VERIFF' AND provider_session_id = $2 AND state = 'PENDING'
          RETURNING id, user_id`,
        [decision, parsed.data.verification.id],
      );
      if (!updated.rows[0]) {
        const known = await tx.query(
          `SELECT 1 FROM identity_verifications
            WHERE provider = 'VERIFF' AND provider_session_id = $1`,
          [parsed.data.verification.id],
        );
        if (known.rows.length === 0) {
          throw errors.notFound('Verification session not found.');
        }
        return;
      }
      const verification = updated.rows[0];
      await tx.query(
        `UPDATE users
            SET identity_status = $1, updated_at = now()
          WHERE id = $2
            AND NOT EXISTS (
              SELECT 1 FROM identity_verifications newer
               WHERE newer.user_id = $2 AND newer.created_at > (
                 SELECT created_at FROM identity_verifications WHERE id = $3
               )
            )`,
        [decision, verification.user_id, verification.id],
      );
      if (decision === 'VERIFIED') {
        await tx.query(
          `UPDATE worker_profiles SET verification_status = 'VERIFIED', updated_at = now()
            WHERE user_id = $1`,
          [verification.user_id],
        );
      }
      await recordAudit(tx, {
        actorId: verification.user_id,
        action: 'identity.verification_decided',
        resourceType: 'identity_verification',
        resourceId: verification.id,
        metadata: { provider: 'VERIFF', decision },
      });
    });
    res.status(200).json({ received: true });
  }),
);

router.post(
  '/demo-document',
  authenticate,
  demoDocumentLimiter,
  asyncHandler(async (req, res) => {
    if (verificationMode() !== 'DEMO') {
      throw errors.unavailable(
        'VERIFICATION_UNAVAILABLE',
        'In-app demo verification is not enabled on this server. Use the secure Veriff check.',
      );
    }
    const body = parseBody(demoDocumentSchema, req.body);
    const user = await db().query<{
      identity_status: string;
      onboarding_complete: boolean;
      full_name: string;
    }>(
      'SELECT identity_status, onboarding_complete, full_name FROM users WHERE id = $1 AND status = $2',
      [req.user!.id, 'ACTIVE'],
    );
    const row = user.rows[0];
    if (!row) throw errors.notFound('Account not found.');
    if (!row.onboarding_complete) {
      throw errors.forbidden('Complete your profile before identity verification.');
    }
    if (row.identity_status === 'VERIFIED') {
      throw errors.conflict('ALREADY_VERIFIED', 'Your identity is already verified.');
    }

    let result;
    try {
      result = runDemoDocumentVerification({
        documentType: body.documentType,
        documentImage: body.documentImage,
        documentBackImage: body.documentBackImage,
        selfieImage: body.selfieImage,
        fullName: row.full_name,
      });
    } catch (error) {
      // The image gates rejected the submission. Persist the decision (not the
      // raw media) so the account can retake, then surface the reason.
      if (error instanceof AppError) {
        const rejectionId = newId();
        await withTransaction(async (tx) => {
          await tx.query(
            `INSERT INTO identity_verifications
               (id, user_id, provider, provider_session_id, state, consent_version,
                consented_at, decided_at, document_type, detail)
             VALUES ($1, $2, 'DEMO', $3, 'NEEDS_ACTION', $4, now(), now(), $5, $6)`,
            [
              rejectionId,
              req.user!.id,
              rejectionId,
              consentVersion,
              body.documentType,
              JSON.stringify({ decision: 'REJECTED', code: error.code, reason: error.message, demo: true }),
            ],
          );
          await tx.query(
            `UPDATE users SET identity_status = 'NEEDS_ACTION', updated_at = now() WHERE id = $1`,
            [req.user!.id],
          );
          await recordAudit(tx, {
            actorId: req.user!.id,
            action: 'identity.verification_rejected',
            resourceType: 'identity_verification',
            resourceId: rejectionId,
            correlationId: req.requestId,
            metadata: { provider: 'DEMO', documentType: body.documentType, code: error.code },
          });
        });
      }
      throw error;
    }

    const verificationId = newId();
    await withTransaction(async (tx) => {
      await tx.query(
        `INSERT INTO identity_verifications
           (id, user_id, provider, provider_session_id, state, consent_version,
            consented_at, decided_at, document_type, detail)
         VALUES ($1, $2, 'DEMO', $3, 'VERIFIED', $4, now(), now(), $5, $6)`,
        [verificationId, req.user!.id, verificationId, consentVersion, body.documentType, JSON.stringify(result)],
      );
      await tx.query(
        `UPDATE users SET identity_status = 'VERIFIED', updated_at = now() WHERE id = $1`,
        [req.user!.id],
      );
      await tx.query(
        `UPDATE worker_profiles SET verification_status = 'VERIFIED', updated_at = now()
          WHERE user_id = $1`,
        [req.user!.id],
      );
      await recordAudit(tx, {
        actorId: req.user!.id,
        action: 'identity.verification_decided',
        resourceType: 'identity_verification',
        resourceId: verificationId,
        correlationId: req.requestId,
        metadata: { provider: 'DEMO', documentType: body.documentType, decision: 'VERIFIED' },
      });
    });

    res.status(201).json({
      onboardingComplete: true,
      identityStatus: 'VERIFIED',
      mode: 'DEMO',
      verification: result,
    });
  }),
);

export default router;
