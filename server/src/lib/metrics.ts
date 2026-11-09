import type { NextFunction, Request, Response } from 'express';
import { Counter, Histogram, Registry, collectDefaultMetrics } from 'prom-client';

export const registry = new Registry();
collectDefaultMetrics({ register: registry, prefix: 'kalla_lai_' });

export const httpRequests = new Counter({
  name: 'kalla_lai_http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status'] as const,
  registers: [registry],
});

export const httpDuration = new Histogram({
  name: 'kalla_lai_http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route', 'status'] as const,
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
  registers: [registry],
});

export const domainEvents = new Counter({
  name: 'kalla_lai_domain_events_total',
  help: 'Domain state changes',
  labelNames: ['event'] as const,
  registers: [registry],
});

export const cacheEvents = new Counter({
  name: 'kalla_lai_cache_events_total',
  help: 'Cache lookups by result (cache is optional and never authoritative)',
  labelNames: ['result'] as const,
  registers: [registry],
});

export function metricsMiddleware(req: Request, res: Response, next: NextFunction) {
  const started = process.hrtime.bigint();
  res.on('finish', () => {
    const route = req.route?.path
      ? `${req.baseUrl}${req.route.path}`
      : req.path.startsWith('/v1/')
        ? 'unmatched'
        : req.path;
    const labels = {
      method: req.method,
      route,
      status: String(res.statusCode),
    };
    const seconds = Number(process.hrtime.bigint() - started) / 1e9;
    httpDuration.observe(labels, seconds);
    httpRequests.inc(labels);
  });
  next();
}
