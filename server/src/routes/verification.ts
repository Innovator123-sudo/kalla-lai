import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { z } from 'zod';
import { config } from '../config.js';
import { db, withTransaction } from '../db/index.js';
import { recordAudit } from '../lib/audit.js';
import { authenticate } from '../lib/auth.js';
import { errors } from '../lib/errors.js';
import { asyncHandler } from '../lib/http.js';
import { parseBody } from '../lib/validation.js';
import { newId } from '../lib/crypto.js';
import { createVeriffSession, isVeriffSignatureValid } from '../lib/veriff.js';
import {
  runInAppVerification,
  type InAppVerificationResult,
} from '../lib/in_app_verification.js';

const router = Router();
const consentVersion = 'identity-verification-v1';
const sessionSchema = z.object({ consent: z.literal(true) });

/**
 * Veriff is used only when all of its credentials are configured. Otherwise the
 * real self-hosted pipeline (OCR + document check + face match) is used. The
 * old synthetic DEMO mode is gone: `IN_APP` performs real checks.
 */
function verificationMode(): 'VERIFF' | 'IN_APP' {
  return config.VERIFF_API_KEY &&
    config.VERIFF_BASE_URL &&
    config.VERIFF_SHARED_SECRET
    ? 'VERIFF'
    : 'IN_APP';
}

const documentSchema = z.object({
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

// OCR and face matching are CPU-heavy, so each account gets a generous but
// finite attempt budget. Keyed by user so shared IPs (offices, NAT) are fine.
const documentLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  keyGenerator: (req) => req.user?.id ?? 'anonymous',
});

/** Stores the decision and extracted fields, never the photos or OCR text. */
function persistedDetail(result: InAppVerificationResult) {
  return {
    decision: result.decision,
    rejectionCode: result.rejectionCode,
    reason: result.reason,
    documentLabel: result.documentLabel,
    detectedType: result.documentCheck.detectedType,
    detectedLabel: result.documentCheck.detectedLabel,
    documentConfidence: result.documentCheck.confidence,
    ocrConfidence: result.ocr.confidence,
    extractedFields: {
      fullName: result.ocr.fullName,
      fullNameEnglish: result.ocr.fullNameEnglish,
      documentNumber: result.ocr.documentNumber,
      dateOfBirth: result.ocr.dateOfBirth,
      address: result.ocr.address,
      addressEnglish: result.ocr.addressEnglish,
    },
    nameMatch: {
      passed: result.nameMatch.passed,
      similarity: result.nameMatch.similarity,
      matchedTokens: result.nameMatch.matchedTokens,
    },
    faceMatch: result.faceMatch
      ? {
          passed: result.faceMatch.passed,
          faceMatched: result.faceMatch.faceMatched,
          score: result.faceMatch.score,
          distance: result.faceMatch.distance,
          threshold: result.faceMatch.threshold,
          livenessPassed: result.faceMatch.livenessPassed,
          livenessScore: result.faceMatch.livenessScore,
          realScore: result.faceMatch.realScore,
          documentFaceCount: result.faceMatch.documentFaceCount,
          selfieFaceCount: result.faceMatch.selfieFaceCount,
        }
      : null,
    stages: result.stages.map((stage) => ({
      key: stage.key,
      status: stage.status,
    })),
    checks: result.checks,
  };
}

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
    if (verificationMode() !== 'VERIFF') {
      throw errors.unavailable(
        'VERIFF_NOT_CONFIGURED',
        'The secure Veriff check is not available. Use the in-app document check instead.',
      );
    }
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
      mode: 'VERIFF',
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

/**
 * Real in-app identity check: Nepali OCR → English fields → selected document
 * type → name match → strict face match + passive liveness. `/demo-document`
 * remains as a compatibility alias for older clients.
 */
const submitDocument = asyncHandler(async (req, res) => {
  if (verificationMode() !== 'IN_APP') {
    throw errors.unavailable(
      'IN_APP_VERIFICATION_UNAVAILABLE',
      'The in-app document check is not enabled on this server. Use the secure Veriff check.',
    );
  }
  const body = parseBody(documentSchema, req.body);
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

  const result = await runInAppVerification({
    documentType: body.documentType,
    documentImage: body.documentImage,
    documentBackImage: body.documentBackImage,
    selfieImage: body.selfieImage,
    fullName: row.full_name,
  });

  const verificationId = newId();
  const detail = persistedDetail(result);
  await withTransaction(async (tx) => {
    await tx.query(
      `INSERT INTO identity_verifications
         (id, user_id, provider, provider_session_id, state, consent_version,
          consented_at, decided_at, document_type, detail)
       VALUES ($1, $2, 'IN_APP', $3, $4, $5, now(), now(), $6, $7)`,
      [
        verificationId,
        req.user!.id,
        verificationId,
        result.verified ? 'VERIFIED' : 'NEEDS_ACTION',
        consentVersion,
        body.documentType,
        JSON.stringify(detail),
      ],
    );
    await tx.query(
      `UPDATE users SET identity_status = $1, updated_at = now() WHERE id = $2`,
      [result.verified ? 'VERIFIED' : 'NEEDS_ACTION', req.user!.id],
    );
    if (result.verified) {
      await tx.query(
        `UPDATE worker_profiles SET verification_status = 'VERIFIED', updated_at = now()
          WHERE user_id = $1`,
        [req.user!.id],
      );
    }
    await recordAudit(tx, {
      actorId: req.user!.id,
      action: result.verified
        ? 'identity.verification_decided'
        : 'identity.verification_rejected',
      resourceType: 'identity_verification',
      resourceId: verificationId,
      correlationId: req.requestId,
      metadata: {
        provider: 'IN_APP',
        documentType: body.documentType,
        decision: result.decision,
        rejectionCode: result.rejectionCode,
      },
    });
  });

  res.status(201).json({
    onboardingComplete: true,
    identityStatus: result.verified ? 'VERIFIED' : 'NEEDS_ACTION',
    mode: 'IN_APP',
    verification: result,
  });
});

router.post('/document', authenticate, documentLimiter, submitDocument);
router.post('/demo-document', authenticate, documentLimiter, submitDocument);

export default router;
