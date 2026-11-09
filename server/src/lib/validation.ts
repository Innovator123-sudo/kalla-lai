import type { Request } from 'express';
import type { ZodTypeAny } from 'zod';
import type { z } from 'zod';
import { db, withTransaction, type Db } from '../db/index.js';
import { newId, sha256 } from './crypto.js';
import { errors } from './errors.js';

export interface CommandResult {
  status: number;
  body: unknown;
}

export function parseBody<S extends ZodTypeAny>(schema: S, body: unknown): z.infer<S> {
  const result = schema.safeParse(body);
  if (!result.success) {
    throw errors.validation(
      result.error.issues.map((issue) => ({
        path: issue.path.join('.'),
        message: issue.message,
      })),
    );
  }
  return result.data as z.infer<S>;
}

export function parseQuery<S extends ZodTypeAny>(schema: S, query: unknown): z.infer<S> {
  return parseBody(schema, query);
}

/**
 * Execute a state-changing command exactly once per (user, key, endpoint).
 * The idempotency record is written in the same transaction as the effect.
 */
export async function idempotent(
  req: Request,
  endpoint: string,
  handler: (tx: Db) => Promise<CommandResult>,
): Promise<CommandResult> {
  const key = req.header('idempotency-key');
  if (!key) {
    return withTransaction(handler);
  }
  if (key.length < 8 || key.length > 200) {
    throw errors.badRequest('INVALID_IDEMPOTENCY_KEY', 'Idempotency-Key must be 8-200 characters.');
  }
  const userId = req.user?.id;
  if (!userId) throw errors.unauthorized();

  const requestHash = sha256(JSON.stringify(req.body ?? {}));
  const existing = await db().query<{
    request_hash: string;
    response_status: number | null;
    response_body: unknown;
  }>(
    `SELECT request_hash, response_status, response_body FROM idempotency_keys
      WHERE user_id = $1 AND key = $2 AND endpoint = $3`,
    [userId, key, endpoint],
  );
  if (existing.rows[0]) {
    if (existing.rows[0].request_hash !== requestHash) {
      throw errors.conflict(
        'IDEMPOTENCY_CONFLICT',
        'This Idempotency-Key was already used with a different request.',
      );
    }
    return {
      status: existing.rows[0].response_status ?? 200,
      body: existing.rows[0].response_body,
    };
  }

  try {
    return await withTransaction(async (tx) => {
      const result = await handler(tx);
      await tx.query(
        `INSERT INTO idempotency_keys
           (user_id, key, endpoint, request_hash, response_status, response_body)
         VALUES ($1, $2, $3, $4, $5, $6::jsonb)`,
        [userId, key, endpoint, requestHash, result.status, JSON.stringify(result.body)],
      );
      return result;
    });
  } catch (error) {
    if ((error as { code?: string }).code === '23505') {
      const stored = await db().query<{
        request_hash: string;
        response_status: number | null;
        response_body: unknown;
      }>(
        `SELECT request_hash, response_status, response_body FROM idempotency_keys
          WHERE user_id = $1 AND key = $2 AND endpoint = $3`,
        [userId, key, endpoint],
      );
      if (stored.rows[0]) {
        if (stored.rows[0].request_hash !== requestHash) {
          throw errors.conflict(
            'IDEMPOTENCY_CONFLICT',
            'This Idempotency-Key was already used with a different request.',
          );
        }
        return {
          status: stored.rows[0].response_status ?? 200,
          body: stored.rows[0].response_body,
        };
      }
    }
    throw error;
  }
}

export function newRequestId() {
  return newId();
}
