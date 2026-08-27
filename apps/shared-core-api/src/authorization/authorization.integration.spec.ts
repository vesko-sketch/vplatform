import { PrismaClient } from '@prisma/client';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { AuthorizationRepository } from './authorization.repository.js';
import { AuthorizationService } from './authorization.service.js';

const enabled = process.env.SHARED_CORE_AUTHORIZATION_INTEGRATION === '1';
const prisma = new PrismaClient();
const ids = {
  country: '91000000-0000-4000-8000-000000000001',
  currency: '91000000-0000-4000-8000-000000000002',
  firmA: '91000000-0000-4000-8000-000000000003',
  firmB: '91000000-0000-4000-8000-000000000004',
  user: '91000000-0000-4000-8000-000000000005',
};
const at = new Date('2026-08-27T09:00:00.000Z');

describe.skipIf(!enabled)('AuthorizationService disposable PostgreSQL integration', () => {
  let service: AuthorizationService;
  let officeId: string;
  let accountingId: string;
  let accountantRoleId: string;
  let managerRoleId: string;
  let officeOverridePermissionId: string;

  beforeAll(async () => {
    const office = await prisma.applications.findUniqueOrThrow({ where: { code: 'OFFICE' } });
    const accounting = await prisma.applications.findUniqueOrThrow({
      where: { code: 'ACCOUNTING' },
    });
    const accountant = await prisma.roles.findUniqueOrThrow({ where: { code: 'accountant' } });
    const manager = await prisma.roles.findUniqueOrThrow({ where: { code: 'manager' } });
    const officeOverridePermission = await prisma.permissions.findUniqueOrThrow({
      where: { application_id_code: { application_id: office.id, code: 'system.settings.manage' } },
    });
    officeId = office.id;
    accountingId = accounting.id;
    accountantRoleId = accountant.id;
    managerRoleId = manager.id;
    officeOverridePermissionId = officeOverridePermission.id;

    await prisma.ref_countries.create({
      data: { id: ids.country, iso2_code: 'ZZ', name_bg: 'Disposable test country' },
    });
    await prisma.ref_currencies.create({
      data: { id: ids.currency, iso_code: 'ZZZ', name: 'Disposable test currency' },
    });
    await prisma.users.create({
      data: { email: 'authorization-integration@example.test', id: ids.user },
    });
    await prisma.firms.createMany({
      data: [
        {
          base_currency_id: ids.currency,
          code: 'AUTH_INT_A',
          country_id: ids.country,
          id: ids.firmA,
          name: 'Authorization Integration A',
        },
        {
          base_currency_id: ids.currency,
          code: 'AUTH_INT_B',
          country_id: ids.country,
          id: ids.firmB,
          name: 'Authorization Integration B',
        },
      ],
    });
    await prisma.firm_applications.createMany({
      data: [
        { application_id: officeId, firm_id: ids.firmA },
        { application_id: accountingId, firm_id: ids.firmA },
        {
          application_id: officeId,
          firm_id: ids.firmB,
          valid_to: new Date('2026-08-26T00:00:00.000Z'),
        },
      ],
    });
    await prisma.user_firm_applications.createMany({
      data: [
        { application_id: officeId, firm_id: ids.firmA, user_id: ids.user },
        { application_id: accountingId, firm_id: ids.firmA, user_id: ids.user },
        { application_id: officeId, firm_id: ids.firmB, user_id: ids.user },
      ],
    });
    await prisma.user_firm_roles.createMany({
      data: [
        { firm_id: ids.firmA, role_id: accountantRoleId, user_id: ids.user },
        { firm_id: ids.firmA, role_id: managerRoleId, user_id: ids.user },
      ],
    });
    service = new AuthorizationService(new AuthorizationRepository(prisma as never));
  });

  afterAll(async () => {
    if (enabled) {
      await prisma.user_permission_overrides.deleteMany({ where: { user_id: ids.user } });
      await prisma.user_firm_roles.deleteMany({ where: { user_id: ids.user } });
      await prisma.user_firm_applications.deleteMany({ where: { user_id: ids.user } });
      await prisma.firm_applications.deleteMany({
        where: { firm_id: { in: [ids.firmA, ids.firmB] } },
      });
      await prisma.firms.deleteMany({ where: { id: { in: [ids.firmA, ids.firmB] } } });
      await prisma.users.delete({ where: { id: ids.user } });
      await prisma.ref_currencies.delete({ where: { id: ids.currency } });
      await prisma.ref_countries.delete({ where: { id: ids.country } });
    }
    await prisma.$disconnect();
  });

  it('resolves multiple-role Office capability through real relations', async () => {
    await expect(
      service.can({
        applicationCode: 'OFFICE',
        evaluatedAt: at,
        firmId: ids.firmA,
        permissionCode: 'documents.view',
        platformUserId: ids.user,
      }),
    ).resolves.toMatchObject({ basePermissionGranted: true, reason: 'allowed' });
  });

  it('keeps identical Office and Accounting codes isolated by application', async () => {
    await expect(
      service.can({
        applicationCode: 'ACCOUNTING',
        evaluatedAt: at,
        firmId: ids.firmA,
        permissionCode: 'documents.view',
        platformUserId: ids.user,
      }),
    ).resolves.toMatchObject({ basePermissionGranted: false, reason: 'permission_not_granted' });
  });

  it('excludes an expired second firm from access enumeration', async () => {
    await expect(service.listFirms(ids.user, at)).resolves.toEqual([
      expect.objectContaining({ id: ids.firmA }),
    ]);
  });

  it('applies a real firm-specific override after the access gate', async () => {
    const created = await prisma.user_permission_overrides.create({
      data: {
        effect: 'allow',
        firm_id: ids.firmA,
        permission_id: officeOverridePermissionId,
        user_id: ids.user,
      },
    });
    try {
      await expect(
        service.can({
          applicationCode: 'OFFICE',
          evaluatedAt: at,
          firmId: ids.firmA,
          permissionCode: 'system.settings.manage',
          platformUserId: ids.user,
        }),
      ).resolves.toMatchObject({ basePermissionGranted: true });
    } finally {
      await prisma.user_permission_overrides.delete({ where: { id: created.id } });
    }
  });
});
