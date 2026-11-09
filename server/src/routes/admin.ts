import { Router } from 'express';
import { z } from 'zod';
import { db, withTransaction } from '../db/index.js';
import { recordAudit } from '../lib/audit.js';
import { authenticate, requireStaff } from '../lib/auth.js';
import { errors } from '../lib/errors.js';
import { asyncHandler } from '../lib/http.js';
import { notify } from '../lib/notify.js';
import { ROLES, type Role } from '../lib/roles.js';
import { parseBody, parseQuery } from '../lib/validation.js';

const router = Router();

/**
 * Platform staff (moderator / billing admin / admin) can browse every account
 * and edit its profile: account fields, roles, and the worker or employer
 * profile sheet. Every change is audited and notifies the affected user.
 */

const listQuery = z.object({
  q: z.string().max(120).optional(),
  role: z.enum(['ALL', ...ROLES]).optional(),
  limit: z.coerce.number().int().min(1).max(200).default(60),
});

const userPatch = z
  .object({
    fullName: z.string().trim().min(2).max(120),
    phone: z.string().trim().max(40),
    status: z.enum(['ACTIVE', 'SUSPENDED']),
    identityStatus: z.enum(['NOT_STARTED', 'PENDING', 'NEEDS_ACTION', 'VERIFIED', 'REJECTED']),
    roles: z.array(z.enum(ROLES)).max(5),
  })
  .partial();

const workerProfilePatch = z
  .object({
    publicName: z.string().trim().min(2).max(120),
    baseArea: z.string().trim().max(160),
    minRateNpr: z.number().int().min(0).max(10_000_000),
    rateNegotiable: z.boolean(),
    availability: z.string().max(500),
    tagline: z.string().max(160),
    bio: z.string().max(2000),
    verificationStatus: z.enum(['UNVERIFIED', 'PENDING', 'VERIFIED', 'REJECTED']),
  })
  .partial();

const employerProfilePatch = z
  .object({
    displayName: z.string().trim().min(2).max(160),
    organization: z.string().trim().max(160),
    trustStatus: z.enum(['UNVERIFIED', 'VERIFIED', 'SUSPENDED']),
    profilePictureUrl: z.string().max(300),
    bio: z.string().max(2000),
    tagline: z.string().max(160),
    baseArea: z.string().max(160),
    latitude: z.number().min(-90).max(90),
    longitude: z.number().min(-180).max(180),
    contactPhone: z.string().max(40),
    websiteUrl: z.string().max(300),
    categories: z.array(z.string().min(1).max(60)).max(30),
    languages: z.array(z.string().min(1).max(60)).max(20),
    portfolioUrls: z.array(z.string().min(1).max(300)).max(10),
  })
  .partial();

const patchSchema = z
  .object({
    user: userPatch.optional(),
    workerProfile: workerProfilePatch.optional(),
    employerProfile: employerProfilePatch.optional(),
  })
  .refine(
    (body) => body.user !== undefined || body.workerProfile !== undefined || body.employerProfile !== undefined,
    { message: 'Nothing to update.' },
  );

interface WorkerProfileView {
  publicName: string | null;
  baseArea: string | null;
  minRateNpr: number | null;
  rateNegotiable: boolean | null;
  availability: string | null;
  tagline: string | null;
  bio: string | null;
  verificationStatus: string | null;
}

interface EmployerProfileView {
  displayName: string | null;
  organization: string | null;
  trustStatus: string | null;
}

interface PersonRow {
  id: string;
  email: string;
  full_name: string;
  phone: string | null;
  status: string;
  identity_status: string;
  onboarding_complete: boolean;
  created_at: Date;
  wp_exists: boolean;
  ep_exists: boolean;
  wp_public_name: string | null;
  wp_base_area: string | null;
  wp_min_rate_npr: string | number | null;
  wp_rate_negotiable: boolean | null;
  wp_availability: string | null;
  wp_tagline: string | null;
  wp_bio: string | null;
  wp_verification_status: string | null;
  ep_display_name: string | null;
  ep_organization: string | null;
  ep_trust_status: string | null;
  ep_profile_picture_url: string | null;
  ep_bio: string | null;
  ep_tagline: string | null;
  ep_base_area: string | null;
  ep_contact_phone: string | null;
  ep_website_url: string | null;
  ep_categories: string[] | null;
  ep_languages: string[] | null;
  ep_portfolio_urls: string[] | null;
}

