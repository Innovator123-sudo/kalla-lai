import type { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { config } from '../config.js';
import { errors } from './errors.js';
import type { Role } from './roles.js';

export interface AuthUser {
  id: string;
  email: string;
  roles: Role[];
}

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      user?: AuthUser;
      requestId: string;
    }
  }
}

interface AccessClaims {
  sub: string;
  email: string;
  roles: Role[];
}

export function signAccessToken(user: AuthUser) {
  return jwt.sign(
    { email: user.email, roles: user.roles } satisfies Omit<AccessClaims, 'sub'>,
    config.JWT_ACCESS_SECRET,
    { subject: user.id, expiresIn: config.JWT_ACCESS_TTL_SECONDS, issuer: 'kalla-lai' },
  );
}

export function verifyAccessToken(token: string): AuthUser {
  const claims = jwt.verify(token, config.JWT_ACCESS_SECRET, {
    issuer: 'kalla-lai',
  }) as jwt.JwtPayload & Omit<AccessClaims, 'sub'>;
  return {
    id: String(claims.sub),
    email: String(claims.email),
    roles: (claims.roles ?? []) as Role[],
  };
}

export function authenticate(req: Request, res: Response, next: NextFunction) {
  const header = req.header('authorization');
  if (!header?.startsWith('Bearer ')) return next(errors.unauthorized());
  try {
    req.user = verifyAccessToken(header.slice(7));
    res.setHeader('Cache-Control', 'no-store');
    return next();
  } catch {
    return next(errors.unauthorized('Your session has expired. Sign in again.'));
  }
}

/** Attach a user when a valid token is present, but never reject the request. */
export function authenticateOptional(req: Request, _res: Response, next: NextFunction) {
  const header = req.header('authorization');
  if (header?.startsWith('Bearer ')) {
    try {
      req.user = verifyAccessToken(header.slice(7));
    } catch {
      // Ignore invalid credentials on public endpoints.
    }
  }
  return next();
}

export function requireRoles(...roles: Role[]) {
  return (req: Request, _res: Response, next: NextFunction) => {
    if (!req.user) return next(errors.unauthorized());
    const allowed = req.user.roles.some((r) => roles.includes(r));
    if (!allowed) return next(errors.forbidden());
    return next();
  };
}

export const requireWorker = requireRoles('WORKER');
export const requireEmployer = requireRoles('EMPLOYER');
export const requireStaff = requireRoles('MODERATOR', 'BILLING_ADMIN', 'ADMIN');
