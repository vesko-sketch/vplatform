import { describe, expect, it } from 'vitest';

import { getWorkerHealth } from './health.js';

describe('document-worker health', () => {
  it('identifies the worker as Office-owned', () => {
    expect(getWorkerHealth()).toEqual({
      service: 'document-worker',
      status: 'ready',
      domain: 'office',
    });
  });
});
