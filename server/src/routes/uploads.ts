import { mkdirSync, readFileSync, writeFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { z } from 'zod';
import { config } from '../config.js';
import { db } from '../db/index.js';
import { authenticate } from '../lib/auth.js';
import { newId } from '../lib/crypto.js';
import { errors } from '../lib/errors.js';
import { asyncHandler } from '../lib/http.js';
import { parseBody } from '../lib/validation.js';

const router = Router();

const uploadLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 60,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
});

// Demo-only showcase media storage. Files live on local disk; the database
// keeps the metadata. This is never used for identity/biometric evidence.
const rules: Record<string, { mimes: string[]; maxBytes: number }> = {
  IMAGE: { mimes: ['image/jpeg', 'image/png', 'image/webp'], maxBytes: 8 * 1024 * 1024 },
  CV: {
    mimes: [
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    ],
    maxBytes: 8 * 1024 * 1024,
  },
  PROMO_VIDEO: {
    mimes: ['video/mp4', 'video/webm', 'video/quicktime'],
    maxBytes: 20 * 1024 * 1024,
  },
};

const uploadSchema = z.object({
  kind: z.enum(['IMAGE', 'CV', 'PROMO_VIDEO']),
  fileName: z.string().min(1).max(200),
  mimeType: z.string().min(3).max(120),
  dataBase64: z.string().min(16),
});

function uploadsDir(): string {
  const dir = path.resolve(process.cwd(), '.data/uploads');
  mkdirSync(dir, { recursive: true });
  return dir;
}

router.post(
  '/',
  authenticate,
  uploadLimiter,
  asyncHandler(async (req, res) => {
    if (!config.DEMO_MODE) {
      throw errors.unavailable(
        'UPLOADS_UNAVAILABLE',
        'File uploads are not enabled on this server.',
      );
    }
    const body = parseBody(uploadSchema, req.body);
    const rule = rules[body.kind];
    if (!rule.mimes.includes(body.mimeType)) {
      throw errors.badRequest(
        'UNSUPPORTED_MEDIA_TYPE',
        `Unsupported ${body.kind} format. Allowed: ${rule.mimes.join(', ')}.`,
      );
    }
    const base64 = body.dataBase64.includes(',')
      ? body.dataBase64.slice(body.dataBase64.indexOf(',') + 1)
      : body.dataBase64;
    let bytes: Buffer;
    try {
      bytes = Buffer.from(base64, 'base64');
    } catch {
      throw errors.badRequest('INVALID_FILE', 'The uploaded file could not be read.');
    }
    if (bytes.length === 0) {
      throw errors.badRequest('EMPTY_FILE', 'The uploaded file is empty.');
    }
    if (bytes.length > rule.maxBytes) {
      throw errors.badRequest(
        'FILE_TOO_LARGE',
        `File is too large. Maximum ${Math.round(rule.maxBytes / (1024 * 1024))} MB for ${body.kind}.`,
      );
    }
    const id = newId();
    writeFileSync(path.join(uploadsDir(), `${id}.bin`), bytes);
    await db().query(
      `INSERT INTO uploads (id, user_id, kind, mime_type, size_bytes, original_name)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [id, req.user!.id, body.kind, body.mimeType, bytes.length, body.fileName],
    );
    res.status(201).json({
      id,
      url: `/v1/uploads/${id}`,
      kind: body.kind,
      mimeType: body.mimeType,
      sizeBytes: bytes.length,
    });
  }),
);

router.get(
  '/:id',
  asyncHandler(async (req, res) => {
    const id = req.params.id;
    if (!/^[0-9a-f-]{36}$/i.test(id)) throw errors.notFound('File not found.');
    const meta = await db().query<{ mime_type: string; original_name: string | null }>(
      'SELECT mime_type, original_name FROM uploads WHERE id = $1',
      [id],
    );
    const row = meta.rows[0];
    if (!row) throw errors.notFound('File not found.');
    const file = path.join(uploadsDir(), `${id}.bin`);
    if (!existsSync(file)) throw errors.notFound('File not found.');
    res.setHeader('content-type', row.mime_type);
    res.setHeader('cache-control', 'public, max-age=3600');
    res.send(readFileSync(file));
  }),
);

export default router;