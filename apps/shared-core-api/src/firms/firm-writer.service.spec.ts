import { ServiceUnavailableException } from '@nestjs/common';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { FirmWriterClient, FirmWriterService } from './firm-writer.service.js';

describe('FirmWriterService failure handling', () => {
  afterEach(() => vi.unstubAllEnvs());
  it('fails closed when the writer URL is unavailable', async () => {
    vi.stubEnv('SHARED_CORE_FIRM_WRITER_DATABASE_URL', '');
    const client = new FirmWriterClient();
    const service = new FirmWriterService(client);
    await expect(
      service.create(
        {
          baseCurrencyId: '00000000-0000-4000-8000-000000000001',
          code: 'X',
          countryId: '00000000-0000-4000-8000-000000000002',
          name: 'X',
        },
        {
          actorUserId: '00000000-0000-4000-8000-000000000003',
          correlationId: '00000000-0000-4000-8000-000000000004',
          requestId: '00000000-0000-4000-8000-000000000005',
        },
        new Date(),
      ),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
    await client.$disconnect();
  });
  it('sanitizes unexpected database failures', async () => {
    const client = {
      configured: true,
      $transaction: vi.fn().mockRejectedValue(new Error('raw database detail')),
    };
    const service = new FirmWriterService(client as unknown as FirmWriterClient);
    await expect(
      service.create(
        {
          baseCurrencyId: '00000000-0000-4000-8000-000000000001',
          code: 'X',
          countryId: '00000000-0000-4000-8000-000000000002',
          name: 'X',
        },
        {
          actorUserId: '00000000-0000-4000-8000-000000000003',
          correlationId: '00000000-0000-4000-8000-000000000004',
          requestId: '00000000-0000-4000-8000-000000000005',
        },
        new Date(),
      ),
    ).rejects.toMatchObject({ message: 'Firm command storage is unavailable' });
  });
});
