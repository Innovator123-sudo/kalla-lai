import type { IncomingMessage, ServerResponse } from 'node:http';
import { config } from './config.js';
import { initDb } from './db/index.js';
import { createApp } from './http/app.js';
import { initCache } from './lib/cache.js';
import { logger } from './lib/logger.js';

/**
 * Vercel serverless entry point.
 *
 * The regular `src/index.ts` entry binds a TCP port and attaches the WebSocket
 * gateway, which Vercel's function runtime does not allow. Here the Express app
 * is created once per warm lambda and reused for every request.
 *
 * Database migrations are intentionally not run per invocation: they are
 * managed explicitly with `npm run db:migrate` (or `supabase:setup`). Set
 * AUTO_MIGRATE=false on Vercel.
 */

let appPromise: Promise<ReturnType<typeof createApp>> | null = null;

async function bootstrap(): Promise<ReturnType<typeof createApp>> {
  await initDb();
  await initCache();
  if (config.AUTO_MIGRATE) {
    logger.warn(
      'AUTO_MIGRATE is enabled on a serverless deployment; run migrations from a job instead',
    );
  }
  return createApp();
}

function getApp(): Promise<ReturnType<typeof createApp>> {
  if (!appPromise) {
    appPromise = bootstrap().catch((error) => {
      // Drop the failed promise so the next request can retry a cold start.
      appPromise = null;
      throw error;
    });
  }
  return appPromise;
}

export default async function handler(
  request: IncomingMessage,
  response: ServerResponse,
): Promise<void> {
  try {
    const app = await getApp();
    // Express apps are callable request handlers.
    (app as unknown as (req: IncomingMessage, res: ServerResponse) => void)(
      request,
      response,
    );
  } catch (error) {
    logger.error({ err: error }, 'serverless bootstrap failed');
    if (!response.headersSent) {
      response.statusCode = 500;
      response.setHeader('content-type', 'application/json; charset=utf-8');
    }
    response.end(
      JSON.stringify({
        error: {
          code: 'INTERNAL_ERROR',
          message: 'The service could not start. Try again shortly.',
        },
      }),
    );
  }
}
