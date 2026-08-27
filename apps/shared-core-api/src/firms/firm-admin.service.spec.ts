import { ForbiddenException, ServiceUnavailableException } from '@nestjs/common';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import type { AuthorizationService } from '../authorization/authorization.service.js';
import { FirmAdminService } from './firm-admin.service.js';
import type { FirmReadRepository } from './firm-read.repository.js';
import type { FirmWriterService } from './firm-writer.service.js';

const at = new Date('2026-08-27T12:00:00Z');
const actor = '00000000-0000-4000-8000-000000000001';
const firmId = '00000000-0000-4000-8000-000000000002';
const context = {
  actorUserId: actor,
  correlationId: '00000000-0000-4000-8000-000000000003',
  requestId: '00000000-0000-4000-8000-000000000004',
};

describe('FirmAdminService', () => {
  let authorization: {
    can: ReturnType<typeof vi.fn>;
    canAtApplicationScope: ReturnType<typeof vi.fn>;
  };
  let reads: { find: ReturnType<typeof vi.fn>; list: ReturnType<typeof vi.fn> };
  let writer: Record<string, ReturnType<typeof vi.fn>>;
  let service: FirmAdminService;
  beforeEach(() => {
    authorization = {
      can: vi.fn().mockResolvedValue({ basePermissionGranted: true }),
      canAtApplicationScope: vi.fn().mockResolvedValue({ basePermissionGranted: true }),
    };
    reads = { find: vi.fn(), list: vi.fn().mockResolvedValue([]) };
    writer = {
      activate: vi.fn(),
      create: vi.fn(),
      deactivate: vi.fn(),
      updateIdentity: vi.fn(),
      updateProfile: vi.fn(),
      updateSettings: vi.fn(),
    };
    service = new FirmAdminService(
      authorization as unknown as AuthorizationService,
      reads as unknown as FirmReadRepository,
      writer as unknown as FirmWriterService,
    );
  });
  it('uses application scope for create, catalog, and activation', async () => {
    await service.list(actor, at);
    await service.create(
      { baseCurrencyId: firmId, code: 'T', countryId: firmId, name: 'T' },
      context,
      at,
    );
    await service.activate(firmId, { expectedRowVersion: 1n, reason: 'reactivate' }, context, at);
    expect(authorization.canAtApplicationScope).toHaveBeenCalledWith(
      expect.objectContaining({ permissionCode: 'firms.catalog.view' }),
    );
    expect(authorization.canAtApplicationScope).toHaveBeenCalledWith(
      expect.objectContaining({ permissionCode: 'firms.create' }),
    );
    expect(authorization.canAtApplicationScope).toHaveBeenCalledWith(
      expect.objectContaining({ permissionCode: 'firms.activate' }),
    );
    expect(authorization.can).not.toHaveBeenCalled();
  });
  it('uses firm scope for profile, identity, settings, and disable', async () => {
    await service.updateProfile(firmId, { expectedRowVersion: 1n, name: 'x' }, context, at);
    await service.updateIdentity(firmId, { expectedRowVersion: 1n, code: 'X' }, context, at);
    await service.updateSettings(
      firmId,
      { baseCurrencyId: firmId, expectedRowVersion: 1n },
      context,
      at,
    );
    await service.deactivate(firmId, { expectedRowVersion: 1n, reason: 'x' }, context, at);
    expect(authorization.can).toHaveBeenCalledTimes(4);
    expect(authorization.canAtApplicationScope).not.toHaveBeenCalled();
  });
  it('never reaches the writer after preliminary denial', async () => {
    authorization.canAtApplicationScope.mockResolvedValue({ basePermissionGranted: false });
    await expect(
      service.create(
        { baseCurrencyId: firmId, code: 'T', countryId: firmId, name: 'T' },
        context,
        at,
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(writer.create).not.toHaveBeenCalled();
  });
  it('fails closed when authorization is unavailable', async () => {
    authorization.canAtApplicationScope.mockRejectedValue(new Error('down'));
    await expect(service.list(actor, at)).rejects.toBeInstanceOf(ServiceUnavailableException);
    expect(reads.list).not.toHaveBeenCalled();
  });
});
