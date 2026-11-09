import { monitorEventLoopDelay } from 'node:perf_hooks';
import type { NextFunction, Request, RequestHandler, Response } from 'express';
import { config } from '../config.js';
import { AppError, errors } from './errors.js';

/** Compare dotted numeric versions; non-numeric suffixes (build metadata) are ignored. */
export function compareAppVersions(a: string, b: string): number {
  const parse = (v: string) => v.split('.').map((part) => parseInt(part, 10) || 0);
  const left = parse(a);
  const right = parse(b);
  for (let i = 0; i < Math.max(left.length, right.length); i++) {
    const diff = (left[i] ?? 0) - (right[i] ?? 0);
    if (diff !== 0) return diff < 0 ? -1 : 1;
  }
  return 0;
}

/**
 * Blueprint request chain steps 2-3: maintenance kill switch and minimum
 * app version. The version gate only fires when the client sends
 * X-App-Version, so older clients that predate the header keep working
 * until MIN_APP_VERSION is raised deliberately.
 */
export function appGate(req: Request, res: Response, next: NextFunction) {
  if (req.path === '/app/config' || req.path === '/meta') return next();
  if (config.MAINTENANCE_MODE) {
    res.setHeader('Retry-After', '60');
    return next(
      errors.unavailable('MAINTENANCE', 'The service is under maintenance. Try again shortly.'),
    );
  }
  const minimum = config.MIN_APP_VERSION;
  const version = req.header('x-app-version');
  if (minimum && version && compareAppVersions(version, minimum) < 0) {
    return next(new AppError('UPGRADE_REQUIRED', 426, 'Please update the app to continue.'));
  }
  return next();
}

const eventLoop = monitorEventLoopDelay({ resolution: 20 });
eventLoop.enable();

/** Clear startup work (migrations, WASM compile) from the delay histogram. */
export function resetLoadShedding(): void {
  eventLoop.reset();
}

/**
 * Load shedding: when the event loop falls more than ~1 s behind, answer
 * fast with 503 instead of piling up work. Health checks are never shed so
 * orchestrators can still see the process is alive.
 */
export const loadShedding: RequestHandler = (req, res, next) => {
  if (req.path === '/healthz' || req.path === '/readyz' || req.path === '/metrics') {
    return next();
  }
  const maxDelayMs = eventLoop.max / 1e6;
  eventLoop.reset();
  if (maxDelayMs > 1000) {
    res.setHeader('Retry-After', '5');
    return next(errors.unavailable('SERVICE_BUSY', 'The server is busy. Retry in a few seconds.'));
  }
  return next();
};

/** Private answers (tokens, profiles) must never be stored by shared caches. */
export const noStore: RequestHandler = (_req, res, next) => {
  res.setHeader('Cache-Control', 'no-store');
  next();
};