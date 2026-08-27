import { BadRequestException } from '@nestjs/common';
import { describe, expect, it } from 'vitest';

import { endRelationship, validity } from './access-provisioning.validation.js';

describe('access provisioning validation', () => {
  it('accepts validity and lifecycle commands', () => {
    expect(
      validity({ expectedRowVersion: '2', validFrom: '2026-08-27', validTo: '2026-08-28' }),
    ).toEqual({ expectedRowVersion: 2n, validFrom: '2026-08-27', validTo: '2026-08-28' });
    expect(endRelationship({ expectedRowVersion: 3, reason: ' reviewed ' })).toEqual({
      expectedRowVersion: 3n,
      reason: 'reviewed',
    });
  });
  it('rejects invalid windows, unknown fields and missing versions', () => {
    expect(() => validity({ validFrom: '2026-08-28', validTo: '2026-08-27' })).toThrow(
      BadRequestException,
    );
    expect(() => validity({ metadata: {} })).toThrow(BadRequestException);
    expect(() => endRelationship({ reason: 'missing version' })).toThrow(BadRequestException);
  });
});
