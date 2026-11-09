import { Router } from 'express';
import { z } from 'zod';
import { db } from '../db/index.js';
import { recordAudit } from '../lib/audit.js';
import { authenticate } from '../lib/auth.js';
import { asyncHandler } from '../lib/http.js';
import { parseBody } from '../lib/validation.js';

const router = Router();

const surveySchema = z.object({
  intent: z.enum(['WORKER', 'EMPLOYER']),
  acquisitionSource: z.enum([
    'FRIEND_FAMILY',
    'FACEBOOK_TIKTOK',
    'GOOGLE_SEARCH',
    'JOB_BOARD',
    'COMMUNITY_EVENT',
    'OTHER',
  ]),
  timeline: z.enum(['THIS_WEEK', 'THIS_MONTH', 'EXPLORING']),
  experience: z.enum(['NEW', 'SOME', 'EXPERIENCED']),
});

/**
 * Stores the optional first-run survey after a successful sign-in.
 * One row per account; answers are dropped if the user skips the survey.
 */
router.post(
  '/survey',
  authenticate,
  asyncHandler(async (req, res) => {
    const body = parseBody(surveySchema, req.body ?? {});
    await db().query(
      `INSERT INTO entry_surveys (user_id, intent, acquisition_source, timeline, experience)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (user_id) DO UPDATE SET
         intent = EXCLUDED.intent,
         acquisition_source = EXCLUDED.acquisition_source,
         timeline = EXCLUDED.timeline,
         experience = EXCLUDED.experience,
         updated_at = now()`,
      [req.user!.id, body.intent, body.acquisitionSource, body.timeline, body.experience],
    );
    await recordAudit(db(), {
      actorId: req.user!.id,
      action: 'entry.survey.saved',
      resourceType: 'entry_survey',
      resourceId: req.user!.id,
      correlationId: req.requestId,
    });
    res.status(201).json({ saved: true });
  }),
);

router.get(
  '/survey/me',
  authenticate,
  asyncHandler(async (req, res) => {
    const result = await db().query(
      `SELECT intent, acquisition_source, timeline, experience, updated_at
         FROM entry_surveys WHERE user_id = $1`,
      [req.user!.id],
    );
    res.json({ survey: result.rows[0] ?? null });
  }),
);

export default router;