function toPerson(row: PersonRow, roles: string[]) {
  return {
    id: row.id,
    email: row.email,
    fullName: row.full_name,
    phone: row.phone,
    status: row.status,
    identityStatus: row.identity_status,
    onboardingComplete: row.onboarding_complete,
    roles,
    createdAt: row.created_at instanceof Date ? row.created_at.toISOString() : row.created_at,
    workerProfile: row.wp_exists
      ? {
        publicName: row.wp_public_name,
        baseArea: row.wp_base_area,
        minRateNpr: row.wp_min_rate_npr === null ? null : Number(row.wp_min_rate_npr),
        rateNegotiable: row.wp_rate_negotiable,
        availability: row.wp_availability,
        tagline: row.wp_tagline,
        bio: row.wp_bio,
        verificationStatus: row.wp_verification_status,
      }
      : null,
    employerProfile: row.ep_exists
      ? {
        displayName: row.ep_display_name,
        organization: row.ep_organization,
        trustStatus: row.ep_trust_status,
        profilePictureUrl: row.ep_profile_picture_url,
        bio: row.ep_bio,
        tagline: row.ep_tagline,
        baseArea: row.ep_base_area,
        contactPhone: row.ep_contact_phone,
        websiteUrl: row.ep_website_url,
        categories: row.ep_categories ?? [],
        languages: row.ep_languages ?? [],
        portfolioUrls: row.ep_portfolio_urls ?? [],
      }
      : null,
  };
}

async function loadPeople(ids: string[]) {
  if (ids.length === 0) return [] as ReturnType<typeof toPerson>[];
  const usersResult = await db().query<PersonRow>(
    `SELECT u.id, u.email, u.full_name, u.phone, u.status, u.identity_status,
            u.onboarding_complete, u.created_at,
            (wp.user_id IS NOT NULL) AS wp_exists, (ep.user_id IS NOT NULL) AS ep_exists,
            wp.public_name AS wp_public_name, wp.base_area AS wp_base_area,
            wp.min_rate_npr AS wp_min_rate_npr, wp.rate_negotiable AS wp_rate_negotiable,
            wp.availability AS wp_availability, wp.tagline AS wp_tagline, wp.bio AS wp_bio,
            wp.verification_status AS wp_verification_status,
            ep.display_name AS ep_display_name, ep.organization AS ep_organization,
            ep.trust_status AS ep_trust_status,
            ep.profile_picture_url AS ep_profile_picture_url,
            ep.bio AS ep_bio, ep.tagline AS ep_tagline,
            ep.base_area AS ep_base_area, ep.contact_phone AS ep_contact_phone,
            ep.website_url AS ep_website_url,
            ep.categories AS ep_categories, ep.languages AS ep_languages,
            ep.portfolio_urls AS ep_portfolio_urls
       FROM users u
       LEFT JOIN worker_profiles wp ON wp.user_id = u.id
       LEFT JOIN employer_profiles ep ON ep.user_id = u.id
      WHERE u.id = ANY($1)
      ORDER BY u.created_at DESC`,
    [ids],
  );
  const rolesResult = await db().query<{ user_id: string; role: string }>(
    'SELECT user_id, role FROM user_roles WHERE user_id = ANY($1)',
    [ids],
  );
  const rolesByUser = new Map<string, string[]>();
  for (const row of rolesResult.rows) {
    const list = rolesByUser.get(row.user_id) ?? [];
    list.push(row.role);
    rolesByUser.set(row.user_id, list);
  }
  return usersResult.rows.map((row) => toPerson(row, rolesByUser.get(row.id) ?? []));
}

