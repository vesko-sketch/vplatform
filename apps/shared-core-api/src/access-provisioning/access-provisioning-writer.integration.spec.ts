import { ConflictException, ForbiddenException, ServiceUnavailableException } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { AuthorizationRepository } from '../authorization/authorization.repository.js';
import { AuthorizationService } from '../authorization/authorization.service.js';
import {
  AccessProvisioningWriterClient,
  AccessProvisioningWriterService,
} from './access-provisioning-writer.service.js';
import type { ProvisioningContext } from './access-provisioning.types.js';

const enabled = process.env.SHARED_CORE_ACCESS_PROVISIONING_INTEGRATION === '1';
const prisma = new PrismaClient();
const ids = {
  admin: '93000000-0000-4000-8000-000000000001',
  manager: '93000000-0000-4000-8000-000000000002',
  accountant: '93000000-0000-4000-8000-000000000003',
  client: '93000000-0000-4000-8000-000000000004',
  country: '93000000-0000-4000-8000-000000000005',
  currency: '93000000-0000-4000-8000-000000000006',
  firm: '93000000-0000-4000-8000-000000000007',
  target: '93000000-0000-4000-8000-000000000008',
};
const at = new Date('2026-08-27T09:00:00Z');
const context = (
  actorUserId: string,
  requestId = '93000000-0000-4000-8000-000000000009',
): ProvisioningContext => ({
  actorUserId,
  correlationId: '93000000-0000-4000-8000-000000000010',
  evaluatedAt: at,
  requestId,
});

