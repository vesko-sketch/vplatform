import { Test } from '@nestjs/testing';
import { describe, expect, it } from 'vitest';

import { HealthController } from './health.controller.js';

describe('HealthController', () => {
  it('reports a healthy office-api process', async () => {
    const moduleRef = await Test.createTestingModule({ controllers: [HealthController] }).compile();

    expect(moduleRef.get(HealthController).getHealth()).toEqual({
      service: 'office-api',
      status: 'ok',
    });
  });
});