router.get(
  '/people',
  authenticate,
  requireStaff,
  asyncHandler(async (req, res) => {
    const query = parseQuery(listQuery, req.query);
    const like = query.q
      ? `%${query.q.replace(/([%_\\])/g, (m) => `\\${m}`)}%`
      : null;
    const roleFilter = !query.role || query.role === 'ALL' ? null : query.role;
    const idResult = await db().query<{ id: string }>(
      `SELECT u.id FROM users u
        WHERE ($1::text IS NULL OR u.email ILIKE $1 ESCAPE '\\' OR u.full_name ILIKE $1 ESCAPE '\\')
          AND EXISTS (
            SELECT 1 FROM user_roles ur
             WHERE ur.user_id = u.id AND ($2::text IS NULL OR ur.role = $2)
          )
        ORDER BY u.created_at DESC
        LIMIT $3`,
      [like, roleFilter, query.limit],
    );
    const people = await loadPeople(idResult.rows.map((row) => row.id));
    res.json({ people, total: people.length });
  }),
);

router.get(
  '/people/:id',
  authenticate,
  requireStaff,
  asyncHandler(async (req, res) => {
    const id = z.string().uuid().safeParse(req.params.id);
    if (!id.success) throw errors.badRequest('INVALID_ID', 'The account id is not a valid identifier.');
    const [person] = await loadPeople([id.data]);
    if (!person) throw errors.notFound('That account does not exist.');
    res.json({ person });
  }),
);

router.patch(
  '/people/:id',
  authenticate,
  requireStaff,
  asyncHandler(async (req, res) => {
    const id = z.string().uuid().safeParse(req.params.id);
    if (!id.success) throw errors.badRequest('INVALID_ID', 'The account id is not a valid identifier.');
    const body = parseBody(patchSchema, req.body);

    const changed: string[] = [];
    await withTransaction(async (tx) => {
      const target = await tx.query<{ full_name: string }>(
        'SELECT full_name FROM users WHERE id = $1',
        [id.data],
      );
      if (!target.rows[0]) throw errors.notFound('That account does not exist.');

      const user = body.user;
      if (user) {
        const columnMap: Record<string, string> = {
          fullName: 'full_name',
          phone: 'phone',
          status: 'status',
          identityStatus: 'identity_status',
        };
        const entries = Object.entries(user).filter(([key, value]) => key !== 'roles' && value !== undefined);
        if (entries.length > 0) {
          const sets = entries.map(([key], index) => `${columnMap[key]} = $${index + 1}`);
          const values = entries.map(([, value]) => value);
          await tx.query(
            `UPDATE users SET ${sets.join(', ')}, updated_at = now() WHERE id = $${entries.length + 1}`,
            [...values, id.data],
          );
          for (const [key] of entries) changed.push(key);
        }
        if (user.roles !== undefined) {
          const current = await tx.query<{ role: string }>(
            'SELECT role FROM user_roles WHERE user_id = $1',
            [id.data],
          );
          const currentRoles = current.rows.map((row) => row.role as Role);
          const toAdd = user.roles.filter((role) => !currentRoles.includes(role));
          const toRemove = currentRoles.filter((role) => !user.roles!.includes(role));
          if (toAdd.length > 0 || toRemove.length > 0) {
            for (const role of toRemove) {
              await tx.query('DELETE FROM user_roles WHERE user_id = $1 AND role = $2', [id.data, role]);
            }
            for (const role of toAdd) {
              await tx.query('INSERT INTO user_roles (user_id, role) VALUES ($1, $2) ON CONFLICT DO NOTHING', [
                id.data,
                role,
              ]);
            }
            changed.push(`roles(${toAdd.join('+') || '-'}/${toRemove.join('-') || '-'})`);
          }
        }
      }

      if (body.workerProfile) {
        const columnMap: Record<string, string> = {
          publicName: 'public_name',
          baseArea: 'base_area',
          minRateNpr: 'min_rate_npr',
          rateNegotiable: 'rate_negotiable',
          availability: 'availability',
          tagline: 'tagline',
          bio: 'bio',
          verificationStatus: 'verification_status',
        };
        const entries = Object.entries(body.workerProfile).filter(([, value]) => value !== undefined);
        // Create the sheet on demand so an admin can configure a brand-new
        // worker profile even before the worker completes their own onboarding.
        const publicName = body.workerProfile.publicName ?? target.rows[0].full_name;
        await tx.query(
          `INSERT INTO worker_profiles (user_id, public_name) VALUES ($1, $2)
             ON CONFLICT (user_id) DO NOTHING`,
          [id.data, publicName],
        );
        if (entries.length > 0) {
          const sets = entries.map(([key], index) => `${columnMap[key]} = $${index + 1}`);
          const values = entries.map(([, value]) => value);
          await tx.query(
            `UPDATE worker_profiles SET ${sets.join(', ')}, updated_at = now()
               WHERE user_id = $${entries.length + 1}`,
            [...values, id.data],
          );
          changed.push('workerProfile');
        }
      }

      if (body.employerProfile) {
        const columnMap: Record<string, string> = {
          displayName: 'display_name',
          organization: 'organization',
          trustStatus: 'trust_status',
          profilePictureUrl: 'profile_picture_url',
          bio: 'bio',
          tagline: 'tagline',
          baseArea: 'base_area',
          latitude: 'latitude',
          longitude: 'longitude',
          contactPhone: 'contact_phone',
          websiteUrl: 'website_url',
          categories: 'categories',
          languages: 'languages',
          portfolioUrls: 'portfolio_urls',
        };
        const entries = Object.entries(body.employerProfile).filter(([, value]) => value !== undefined);
        const displayName = body.employerProfile.displayName ?? target.rows[0].full_name;
        await tx.query(
          `INSERT INTO employer_profiles (user_id, display_name) VALUES ($1, $2)
             ON CONFLICT (user_id) DO NOTHING`,
          [id.data, displayName],
        );
        if (entries.length > 0) {
          const sets = entries.map(([key], index) => `${columnMap[key]} = $${index + 1}`);
          const values = entries.map(([, value]) => value);
          await tx.query(
            `UPDATE employer_profiles SET ${sets.join(', ')}, updated_at = now()
               WHERE user_id = $${entries.length + 1}`,
            [...values, id.data],
          );
          changed.push('employerProfile');
        }
      }

      await recordAudit(tx, {
        actorId: req.user!.id,
        action: 'admin.person.update',
        resourceType: 'user',
        resourceId: id.data,
        correlationId: req.requestId,
        metadata: { changed },
      });
      await notify(tx, {
        userId: id.data,
        type: 'profile.updated',
        title: 'Profile updated',
        body: 'A platform administrator updated your profile details.',
        resourceType: 'user',
        resourceId: id.data,
      });
    });

    const [person] = await loadPeople([id.data]);
    res.json({ person, changed });
  }),
);