describe.skipIf(!enabled)('access provisioning writer integration', () => {
  let writerClient: AccessProvisioningWriterClient;
  let writer: AccessProvisioningWriterService;
  let authorization: AuthorizationService;
  let officeId: string;
  let adminRoleId: string;

  beforeAll(async () => {
    officeId = (await prisma.applications.findUniqueOrThrow({ where: { code: 'OFFICE' } })).id;
    const roles = new Map((await prisma.roles.findMany()).map((role) => [role.code, role.id]));
    adminRoleId = roles.get('admin')!;
    await prisma.ref_countries.create({
      data: { id: ids.country, iso2_code: 'ZY', name_bg: 'Provision test' },
    });
    await prisma.ref_currencies.create({
      data: { id: ids.currency, iso_code: 'ZYY', name: 'Provision test' },
    });
    await prisma.users.createMany({
      data: [ids.admin, ids.manager, ids.accountant, ids.client, ids.target].map((id, index) => ({
        email: `provision-${index}@example.test`,
        id,
        lifecycle_status: 'ACTIVE',
      })),
    });
    await prisma.firms.create({
      data: {
        base_currency_id: ids.currency,
        code: 'PROVISION_INT',
        country_id: ids.country,
        id: ids.firm,
        name: 'Provision integration',
      },
    });
    await prisma.user_application_roles.createMany({
      data: [
        { application_id: officeId, role_id: roles.get('admin')!, user_id: ids.admin },
        { application_id: officeId, role_id: roles.get('manager')!, user_id: ids.manager },
        { application_id: officeId, role_id: roles.get('accountant')!, user_id: ids.accountant },
        { application_id: officeId, role_id: roles.get('client_owner')!, user_id: ids.client },
      ],
    });
    writerClient = new AccessProvisioningWriterClient();
    writer = new AccessProvisioningWriterService(writerClient);
    authorization = new AuthorizationService(new AuthorizationRepository(prisma as never));
  });

  afterAll(async () => {
    if (enabled) {
      await prisma.audit_log.deleteMany({ where: { firm_id: ids.firm } });
      await prisma.user_firm_roles.deleteMany({ where: { firm_id: ids.firm } });
      await prisma.user_firm_applications.deleteMany({ where: { firm_id: ids.firm } });
      await prisma.firm_applications.deleteMany({ where: { firm_id: ids.firm } });
      await prisma.user_application_roles.deleteMany({
        where: { user_id: { in: [ids.admin, ids.manager, ids.accountant, ids.client] } },
      });
      await prisma.firms.delete({ where: { id: ids.firm } });
      await prisma.users.deleteMany({
        where: { id: { in: [ids.admin, ids.manager, ids.accountant, ids.client, ids.target] } },
      });
      await prisma.ref_currencies.delete({ where: { id: ids.currency } });
      await prisma.ref_countries.delete({ where: { id: ids.country } });
    }
    await writerClient?.$disconnect();
    await prisma.$disconnect();
  });

  it('creates each layer idempotently and writes one audit per change', async () => {
    const firmApplication = await writer.enableFirmApplication(
      ids.firm,
      'OFFICE',
      { validFrom: null, validTo: null },
      context(ids.admin),
    );
    expect(
      (
        await writer.enableFirmApplication(
          ids.firm,
          'OFFICE',
          { validFrom: null, validTo: null },
          context(ids.admin),
        )
      ).id,
    ).toBe(firmApplication.id);
    const access = await writer.grantUserAccess(
      ids.firm,
      'OFFICE',
      ids.target,
      { validFrom: null, validTo: null },
      context(ids.admin),
    );
    expect(
      (
        await writer.grantUserAccess(
          ids.firm,
          'OFFICE',
          ids.target,
          { validFrom: null, validTo: null },
          context(ids.admin),
        )
      ).id,
    ).toBe(access.id);
    const role = await writer.assignRole(
      ids.firm,
      ids.target,
      'admin',
      { validFrom: null, validTo: null },
      context(ids.admin),
    );
    expect(
      (
        await writer.assignRole(
          ids.firm,
          ids.target,
          'admin',
          { validFrom: null, validTo: null },
          context(ids.admin),
        )
      ).id,
    ).toBe(role.id);
    expect(await prisma.audit_log.count({ where: { firm_id: ids.firm } })).toBe(3);
  });

  it('blocks disable dependencies and reuses revoked/disabled tuples', async () => {
    const fa = await prisma.firm_applications.findUniqueOrThrow({
      where: { firm_id_application_id: { application_id: officeId, firm_id: ids.firm } },
    });
    await expect(
      writer.disableFirmApplication(
        ids.firm,
        'OFFICE',
        { expectedRowVersion: fa.row_version, reason: 'blocked' },
        context(ids.admin),
      ),
    ).rejects.toSatisfy(
      (error: unknown) =>
        error instanceof ConflictException &&
        (error.getResponse() as { code?: string }).code === 'DEPENDENT_ACTIVE_USER_ACCESS',
    );
    const access = await prisma.user_firm_applications.findUniqueOrThrow({
      where: {
        user_id_firm_id_application_id: {
          application_id: officeId,
          firm_id: ids.firm,
          user_id: ids.target,
        },
      },
    });
    const revoked = await writer.revokeUserAccess(
      ids.firm,
      'OFFICE',
      ids.target,
      { expectedRowVersion: access.row_version, reason: 'revoke' },
      context(ids.admin),
    );
    await expect(
      authorization.can({
        applicationCode: 'OFFICE',
        evaluatedAt: at,
        firmId: ids.firm,
        permissionCode: 'documents.view',
        platformUserId: ids.target,
      }),
    ).resolves.toMatchObject({ reason: 'user_application_access_inactive' });
    await expect(
      authorization.canAtApplicationScope({
        applicationCode: 'OFFICE',
        evaluatedAt: at,
        permissionCode: 'firms.create',
        platformUserId: ids.admin,
      }),
    ).resolves.toMatchObject({ basePermissionGranted: true });
    const disabled = await writer.disableFirmApplication(
      ids.firm,
      'OFFICE',
      { expectedRowVersion: fa.row_version, reason: 'disable' },
      context(ids.admin),
    );
    expect(
      (
        await writer.enableFirmApplication(
          ids.firm,
          'OFFICE',
          { expectedRowVersion: disabled.rowVersion, validFrom: null, validTo: null },
          context(ids.admin),
        )
      ).id,
    ).toBe(fa.id);
    expect(
      (
        await writer.grantUserAccess(
          ids.firm,
          'OFFICE',
          ids.target,
          { expectedRowVersion: revoked.rowVersion, validFrom: null, validTo: null },
          context(ids.admin),
        )
      ).id,
    ).toBe(access.id);
    expect(
      await prisma.user_firm_roles.count({
        where: { firm_id: ids.firm, is_active: true, user_id: ids.target },
      }),
    ).toBe(1);
  });

  it('uses optimistic concurrency and reassigns the reserved role tuple', async () => {
    const role = await prisma.user_firm_roles.findUniqueOrThrow({
      where: {
        user_id_firm_id_role_id: { firm_id: ids.firm, role_id: adminRoleId, user_id: ids.target },
      },
    });
    await expect(
      writer.removeRole(
        ids.firm,
        ids.target,
        'admin',
        { expectedRowVersion: role.row_version + 1n, reason: 'stale' },
        context(ids.admin),
      ),
    ).rejects.toBeInstanceOf(ConflictException);
    const removed = await writer.removeRole(
      ids.firm,
      ids.target,
      'admin',
      { expectedRowVersion: role.row_version, reason: 'remove' },
      context(ids.admin),
    );
    expect(
      (
        await writer.assignRole(
          ids.firm,
          ids.target,
          'admin',
          { expectedRowVersion: removed.rowVersion, validFrom: null, validTo: null },
          context(ids.admin),
        )
      ).id,
    ).toBe(role.id);
  });

  it('enforces actor and target-role policy', async () => {
    await expect(
      writer.assignRole(
        ids.firm,
        ids.target,
        'admin',
        { validFrom: null, validTo: null },
        context(ids.manager),
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);
    await expect(
      writer.assignRole(
        ids.firm,
        ids.target,
        'accountant',
        { validFrom: null, validTo: null },
        context(ids.manager),
      ),
    ).resolves.toMatchObject({ roleCode: 'accountant' });
    await expect(
      writer.enableFirmApplication(
        ids.firm,
        'OFFICE',
        { validFrom: null, validTo: null },
        context(ids.accountant),
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);
    await expect(
      writer.enableFirmApplication(
        ids.firm,
        'OFFICE',
        { validFrom: null, validTo: null },
        context(ids.client),
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);
    await expect(
      writer.assignRole(
        ids.firm,
        ids.target,
        'unknown',
        { validFrom: null, validTo: null },
        context(ids.admin),
      ),
    ).rejects.toMatchObject({ status: 404 });
  });

  it('rolls back the relationship update when audit insertion fails', async () => {
    const access = await prisma.user_firm_applications.findUniqueOrThrow({
      where: {
        user_id_firm_id_application_id: {
          application_id: officeId,
          firm_id: ids.firm,
          user_id: ids.target,
        },
      },
    });
    await expect(
      writer.revokeUserAccess(
        ids.firm,
        'OFFICE',
        ids.target,
        { expectedRowVersion: access.row_version, reason: 'rollback' },
        context(ids.admin, 'invalid'),
      ),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
    await expect(
      prisma.user_firm_applications.findUniqueOrThrow({ where: { id: access.id } }),
    ).resolves.toMatchObject({ is_active: true, row_version: access.row_version });
  });
});
