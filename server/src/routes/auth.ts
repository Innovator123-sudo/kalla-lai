import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { config } from '../config.js';
import { db, withTransaction } from '../db/index.js';
import { authenticate, signAccessToken, type AuthUser } from '../lib/auth.js';
import { newId, newOpaqueToken, sha256 } from '../lib/crypto.js';
import { errors } from '../lib/errors.js';
import { asyncHandler } from '../lib/http.js';
import { recordAudit } from '../lib/audit.js';
import { logger } from '../lib/logger.js';
import { ROLES, type Role } from '../lib/roles.js';
import { parseBody } from '../lib/validation.js';
import { verifyFirebaseIdToken } from '../lib/firebase_auth.js';

const router = Router();

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 30,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  handler: (_req, res) =>
    res.status(429).json({
      error: { code: 'RATE_LIMITED', message: 'Too many authentication attempts. Try again later.' },
    }),
});

const registerSchema = z
  .object({
    email: z.string().email().max(254),
    password: z.string().min(10).max(200),
    fullName: z.string().min(2).max(120),
    phone: z.string().min(6).max(32).optional(),
    role: z.enum(['WORKER', 'EMPLOYER']),
    publicName: z.string().min(2).max(120).optional(),
    organization: z.string().max(160).optional(),
  })
  .strict();

// Accept either a full email or a short sign-in ID (the local part of the
// account email), so a staff member can sign in as "novacane232".
const loginSchema = z
  .object({
    email: z.string().trim().min(1).max(254),
    password: z.string().min(1).max(200),
  })
  .strict();

const firebaseSignInSchema = z
  .object({
    idToken: z.string().min(1).max(10_000),
    role: z.enum(['WORKER', 'EMPLOYER']),
  })
  .strict();

const refreshSchema = z.object({ refreshToken: z.string().min(20).max(500) }).strict();

async function rolesFor(userId: string): Promise<Role[]> {
  const result = await db().query<{ role: Role }>('SELECT role FROM user_roles WHERE user_id = $1', [
    userId,
  ]);
  return result.rows.map((row) => row.role);
}