// ---------------------------------------------------------------------------
// Explicit profile configuration. An admin can create a worker or hirer sheet
// for any account (even before that person onboards), and remove one again.
// PATCH above remains the way to edit fields on an existing sheet.
// ---------------------------------------------------------------------------

const profileKindSchema = z.enum(['worker', 'employer']);

const workerColumns: Record<string, string> = {
  publicName: 'public_name',
  baseArea: 'base_area',
  minRateNpr: 'min_rate_npr',
  rateNegotiable: 'rate_negotiable',
  availability: 'availability',
  tagline: 'tagline',
  bio: 'bio',
  verificationStatus: 'verification_status',
};

const employerColumns: Record<string, string> = {
  displayName: 'display_name',
  organization: 'organization',
  trustStatus: 'trust_status',
  profilePictureUrl: 'profile_picture_url',
  bio: 'bio',
  tagline: 'tagline',
  baseArea: 'base_area',
  latitude: 'latitude',
  longitude: 'longitude',
  contactPhone: 'contact_phone',
  websiteUrl: 'website_url',
  categories: 'categories',
  languages: 'languages',
  portfolioUrls: 'portfolio_urls',
};

function parsePersonId(raw: string): string {
  const parsed = z.string().uuid().safeParse(raw);
  if (!parsed.success) {
    throw errors.badRequest('INVALID_ID', 'The account id is not a valid identifier.');
  }
  return parsed.data;
}

