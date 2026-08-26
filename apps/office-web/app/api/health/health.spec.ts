import { describe, expect, it } from 'vitest';

import { getHealth } from './health';

describe('office-web health', () => {
  it('identifies the public application', () => {
    expect(getHealth()).toEqual({ service: 'office-web', status: 'ok', zone: 'public' });
  });
});
