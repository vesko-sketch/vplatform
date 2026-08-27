import { BadRequestException } from '@nestjs/common';
import { describe, expect, it } from 'vitest';

import {
  createFirm,
  lifecycle,
  updateIdentity,
  updateProfile,
  updateSettings,
} from './firm.validation.js';

const country = '00000000-0000-4000-8000-000000000001';
const currency = '00000000-0000-4000-8000-000000000002';

describe('firm command DTO validation', () => {
  it('accepts only the create allowlist', () => {
    expect(
      createFirm({
        code: 'TEST',
        name: 'Test',
        country_id: country,
        base_currency_id: currency,
        short_name: null,
      }),
    ).toMatchObject({
      code: 'TEST',
      countryId: country,
      baseCurrencyId: currency,
      shortName: null,
    });
    expect(() =>
      createFirm({
        code: 'TEST',
        name: 'Test',
        country_id: country,
        base_currency_id: currency,
        is_active: false,
      }),
    ).toThrow(BadRequestException);
  });
  it('keeps profile, identity, and settings fields separate', () => {
    expect(updateProfile({ expectedRowVersion: 1, name: 'Changed' })).toMatchObject({
      expectedRowVersion: 1n,
      name: 'Changed',
    });
    expect(() => updateProfile({ expectedRowVersion: 1, code: 'NO' })).toThrow(BadRequestException);
    expect(updateIdentity({ expectedRowVersion: '2', registration_number: null })).toMatchObject({
      expectedRowVersion: 2n,
      registrationNumber: null,
    });
    expect(() => updateIdentity({ expectedRowVersion: 1, base_currency_id: currency })).toThrow(
      BadRequestException,
    );
    expect(updateSettings({ expectedRowVersion: 3, base_currency_id: currency })).toEqual({
      expectedRowVersion: 3n,
      baseCurrencyId: currency,
    });
  });
  it('requires lifecycle reason and a positive row version', () => {
    expect(lifecycle({ expectedRowVersion: 1, reason: 'Reviewed reactivation' })).toEqual({
      expectedRowVersion: 1n,
      reason: 'Reviewed reactivation',
    });
    expect(() => lifecycle({ expectedRowVersion: 0, reason: 'x' })).toThrow(BadRequestException);
    expect(() => lifecycle({ expectedRowVersion: 1 })).toThrow(BadRequestException);
  });
});
