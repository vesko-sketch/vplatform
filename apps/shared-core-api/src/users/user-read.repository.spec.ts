import { describe, expect, it, vi } from 'vitest';

import type { PrismaService } from '../identity/prisma.service.js';
import { UserReadRepository } from './user-read.repository.js';

describe('UserReadRepository access view', () => {
  it('keeps application roles, firm access, and firm roles separate', async () => {
    const query = vi
      .fn()
      .mockResolvedValueOnce([
        { application_code: 'OFFICE', role_code: 'admin', valid_from: null, valid_to: null },
      ])
      .mockResolvedValueOnce([
        {
          application_code: 'OFFICE',
          firm_code: 'DEV',
          firm_id: 'firm',
          firm_name: 'Development',
          valid_from: null,
          valid_to: null,
        },
      ])
      .mockResolvedValueOnce([
        {
          firm_code: 'DEV',
          firm_id: 'firm',
          firm_name: 'Development',
          role_code: 'admin',
          role_name: 'Administrator',
          valid_from: null,
          valid_to: null,
        },
      ]);
    const repository = new UserReadRepository({
      $queryRaw: query,
      users: { count: vi.fn().mockResolvedValue(1) },
    } as unknown as PrismaService);
    await expect(repository.access('user', '2026-08-27')).resolves.toEqual({
      applicationRoles: [
        {
          applicationCode: 'OFFICE',
          isActive: true,
          roleCode: 'admin',
          validFrom: null,
          validTo: null,
        },
      ],
      firms: [
        {
          applications: [
            { accessActive: true, applicationCode: 'OFFICE', validFrom: null, validTo: null },
          ],
          firm: { code: 'DEV', id: 'firm', name: 'Development' },
          roles: [
            {
              isActive: true,
              roleCode: 'admin',
              roleName: 'Administrator',
              validFrom: null,
              validTo: null,
            },
          ],
        },
      ],
      userId: 'user',
    });
  });

  it('returns empty relationships for an authorization-empty user', async () => {
    const query = vi.fn().mockResolvedValue([]);
    const repository = new UserReadRepository({
      $queryRaw: query,
      users: { count: vi.fn().mockResolvedValue(1) },
    } as unknown as PrismaService);
    await expect(repository.access('user', '2026-08-27')).resolves.toEqual({
      applicationRoles: [],
      firms: [],
      userId: 'user',
    });
  });
});
