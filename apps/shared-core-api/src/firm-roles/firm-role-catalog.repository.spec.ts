import { describe, expect, it, vi } from 'vitest';

import type { PrismaService } from '../identity/prisma.service.js';
import { FirmRoleCatalogRepository } from './firm-role-catalog.repository.js';

describe('FirmRoleCatalogRepository', () => {
  it('selects only the safe active projection in deterministic order', async () => {
    const findMany = vi.fn().mockResolvedValue([]);
    const repository = new FirmRoleCatalogRepository({
      roles: { findMany },
    } as unknown as PrismaService);
    await repository.listActive();
    expect(findMany).toHaveBeenCalledWith({
      orderBy: [{ code: 'asc' }, { id: 'asc' }],
      select: { code: true, id: true, name: true },
      where: { is_active: true },
    });
  });
});
