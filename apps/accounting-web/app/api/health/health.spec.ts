import { describe, expect, it } from 'vitest';

import { getHealth } from './health';

describe('accounting-web health', () => {
  it('identifies the private application', () => {
    expect(getHealth()).toEqual({ service: 'accounting-web', status: 'ok', zone: 'private' });
  });
});
