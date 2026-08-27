import { describe, expect, it } from 'vitest';
import { createInvitation, redemptionToken, versionedReason } from './user.validation.js';

describe('user administration validation', () => {
  it('normalizes invitation email and allowlists fields', () => {
    expect(
      createInvitation({ email: '  DEV@Example.Invalid ', displayName: ' Dev User ' }),
    ).toEqual({ email: 'dev@example.invalid', displayName: 'Dev User' });
    expect(() =>
      createInvitation({ email: 'a@b.test', displayName: 'A', role: 'admin' }),
    ).toThrow();
  });
  it('requires optimistic concurrency and a reason', () => {
    expect(versionedReason({ expectedRowVersion: '2', reason: ' reviewed ' })).toEqual({
      expectedRowVersion: 2n,
      reason: 'reviewed',
    });
    expect(() => versionedReason({ expectedRowVersion: 1, reason: '' })).toThrow();
  });
  it('accepts only opaque URL-safe high-entropy tokens', () => {
    expect(redemptionToken({ token: 'a'.repeat(43) })).toHaveLength(43);
    expect(() => redemptionToken({ token: 'short' })).toThrow();
  });
});
