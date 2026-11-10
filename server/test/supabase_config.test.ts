import { describe, expect, it } from 'vitest';
import { assembleDbUrl, encodeDbPassword, supabase } from '../src/config.js';

describe('Supabase connection-string assembly', () => {
  it('percent-encodes a raw # in a pasted connection string', () => {
    const raw =
      'postgresql://postgres.abcdefghijklmnopqrst:Example!Pass#2026@aws-0-ap-south-1.pooler.supabase.com:6543/postgres';
    const encoded = encodeDbPassword(raw);
    expect(encoded).toContain('Pass%232026@');
    expect(encoded).toContain('@aws-0-ap-south-1.pooler.supabase.com:6543/postgres');
    // Encoding an already-encoded string must be a no-op.
    expect(encodeDbPassword(encoded)).toBe(encoded);
  });

  it('builds a transaction-pooler URL from a project ref and host', () => {
    const url = assembleDbUrl({
      password: 'Example!Pass#2026',
      projectRef: 'abcdefghijklmnopqrst',
      host: 'aws-0-ap-south-1.pooler.supabase.com',
    });
    expect(url).toBe(
      'postgresql://postgres.abcdefghijklmnopqrst:Example!Pass%232026@aws-0-ap-south-1.pooler.supabase.com:6543/postgres',
    );
  });

  it('falls back to the direct host when no pooler host is given', () => {
    const url = assembleDbUrl({
      password: 'simple',
      projectRef: 'abcdefghijklmnopqrst',
    });
    expect(url).toBe(
      'postgresql://postgres.abcdefghijklmnopqrst:simple@db.abcdefghijklmnopqrst.supabase.co:5432/postgres',
    );
  });

  it('returns null until the password and an endpoint are known', () => {
    expect(assembleDbUrl({})).toBeNull();
    expect(assembleDbUrl({ password: 'only-a-password' })).toBeNull();
    expect(assembleDbUrl({ projectRef: 'abcdefghijklmnopqrst' })).toBeNull();
  });

  it('never points the test suite at a live Supabase project', () => {
    // server/.env may hold real credentials; the fixture seeder must never
    // write demo rows into that database.
    expect(supabase.dbUrl).toBeNull();
    expect(supabase.url).toBeNull();
  });
});
