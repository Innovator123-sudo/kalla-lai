import type { Db } from '../db/index.js';
import { newId } from './crypto.js';

export interface AuditInput {
  actorId?: string | null;
  action: string;
  resourceType: string;
  resourceId?: string | null;
  outcome?: 'SUCCESS' | 'DENIED' | 'FAILED';
  correlationId?: string | null;
  metadata?: Record<string, unknown>;
}

/** Append a security-relevant event. Never pass secrets or identity payloads. */
export async function recordAudit(tx: Db, input: AuditInput): Promise<void> {
  await tx.query(
    `INSERT INTO audit_events
       (id, actor_id, action, resource_type, resource_id, outcome, correlation_id, metadata)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8::jsonb)`,
    [
      newId(),
      input.actorId ?? null,
      input.action,
      input.resourceType,
      input.resourceId ?? null,
      input.outcome ?? 'SUCCESS',
      input.correlationId ?? null,
      JSON.stringify(input.metadata ?? {}),
    ],
  );
}
