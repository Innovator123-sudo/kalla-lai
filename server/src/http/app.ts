import express, { type NextFunction, type Request, type Response } from 'express';
import helmet from 'helmet';
import cors from 'cors';
import { pinoHttp } from 'pino-http';
import { config, corsOrigins } from '../config.js';
import { pingDb } from '../db/index.js';
import { AppError } from '../lib/errors.js';
import { logger } from '../lib/logger.js';
import { metricsMiddleware, registry } from '../lib/metrics.js';
import { appGate, loadShedding, noStore, resetLoadShedding } from '../lib/guards.js';
import { newId } from '../lib/crypto.js';
import apiRoutes from '../routes/index.js';
import { hub } from '../realtime.js';

export function createApp() {
  resetLoadShedding();
  const app = express();
  if (config.TRUST_PROXY) app.set('trust proxy', 1);
  app.disable('x-powered-by');

  app.use((req, res, next) => {
    req.requestId = req.header('x-request-id')?.slice(0, 100) || newId();
    res.setHeader('x-request-id', req.requestId);
    next();
  });

  app.use(
    pinoHttp({
      logger,
      genReqId: (req) => (req as Request).requestId,
      customLogLevel: (_req, res, err) => {
        if (err || res.statusCode >= 500) return 'error';
        if (res.statusCode >= 400) return 'warn';
        return 'info';
      },
      autoLogging: { ignore: (req) => req.url === '/healthz' || req.url === '/readyz' },
    }),
  );

  app.use(
    helmet({
      // JSON API: it never needs to load scripts or be framed.
      contentSecurityPolicy: {
        useDefaults: false,
        directives: { defaultSrc: ["'none'"], frameAncestors: ["'none'"] },
      },
      crossOriginResourcePolicy: { policy: 'same-site' },
    }),
  );

  // `*` is used by single-origin/static deployments where the web app and API
  // live on different hosts. Authentication is bearer-token based, so no
  // cookies need to be shared across origins.
  const allowAllOrigins = corsOrigins.includes('*');

  app.use(
    cors({
      origin: (origin, callback) => {
        if (allowAllOrigins || !origin || corsOrigins.includes(origin)) {
          return callback(null, true);
        }
        // Local Flutter web runs on an arbitrary dev port; allow loopback only
        // outside production. Deployed origins must be listed explicitly.
        if (
          config.NODE_ENV !== 'production' &&
          /^http:\/\/(localhost|127\.0\.0\.1):\d+$/.test(origin)
        ) {
          return callback(null, true);
        }
        return callback(null, false);
      },
      methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
      allowedHeaders: [
        'content-type',
        'authorization',
        'idempotency-key',
        'x-request-id',
        'x-app-version',
        'x-platform',
      ],
      exposedHeaders: ['x-request-id'],
      maxAge: 600,
    }),
  );

  // Payment webhooks need the raw bytes for signature verification. This
  // parser must be registered before the JSON body parser.
  app.use('/v1/payments/webhook', express.raw({ type: '*/*', limit: '256kb' }));
  app.use('/v1/verification/veriff-webhook', express.raw({ type: '*/*', limit: '256kb' }));

  // Showcase uploads and the in-app demo document check carry base64 media, so
  // they need a larger body limit than the default JSON parser below. These run
  // first; the global parser skips requests whose body is already parsed.
  app.use('/v1/uploads', express.json({ limit: '30mb' }));
  app.use('/v1/verification/demo-document', express.json({ limit: '16mb' }));

  app.use(express.json({ limit: '1mb' }));

  app.use(metricsMiddleware);
  app.use(loadShedding);

  app.get('/healthz', (_req, res) => {
    res.json({ status: 'ok', service: 'kalla-lai-api', uptimeSeconds: Math.round(process.uptime()) });
  });

  app.get('/readyz', async (_req, res) => {
    const ready = await pingDb();
    res.status(ready ? 200 : 503).json({ status: ready ? 'ready' : 'not_ready', database: ready });
  });

  app.get('/metrics', async (req, res) => {
    if (config.METRICS_TOKEN) {
      const token = req.header('x-metrics-token') ?? req.header('authorization')?.replace('Bearer ', '');
      if (token !== config.METRICS_TOKEN) {
        res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'Metrics token required.' } });
        return;
      }
    }
    res.setHeader('content-type', registry.contentType);
    res.send(await registry.metrics());
  });

  app.get('/v1/realtime/stats', (_req, res) => {
    res.json({ onlineSockets: hub.onlineCount() });
  });

  app.use('/v1/auth', noStore);
  app.use('/v1', appGate);
  app.use('/v1', apiRoutes);

  app.use((req, res) => {
    res.status(404).json({
      error: {
        code: 'NOT_FOUND',
        message: 'The requested endpoint does not exist.',
        requestId: req.requestId,
      },
    });
  });

  app.use((error: unknown, req: Request, res: Response, _next: NextFunction) => {
    if (error instanceof AppError) {
      res.status(error.status).json({
        error: {
          code: error.code,
          message: error.message,
          details: error.details,
          requestId: req.requestId,
        },
      });
      return;
    }
    if ((error as { type?: string }).type === 'entity.parse.failed') {
      res.status(400).json({
        error: { code: 'INVALID_JSON', message: 'Request body is not valid JSON.', requestId: req.requestId },
      });
      return;
    }
    if ((error as { type?: string }).type === 'entity.too.large') {
      res.status(413).json({
        error: { code: 'PAYLOAD_TOO_LARGE', message: 'Request body is too large.', requestId: req.requestId },
      });
      return;
    }
    logger.error({ err: error, requestId: req.requestId }, 'unhandled request error');
    res.status(500).json({
      error: {
        code: 'INTERNAL_ERROR',
        message: 'An unexpected error occurred. Quote the request id when contacting support.',
        requestId: req.requestId,
      },
    });
  });

  return app;
}
