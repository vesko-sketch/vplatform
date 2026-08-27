import { ForbiddenException, ServiceUnavailableException } from '@nestjs/common';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import type { AuthorizationService } from '../authorization/authorization.service.js';
import type { FirmRoleCatalogRepository } from './firm-role-catalog.repository.js';
import { FirmRoleCatalogService } from './firm-role-catalog.service.js';

describe('FirmRoleCatalogService', () => {
  const roles = [
    { code: 'accountant', id: 'role-1', name: 'Accountant' },
    { code: 'manager', id: 'role-2', name: 'Manager' },
  ];
  let authorization: { canAtApplicationScope: ReturnType<typeof vi.fn> };
  let repository: { listActive: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    authorization = {
      canAtApplicationScope: vi.fn().mockResolvedValue({ basePermissionGranted: true }),
    };
    repository = { listActive: vi.fn().mockResolvedValue(roles) };
  });

  function service(): FirmRoleCatalogService {
    return new FirmRoleCatalogService(
      authorization as unknown as AuthorizationService,
      repository as unknown as FirmRoleCatalogRepository,
    );
  }

  it('uses OFFICE APPLICATION firms.roles.view and returns the safe catalog', async () => {
    await expect(service().list('actor', new Date('2026-08-27T00:00:00Z'))).resolves.toEqual(roles);
    expect(authorization.canAtApplicationScope).toHaveBeenCalledWith({
      applicationCode: 'OFFICE',
      evaluatedAt: new Date('2026-08-27T00:00:00Z'),
      permissionCode: 'firms.roles.view',
      platformUserId: 'actor',
    });
  });

  it('denies users without application-scoped authority', async () => {
    authorization.canAtApplicationScope.mockResolvedValue({ basePermissionGranted: false });
    await expect(service().list('actor', new Date())).rejects.toBeInstanceOf(ForbiddenException);
    expect(repository.listActive).not.toHaveBeenCalled();
  });

  it('fails closed when authorization is unavailable', async () => {
    authorization.canAtApplicationScope.mockRejectedValue(new Error('database unavailable'));
    await expect(service().list('actor', new Date())).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });
});
