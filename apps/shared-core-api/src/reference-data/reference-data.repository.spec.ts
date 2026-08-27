import { describe, expect, it, vi } from 'vitest';
import type { Prisma } from '@prisma/client';

import type { PrismaService } from '../identity/prisma.service.js';
import { ReferenceDataRepository } from './reference-data.repository.js';

describe('ReferenceDataRepository', () => {
  it('uses active-only, allowlisted, deterministically ordered projections', async () => {
    const query = vi.fn().mockResolvedValue([]);
    const repository = new ReferenceDataRepository({
      $queryRaw: query,
    } as unknown as PrismaService);
    await repository.countries();
    await repository.currencies();
    await repository.languages();
    await repository.legalForms();
    const calls = query.mock.calls as unknown as Array<[Prisma.Sql]>;
    const sql = calls.map(([value]) => value.strings.join(' ')).join('\n');
    expect(sql).toContain('WHERE is_active ORDER BY iso2_code,id');
    expect(sql).toContain('WHERE is_active ORDER BY iso_code,id');
    expect(sql).toContain('WHERE is_active ORDER BY code,id');
    expect(sql).not.toMatch(/metadata|row_version|source_system|external_id/);
  });
});