async function createSession(
  user: AuthUser,
  meta: { userAgent?: string; ip?: string },
): Promise<{ accessToken: string; refreshToken: string; expiresIn: number }> {
  const refreshToken = newOpaqueToken();
  const expiresAt = new Date(Date.now() + config.REFRESH_TTL_DAYS * 24 * 60 * 60 * 1000);
  await db().query(
    `INSERT INTO sessions (id, user_id, refresh_token_hash, user_agent, ip, expires_at)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [newId(), user.id, sha256(refreshToken), meta.userAgent?.slice(0, 300) ?? null, meta.ip ?? null, expiresAt],
  );
  return {
    accessToken: signAccessToken(user),
    refreshToken,
    expiresIn: config.JWT_ACCESS_TTL_SECONDS,
  };
}

router.post(
  '/register',
  authLimiter,
  asyncHandler(async (req, res) => {
    const body = parseBody(registerSchema, req.body);
    const passwordHash = await bcrypt.hash(body.password, 12);
    const userId = newId();
    const email = body.email.trim().toLowerCase();

    await withTransaction(async (tx) => {
      const existing = await tx.query('SELECT 1 FROM users WHERE lower(email) = $1', [email]);
      if (existing.rows.length > 0) {
        throw errors.conflict('EMAIL_ALREADY_REGISTERED', 'An account with this email already exists.');
      }
      await tx.query(
        `INSERT INTO users (id, email, password_hash, full_name, phone)
         VALUES ($1, $2, $3, $4, $5)`,
        [userId, email, passwordHash, body.fullName.trim(), body.phone ?? null],
      );
      await tx.query('INSERT INTO user_roles (user_id, role) VALUES ($1, $2)', [userId, body.role]);
      if (body.role === 'WORKER') {
        await tx.query(
          `INSERT INTO worker_profiles (user_id, public_name, verification_status)
           VALUES ($1, $2, 'PENDING')`,
          [userId, body.publicName?.trim() || body.fullName.trim()],
        );
      } else {
        await tx.query(
          `INSERT INTO employer_profiles (user_id, display_name, organization)
           VALUES ($1, $2, $3)`,
          [userId, body.publicName?.trim() || body.fullName.trim(), body.organization ?? null],
        );
      }
      await recordAudit(tx, {
        actorId: userId,
        action: 'auth.register',
        resourceType: 'user',
        resourceId: userId,
        correlationId: req.requestId,
      });
    });

    const user: AuthUser = {
      id: userId,
      email,
      roles: [body.role as Role],
    };
    const session = await createSession(user, {
      userAgent: req.header('user-agent'),
      ip: req.ip,
    });
    res.status(201).json({
      user: {
        id: userId,
        email,
        fullName: body.fullName.trim(),
        roles: user.roles,
        identityStatus: 'NOT_STARTED',
        onboardingComplete: false,
      },
      ...session,
    });
  }),
);

router.post(
  '/login',
  authLimiter,
  asyncHandler(async (req, res) => {
    // Demo-only convenience: the seeded platform admin can sign in with the
    // literal id/password "admin"/"admin".
    if (
      config.DEMO_MODE &&
      req.body?.email === 'admin' &&
      req.body?.password === 'admin'
    ) {
      req.body = { ...req.body, email: 'admin@kallalai.demo' };
    }
    const body = parseBody(loginSchema, req.body);
    const identifier = body.email.trim().toLowerCase();
    const result = await db().query<{
      id: string;
      email: string;
      full_name: string;
      password_hash: string | null;
      status: string;
      identity_status: string;
      onboarding_complete: boolean;
    }>(
      `SELECT id, email, full_name, password_hash, status, identity_status, onboarding_complete
         FROM users
        WHERE lower(email) = $1 OR lower(split_part(email, '@', 1)) = $1
        ORDER BY CASE WHEN lower(email) = $1 THEN 0 ELSE 1 END, created_at ASC
        LIMIT 1`,
      [identifier],
    );
    const row = result.rows[0];
    const valid = row?.password_hash
      ? await bcrypt.compare(body.password, row.password_hash)
      : false;
    if (!row || !valid) {
      throw errors.unauthorized('ID or password is incorrect.');
    }
    if (row.status !== 'ACTIVE') {
      throw errors.forbidden('This account is suspended. Contact support.');
    }
    const roles = await rolesFor(row.id);
    const user: AuthUser = { id: row.id, email: row.email, roles };
    const session = await createSession(user, {
      userAgent: req.header('user-agent'),
      ip: req.ip,
    });
    await recordAudit(db(), {
      actorId: row.id,
      action: 'auth.login',
      resourceType: 'session',
      correlationId: req.requestId,
    });
    res.json({
      user: {
        id: row.id,
        email: row.email,
        fullName: row.full_name,
        roles,
        identityStatus: row.identity_status,
        onboardingComplete: row.onboarding_complete,
      },
      ...session,
    });
  }),
);

router.post(
  '/firebase',
  authLimiter,
  asyncHandler(async (req, res) => {
    const body = parseBody(firebaseSignInSchema, req.body);
    const identity = await verifyFirebaseIdToken(body.idToken);
    const email = identity.email?.trim().toLowerCase();
    if (
      !identity.email_verified ||
      identity.firebase?.sign_in_provider !== 'google.com' ||
      !email ||
      !identity.uid
    ) {
      throw errors.unauthorized(
        'Use a Google account with a verified email address.',
      );
    }

    let userId: string;
    let fullName: string;
    let identityStatus: string;
    let onboardingComplete: boolean;
    let isNewUser = false;
    const existing = await db().query<{
      id: string;
      email: string;
      full_name: string;
      status: string;
      identity_status: string;
      onboarding_complete: boolean;
    }>(
      `SELECT id, email, full_name, status, identity_status, onboarding_complete
         FROM users
        WHERE firebase_uid = $1`,
      [identity.uid],
    );

    if (existing.rows[0]) {
      const row = existing.rows[0];
      if (row.status !== 'ACTIVE') {
        throw errors.forbidden('This account is suspended. Contact support.');
      }
      if (row.email.toLowerCase() !== email) {
        const conflictingEmail = await db().query<{ id: string }>(
          'SELECT id FROM users WHERE lower(email) = $1 AND id <> $2',
          [email, row.id],
        );
        if (conflictingEmail.rows.length > 0) {
          throw errors.conflict(
            'EMAIL_ALREADY_REGISTERED',
            'This Google email is already used by another account.',
          );
        }
        try {
          await db().query(
            'UPDATE users SET email = $1, updated_at = now() WHERE id = $2',
            [email, row.id],
          );
        } catch (error) {
          if (
            typeof error === 'object' &&
            error !== null &&
            'code' in error &&
            error.code === '23505'
          ) {
            throw errors.conflict(
              'EMAIL_ALREADY_REGISTERED',
              'This Google email is already used by another account.',
            );
          }
          throw error;
        }
      }
      userId = row.id;
      fullName = row.full_name;
      identityStatus = row.identity_status;
      onboardingComplete = row.onboarding_complete;

      // Ensure the role selected during Google sign-in is granted to the user
      await db().query(
        'INSERT INTO user_roles (user_id, role) VALUES ($1, $2) ON CONFLICT DO NOTHING',
        [userId, body.role],
      );
      if (body.role === 'WORKER') {
        await db().query(
          `INSERT INTO worker_profiles (user_id, public_name, verification_status)
           VALUES ($1, $2, 'PENDING') ON CONFLICT DO NOTHING`,
          [userId, fullName],
        );
      } else {
        await db().query(
          `INSERT INTO employer_profiles (user_id, display_name)
           VALUES ($1, $2) ON CONFLICT DO NOTHING`,
          [userId, fullName],
        );
      }
    } else {
      const emailOwner = await db().query<{ id: string }>(
        'SELECT id FROM users WHERE lower(email) = $1',
        [email],
      );
      if (emailOwner.rows.length > 0) {
        throw errors.conflict(
          'EMAIL_ALREADY_REGISTERED',
          'This email already has an account. Sign in with that method before linking Google.',
        );
      }

      userId = newId();
      identityStatus = 'NOT_STARTED';
      onboardingComplete = false;
      fullName =
        typeof identity.name === 'string' && identity.name.trim().length >= 2
          ? identity.name.trim().slice(0, 120)
          : email.split('@')[0].slice(0, 120);
      try {
        await withTransaction(async (tx) => {
          await tx.query(
            `INSERT INTO users (id, email, password_hash, firebase_uid, full_name)
             VALUES ($1, $2, NULL, $3, $4)`,
            [userId, email, identity.uid, fullName],
          );
          await tx.query('INSERT INTO user_roles (user_id, role) VALUES ($1, $2)', [
            userId,
            body.role,
          ]);
          if (body.role === 'WORKER') {
            await tx.query(
              `INSERT INTO worker_profiles (user_id, public_name, verification_status)
               VALUES ($1, $2, 'PENDING')`,
              [userId, fullName],
            );
          } else {
            await tx.query(
              `INSERT INTO employer_profiles (user_id, display_name)
               VALUES ($1, $2)`,
              [userId, fullName],
            );
          }
          await recordAudit(tx, {
            actorId: userId,
            action: 'auth.firebase_register',
            resourceType: 'user',
            resourceId: userId,
            correlationId: req.requestId,
          });
        });
        isNewUser = true;
      } catch (error) {
        if (
          typeof error === 'object' &&
          error !== null &&
          'code' in error &&
          error.code === '23505'
        ) {
          throw errors.conflict(
            'ACCOUNT_ALREADY_EXISTS',
            'An account with this Google identity or email already exists. Sign in again.',
          );
        }
        throw error;
      }
    }

    const roles = await rolesFor(userId);
    const user: AuthUser = { id: userId, email, roles };
    const session = await createSession(user, {
      userAgent: req.header('user-agent'),
      ip: req.ip,
    });
    if (!isNewUser) {
      await recordAudit(db(), {
        actorId: userId,
        action: 'auth.firebase_login',
        resourceType: 'session',
        correlationId: req.requestId,
      });
    }
    res.status(isNewUser ? 201 : 200).json({
      user: {
        id: userId,
        email,
        fullName,
        roles,
        identityStatus,
        onboardingComplete,
      },
      ...session,
    });
  }),
);

router.post(
  '/refresh',
  authLimiter,
  asyncHandler(async (req, res) => {
    const body = parseBody(refreshSchema, req.body);
    const tokenHash = sha256(body.refreshToken);
    const result = await db().query<{
      id: string;
      user_id: string;
      expires_at: Date;
      revoked_at: Date | null;
    }>(
      `SELECT id, user_id, expires_at, revoked_at FROM sessions
        WHERE refresh_token_hash = $1`,
      [tokenHash],
    );
    const session = result.rows[0];
    if (!session || new Date(session.expires_at).getTime() <= Date.now()) {
      throw errors.unauthorized('Refresh token is invalid or expired.');
    }
    if (session.revoked_at) {
      // A rotated (already-used) token came back: treat it as stolen and
      // revoke every session of this user (blueprint Figure 4).
      await db().query(
        'UPDATE sessions SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL',
        [session.user_id],
      );
      await recordAudit(db(), {
        actorId: session.user_id,
        action: 'auth.refresh_reuse',
        resourceType: 'session',
        resourceId: session.id,
        outcome: 'DENIED',
        correlationId: req.requestId,
      });
      logger.warn(
        { userId: session.user_id, requestId: req.requestId },
        'refresh token reuse detected; all sessions revoked',
      );
      throw errors.unauthorized('Refresh token is invalid or expired.');
    }
    const userResult = await db().query<{
      id: string;
      email: string;
      full_name: string;
      status: string;
      identity_status: string;
      onboarding_complete: boolean;
    }>(
      `SELECT id, email, full_name, status, identity_status, onboarding_complete
         FROM users WHERE id = $1`,
      [session.user_id],
    );
    const userRow = userResult.rows[0];
    if (!userRow || userRow.status !== 'ACTIVE') throw errors.unauthorized('Account is not active.');
    const roles = await rolesFor(userRow.id);

    await db().query('UPDATE sessions SET revoked_at = now() WHERE id = $1', [session.id]);
    const tokens = await createSession(
      { id: userRow.id, email: userRow.email, roles },
      { userAgent: req.header('user-agent'), ip: req.ip },
    );
    res.json({
      user: {
        id: userRow.id,
        email: userRow.email,
        fullName: userRow.full_name,
        roles,
        identityStatus: userRow.identity_status,
        onboardingComplete: userRow.onboarding_complete,
      },
      ...tokens,
    });
  }),
);

router.post(
  '/logout',
  authenticate,
  asyncHandler(async (req, res) => {
    const body = parseBody(refreshSchema.partial(), req.body ?? {});
    if (body.refreshToken) {
      await db().query(
        'UPDATE sessions SET revoked_at = now() WHERE user_id = $1 AND refresh_token_hash = $2',
        [req.user!.id, sha256(body.refreshToken)],
      );
    } else {
      await db().query('UPDATE sessions SET revoked_at = now() WHERE user_id = $1', [req.user!.id]);
    }
    await recordAudit(db(), {
      actorId: req.user!.id,
      action: 'auth.logout',
      resourceType: 'session',
      correlationId: req.requestId,
    });
    res.status(204).end();
  }),
);

router.get(
  '/session',
  authenticate,
  asyncHandler(async (req, res) => {
    const result = await db().query<{ id: string; email: string; full_name: string; phone: string | null }>(
      'SELECT id, email, full_name, phone FROM users WHERE id = $1',
      [req.user!.id],
    );
    if (!result.rows[0]) throw errors.unauthorized();
    const roles = await rolesFor(req.user!.id);
    res.json({
      user: {
        id: result.rows[0].id,
        email: result.rows[0].email,
        fullName: result.rows[0].full_name,
        phone: result.rows[0].phone,
        roles,
      },
      serverTime: new Date().toISOString(),
    });
  }),
);

export { rolesFor };
export default router;
