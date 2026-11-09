import { Router } from 'express';
import { config, supabase } from '../config.js';
import { databaseBackend } from '../db/index.js';
import adminRoutes from './admin.js';
import authRoutes from './auth.js';
import entryRoutes from './entry.js';
import interviewRoutes from './interviews.js';
import jobRoutes from './jobs.js';
import paymentRoutes from './payments.js';
import profileRoutes from './profiles.js';
import reviewRoutes from './reviews.js';
import shiftRoutes from './shifts.js';
import supabaseRoutes from './supabase.js';
import uploadRoutes from './uploads.js';
import verificationRoutes from './verification.js';

const router = Router();

router.get('/meta', (_req, res) => {
  res.json({
    name: 'Kalla-Lai API',
    version: 'v1',
    documentation: '/v1/openapi.json',
    realtime: '/v1/ws?token=<access-token>',
    currency: 'NPR',
    backend: databaseBackend(),
  });
});

// Public app configuration: force-update gate, maintenance kill switch,
// feature flags, and the client-safe Supabase settings. Contains no secrets.
router.get('/app/config', (_req, res) => {
  res.setHeader('Cache-Control', 'public, max-age=60');
  res.json({
    minimumAppVersion: config.MIN_APP_VERSION ?? null,
    maintenanceMode: config.MAINTENANCE_MODE,
    demoMode: config.DEMO_MODE,
    currency: 'NPR',
    // Flat keys kept for existing clients.
    supabaseUrl: supabase.url,
    supabasePublishableKey: supabase.publishableKey,
    backend: databaseBackend(),
    supabase: {
      url: supabase.url,
      publishableKey: supabase.publishableKey,
      projectRef: supabase.projectRef,
      configurationWarning: supabase.warning,
      dataApiConfigured: supabase.dataApiConfigured,
      databaseConfigured: supabase.databaseConfigured,
      backend: databaseBackend(),
      // Admin console capabilities, always enforced server-side.
      adminProfileEditing: {
        worker: { create: true, edit: true, remove: true },
        employer: { create: true, edit: true, remove: true },
      },
    },
    features: {
      realtime: true,
      demoVerification: config.DEMO_MODE,
      payments: true,
      adminProfileEditing: true,
    },
    serverTime: new Date().toISOString(),
  });
});

router.use('/auth', authRoutes);
router.use('/admin', adminRoutes);
router.use('/supabase', supabaseRoutes);
router.use('/entry', entryRoutes);
router.use('/uploads', uploadRoutes);
router.use('/verification', verificationRoutes);
router.use('/', profileRoutes);
router.use('/', jobRoutes);
router.use('/', interviewRoutes);
router.use('/', shiftRoutes);
router.use('/', paymentRoutes);
router.use('/', reviewRoutes);

export default router;