router.post(
  '/people/:id/profiles/:kind',
  authenticate,
  requireStaff,
  asyncHandler(async (req, res) => {
    const id = parsePersonId(req.params.id);
    const kind = profileKindSchema.safeParse(req.params.kind);
    if (!kind.success) {
      throw errors.badRequest('INVALID_PROFILE_KIND', 'Profile kind must be worker or employer.');
    }
    const patch =
      kind.data === 'worker'
        ? parseBody(workerProfilePatch, req.body ?? {})
        : parseBody(employerProfilePatch, req.body ?? {});

    await withTransaction(async (tx) => {
      const target = await tx.query<{ full_name: string }>(
        'SELECT full_name FROM users WHERE id = $1',
        [id],
      );
      if (!target.rows[0]) throw errors.notFound('That account does not exist.');

      const table = kind.data === 'worker' ? 'worker_profiles' : 'employer_profiles';
      const nameColumn = kind.data === 'worker' ? 'public_name' : 'display_name';
      const columns = kind.data === 'worker' ? workerColumns : employerColumns;
      const requestedName =
        kind.data === 'worker'
          ? (patch as z.infer<typeof workerProfilePatch>).publicName
          : (patch as z.infer<typeof employerProfilePatch>).displayName;

      // Idempotent: configuring an already-configured account is not an error.
      await tx.query(
        `INSERT INTO ${table} (user_id, ${nameColumn}) VALUES ($1, $2)
           ON CONFLICT (user_id) DO NOTHING`,
        [id, requestedName ?? target.rows[0].full_name],
      );

      const entries = Object.entries(patch).filter(([, value]) => value !== undefined);
      if (entries.length > 0) {
        const sets = entries.map(([key], index) => `${columns[key]} = $${index + 1}`);
        const values = entries.map(([, value]) => value);
        await tx.query(
          `UPDATE ${table} SET ${sets.join(', ')}, updated_at = now()
             WHERE user_id = $${entries.length + 1}`,
          [...values, id],
        );
      }

      await recordAudit(tx, {
        actorId: req.user!.id,
        action: 'admin.profile.create',
        resourceType: kind.data === 'worker' ? 'worker_profile' : 'employer_profile',
        resourceId: id,
        correlationId: req.requestId,
        metadata: { kind: kind.data, fields: entries.map(([key]) => key) },
      });
      await notify(tx, {
        userId: id,
        type: 'profile.updated',
        title: 'Profile configured',
        body:
          kind.data === 'worker'
            ? 'A platform administrator set up your worker profile.'
            : 'A platform administrator set up your hirer profile.',
        resourceType: 'user',
        resourceId: id,
      });
    });

    const [person] = await loadPeople([id]);
    res.status(201).json({ person });
  }),
);

router.delete(
  '/people/:id/profiles/:kind',
  authenticate,
  requireStaff,
  asyncHandler(async (req, res) => {
    const id = parsePersonId(req.params.id);
    const kind = profileKindSchema.safeParse(req.params.kind);
    if (!kind.success) {
      throw errors.badRequest('INVALID_PROFILE_KIND', 'Profile kind must be worker or employer.');
    }

    await withTransaction(async (tx) => {
      const exists = await tx.query<{ id: string }>('SELECT id FROM users WHERE id = $1', [id]);
      if (!exists.rows[0]) throw errors.notFound('That account does not exist.');
      const table = kind.data === 'worker' ? 'worker_profiles' : 'employer_profiles';
      const removed = await tx.query<{ user_id: string }>(
        `DELETE FROM ${table} WHERE user_id = $1 RETURNING user_id`,
        [id],
      );
      if (removed.rows.length === 0) {
        throw errors.notFound('That profile sheet does not exist.');
      }
      await recordAudit(tx, {
        actorId: req.user!.id,
        action: 'admin.profile.delete',
        resourceType: kind.data === 'worker' ? 'worker_profile' : 'employer_profile',
        resourceId: id,
        correlationId: req.requestId,
        metadata: { kind: kind.data },
      });
      await notify(tx, {
        userId: id,
        type: 'profile.updated',
        title: 'Profile removed',
        body:
          kind.data === 'worker'
            ? 'A platform administrator removed your worker profile.'
            : 'A platform administrator removed your hirer profile.',
        resourceType: 'user',
        resourceId: id,
      });
    });

    const [person] = await loadPeople([id]);
    res.json({ person });
  }),
);

export default router;
