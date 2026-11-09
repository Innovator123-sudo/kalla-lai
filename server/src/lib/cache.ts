import { Redis } from 'ioredis';
import { config } from '../config.js';
import { logger } from './logger.js';
import { cacheEvents } from './metrics.js';

/**
 * Cache-only Redis adapter.
 *
 * Redis is never authoritative. Every call is best-effort: if Redis is not
 * configured, is unreachable, or errors, callers fall through to PostgreSQL.
 * A broken cache must never break a request.
 */
let client: Redis | null = null;
let connected = false;
let errorLogged = false;

function getClient(): Redis | null {
  if (!config.REDIS_URL) return null;
  if (!client) {
    client = new Redis(config.REDIS_URL, {
      lazyConnect: true,
      enableOfflineQueue: false,
      maxRetriesPerRequest: 1,
      connectTimeout: 1_000,
      retryStrategy: (attempt) => (attempt > 3 ? null : Math.min(attempt * 250, 1_000)),
    });
    client.on('ready', () => {
      connected = true;
      errorLogged = false;
      logger.info('redis cache connected');
    });
    client.on('end', () => {
      connected = false;
    });
    client.on('error', (error: Error) => {
      connected = false;
      if (!errorLogged) {
        errorLogged = true;
        logger.warn({ err: error }, 'redis cache unavailable; continuing without cache');
      }
    });
  }
  return client;
}

export async function initCache(): Promise<void> {
  const redis = getClient();
  if (!redis) {
    logger.info('redis cache disabled (REDIS_URL not set)');
    return;
  }
  try {
    await redis.connect();
    await redis.ping();
  } catch (error) {
    logger.warn({ err: error }, 'redis cache connection failed; continuing without cache');
  }
}

export async function cacheGet(key: string): Promise<string | null> {
  const redis = getClient();
  if (!redis || !connected) {
    if (redis) cacheEvents.inc({ result: 'skip' });
    return null;
  }
  try {
    const value = await redis.get(key);
    cacheEvents.inc({ result: value === null ? 'miss' : 'hit' });
    return value;
  } catch {
    cacheEvents.inc({ result: 'error' });
    return null;
  }
}

export async function cacheSet(key: string, value: string, ttlSeconds: number): Promise<void> {
  const redis = getClient();
  if (!redis || !connected) return;
  try {
    await redis.set(key, value, 'EX', Math.max(1, Math.floor(ttlSeconds)));
  } catch {
    cacheEvents.inc({ result: 'error' });
  }
}

export async function closeCache(): Promise<void> {
  if (!client) return;
  try {
    await client.quit();
  } catch {
    client.disconnect();
  }
  client = null;
  connected = false;
}
