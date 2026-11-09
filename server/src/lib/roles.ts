export const ROLES = ['WORKER', 'EMPLOYER', 'MODERATOR', 'BILLING_ADMIN', 'ADMIN'] as const;
export type Role = (typeof ROLES)[number];

export function isRole(value: string): value is Role {
  return (ROLES as readonly string[]).includes(value);
}
