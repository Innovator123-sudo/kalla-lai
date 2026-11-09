-- Add the platform administrator role used by the demo staff console.

ALTER TABLE user_roles DROP CONSTRAINT user_roles_role_check;
ALTER TABLE user_roles ADD CONSTRAINT user_roles_role_check
  CHECK (role IN ('WORKER', 'EMPLOYER', 'MODERATOR', 'BILLING_ADMIN', 'ADMIN'));
