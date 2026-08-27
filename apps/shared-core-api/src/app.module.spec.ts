import { Test } from '@nestjs/testing';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { AppModule } from './app.module.js';
import { PrismaService } from './identity/prisma.service.js';

describe('AppModule', () => {
  afterEach(() => vi.unstubAllEnvs());

  it('wires the authentication guard into authorization routes', async () => {
    vi.stubEnv('OIDC_ISSUER_URL', 'https://identity.example.test/realms/vplatform');
    vi.stubEnv('OIDC_SHARED_CORE_API_CLIENT_ID', 'shared-core-api');
    vi.stubEnv('OIDC_SHARED_CORE_API_AUDIENCE', 'shared-core-api');
    vi.stubEnv('OIDC_SHARED_CORE_API_SIGNING_ALGORITHM', 'RS256');
    vi.stubEnv('OIDC_CLOCK_TOLERANCE_SECONDS', '5');
    const module = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(PrismaService)
      .useValue({ $disconnect: vi.fn() })
      .compile();

    expect(module).toBeDefined();
    await module.close();
  });
});
