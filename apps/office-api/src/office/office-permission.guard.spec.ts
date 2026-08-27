import { ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { describe, expect, it, vi } from 'vitest';

import { OfficePermissionGuard } from './office-permission.guard.js';
import type { SharedCoreAuthorizationClient } from '../shared-core/shared-core.client.js';

function context(request: unknown): never {
  return {
    getHandler: () => function handler() {},
    switchToHttp: () => ({ getRequest: () => request }),
  } as never;
}

describe('OfficePermissionGuard', () => {
  it('requires firm context and delegates the exact OFFICE permission decision', async () => {
    const client = { canOfficePermission: vi.fn().mockResolvedValue({ allowed: true }) };
    const reflector = { get: vi.fn().mockReturnValue('documents.view') };
    const guard = new OfficePermissionGuard(reflector as unknown as Reflector, client as never);
    await expect(
      guard.canActivate(context({ bearerToken: 'token', params: { firmId: 'firm-id' } })),
    ).resolves.toBe(true);
    expect(client.canOfficePermission).toHaveBeenCalledWith('token', 'firm-id', 'documents.view');
  });

  it('denies missing permissions and ignores browser role/permission headers', async () => {
    const client = { canOfficePermission: vi.fn().mockResolvedValue({ allowed: false }) };
    const reflector = { get: vi.fn().mockReturnValue('documents.view') };
    const guard = new OfficePermissionGuard(
      reflector as unknown as Reflector,
      client as unknown as SharedCoreAuthorizationClient,
    );
    await expect(
      guard.canActivate(
        context({
          bearerToken: 'token',
          headers: { 'x-permissions': 'documents.view', 'x-role': 'admin' },
          params: { firmId: 'arbitrary-firm' },
        }),
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });
});
