import { Test } from '@nestjs/testing';
import { describe, expect, it } from 'vitest';

import { HealthController } from './health.controller.js';

describe('HealthController', () => {
  it('reports a healthy shared-core-api process', async () => {
    const moduleRef = await Test.createTestingModule({ controllers: [HealthController] }).compile();

    expect(moduleRef.get(HealthController).getHealth()).toEqual({
      service: 'shared-core-api',
      status: 'ok',
    });
  });
});
