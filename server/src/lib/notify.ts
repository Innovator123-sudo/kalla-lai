import type { Db } from '../db/index.js';
import { hub } from '../realtime.js';
import { newId } from './crypto.js';

export interface NotificationInput {
  userId: string;
  type: string;
  title: string;
  body: string;
  resourceType?: string;
  resourceId?: string | null;
}

/**
 * Notifications are durable (in-app inbox) and best-effort realtime. Push/SMS
 * delivery is an infrastructure adapter concern and is intentionally not faked
 * in demo mode.
 */
export async function notify(tx: Db, input: NotificationInput): Promise<void> {
  const id = newId();
  await tx.query(
    `INSERT INTO notifications (id, user_id, type, title, body, resource_type, resource_id)
     VALUES ($1, $2, $3, $4, $5, $6, $7)`,
    [id, input.userId, input.type, input.title, input.body, input.resourceType ?? null, input.resourceId ?? null],
  );
  hub.publish([input.userId], 'notification.created', { type: 'notification', id }, {
    notificationId: id,
    notificationType: input.type,
    title: input.title,
  });
}
