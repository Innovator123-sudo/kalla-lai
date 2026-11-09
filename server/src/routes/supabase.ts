import { Router } from 'express';
import { supabase } from '../config.js';
import { databaseBackend } from '../db/index.js';
import { authenticate, requireStaff } from '../lib/auth.js';
import { asyncHandler } from '../lib/http.js';
import { probeSupabaseDataApi } from '../lib/supabase.js';

/**
 * Read-only diagnostics for the Supabase connection. No secret key is ever
 * returned here; the publishable key is intentionally public and is exposed
 * through /v1/app/config for client-side Supabase calls.
 */
const router = Router();

const adminProfileCapabilities = {
  worker: { create: true, edit: true, remove: true },
  employer: { create: true, edit: true, remove: true },
  roles: ['WORKER', 'EMPLOYER', 'MODERATOR', 'BILLING_ADMIN', 'ADMIN'],
};

router.get(
  '/status',
  asyncHandler(async (req, res) => {
    const probe = await probeSupabaseDataApi(req.query.refresh === '1');
    res.setHeader('Cache-Control', 'no-store');
    res.json({
      ...probe,
      databaseBackend: databaseBackend(),
      secretKeyConfigured: Boolean(supabase.secretKey),
      configurationWarning: supabase.warning,
      adminProfileEditing: adminProfileCapabilities,
    });
  }),
);

/** Staff-triggered fresh check (bypasses the 30 s probe cache). */
router.post(
  '/verify',
  authenticate,
  requireStaff,
  asyncHandler(async (_req, res) => {
    const probe = await probeSupabaseDataApi(true);
    res.setHeader('Cache-Control', 'no-store');
    res.json({
      ...probe,
      databaseBackend: databaseBackend(),
      secretKeyConfigured: Boolean(supabase.secretKey),
      configurationWarning: supabase.warning,
      adminProfileEditing: adminProfileCapabilities,
    });
  }),
);

export default router;
