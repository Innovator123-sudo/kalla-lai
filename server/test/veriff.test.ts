import { createHmac } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { isVeriffSignatureValid } from '../src/lib/veriff.js';

describe('Veriff webhook signatures', () => {
  const secret = 'local-test-shared-secret';
  const rawBody = Buffer.from('{"verification":{"status":"approved"}}');
  const signature = createHmac('sha256', secret).update(rawBody).digest('hex');

  it('accepts a valid signature over the exact raw body', () => {
    expect(isVeriffSignatureValid(rawBody, signature, secret)).toBe(true);
  });

  it('rejects altered bodies, wrong secrets, and malformed signatures', () => {
    expect(
      isVeriffSignatureValid(Buffer.from(`${rawBody.toString()} `), signature, secret),
    ).toBe(false);
    expect(isVeriffSignatureValid(rawBody, signature, 'wrong-secret')).toBe(false);
    expect(isVeriffSignatureValid(rawBody, 'not-a-signature', secret)).toBe(false);
  });
});
