import { BadRequestException, ConflictException, ForbiddenException } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { FirmWriterClient, FirmWriterService } from './firm-writer.service.js';

const enabled = process.env.SHARED_CORE_FIRM_COMMAND_INTEGRATION === '1';
const prisma = new PrismaClient();
const ids = {
  user: 'fa340001-0000-4000-8000-000000000001',
  country: 'fa340002-0000-4000-8000-000000000002',
  currency: 'fa340003-0000-4000-8000-000000000003',
};
const context = {
  actorUserId: ids.user,
  requestId: 'fa340004-0000-4000-8000-000000000004',
  correlationId: 'fa340005-0000-4000-8000-000000000005',
};
const at = new Date('2026-08-27T12:00:00Z');

describe.skipIf(!enabled)('FirmWriterService disposable PostgreSQL integration', () => {
  let client: FirmWriterClient;
  let service: FirmWriterService;
  let officeId: string;
  let adminId: string;
  let createdId: string;
  beforeAll(async () => {
    officeId = (await prisma.applications.findUniqueOrThrow({ where: { code: 'OFFICE' } })).id;
    adminId = (await prisma.roles.findUniqueOrThrow({ where: { code: 'admin' } })).id;
    await prisma.ref_countries.create({
      data: { id: ids.country, iso2_code: 'Y4', name_bg: 'Firm command country' },
    });
    await prisma.ref_currencies.create({
      data: { id: ids.currency, iso_code: 'YFC', name: 'Firm command currency' },
    });
    await prisma.users.create({ data: { id: ids.user, email: 'firm-command@example.test' } });
    await prisma.user_application_roles.create({
      data: { user_id: ids.user, application_id: officeId, role_id: adminId },
    });
    client = new FirmWriterClient();
    service = new FirmWriterService(client);
  });
  afterAll(async () => {
    if (enabled) {
      await prisma.audit_log.deleteMany({ where: { user_id: ids.user } });
      if (createdId !== undefined) {
        await prisma.user_firm_roles.deleteMany({ where: { firm_id: createdId } });
        await prisma.user_firm_applications.deleteMany({ where: { firm_id: createdId } });
        await prisma.firm_applications.deleteMany({ where: { firm_id: createdId } });
        await prisma.firms.deleteMany({ where: { id: createdId } });
      }
      await prisma.user_application_roles.deleteMany({ where: { user_id: ids.user } });
      await prisma.users.deleteMany({ where: { id: ids.user } });
      await prisma.ref_currencies.deleteMany({ where: { id: ids.currency } });
      await prisma.ref_countries.deleteMany({ where: { id: ids.country } });
    }
    await client?.$disconnect();
    await prisma.$disconnect();
  });

  it('creates only a firm master and audits it', async () => {
    const firm = await service.create(
      {
        baseCurrencyId: ids.currency,
        code: 'PHASE3A4_INT',
        countryId: ids.country,
        name: 'Phase 3A.4 Integration',
      },
      context,
      at,
    );
    createdId = firm.id;
    expect(firm.rowVersion).toBe(1n);
    expect(await prisma.firm_applications.count({ where: { firm_id: firm.id } })).toBe(0);
    expect(await prisma.user_firm_applications.count({ where: { firm_id: firm.id } })).toBe(0);
    expect(await prisma.user_firm_roles.count({ where: { firm_id: firm.id } })).toBe(0);
    expect(
      await prisma.audit_log.count({ where: { entity_id: firm.id, action: 'firm.created' } }),
    ).toBe(1);
  });
  it('sanitizes duplicate and invalid-reference errors', async () => {
    await expect(
      service.create(
        {
          baseCurrencyId: ids.currency,
          code: 'PHASE3A4_INT',
          countryId: ids.country,
          name: 'Duplicate',
        },
        context,
        at,
      ),
    ).rejects.toBeInstanceOf(ConflictException);
    await expect(
      service.create(
        {
          baseCurrencyId: ids.currency,
          code: 'PHASE3A4_BAD_REF',
          countryId: 'fa349999-0000-4000-8000-000000000099',
          name: 'Bad ref',
        },
        context,
        at,
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
  it('does not turn application catalog authority into firm access', async () => {
    await expect(
      service.updateProfile(createdId, { expectedRowVersion: 1n, name: 'Denied' }, context, at),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect((await prisma.firms.findUniqueOrThrow({ where: { id: createdId } })).name).toBe(
      'Phase 3A.4 Integration',
    );
  });
  it('enforces firm permissions, row versions, lifecycle, and application activation', async () => {
    await prisma.firm_applications.create({
      data: { firm_id: createdId, application_id: officeId },
    });
    await prisma.user_firm_applications.create({
      data: { user_id: ids.user, firm_id: createdId, application_id: officeId },
    });
    await prisma.user_firm_roles.create({
      data: { user_id: ids.user, firm_id: createdId, role_id: adminId },
    });
    const updated = await service.updateProfile(
      createdId,
      { expectedRowVersion: 1n, name: 'Updated Integration' },
      context,
      at,
    );
    expect(updated.rowVersion).toBe(2n);
    await expect(
      service.updateProfile(createdId, { expectedRowVersion: 1n, name: 'Stale' }, context, at),
    ).rejects.toBeInstanceOf(ConflictException);
    const deactivated = await service.deactivate(
      createdId,
      { expectedRowVersion: 2n, reason: 'Disposable lifecycle verification' },
      context,
      at,
    );
    expect(deactivated.isActive).toBe(false);
    const activated = await service.activate(
      createdId,
      { expectedRowVersion: 3n, reason: 'Disposable lifecycle verification' },
      context,
      at,
    );
    expect(activated.isActive).toBe(true);
    expect(activated.rowVersion).toBe(4n);
  });
  it('rechecks authorization inside the write transaction', async () => {
    await prisma.user_firm_applications.deleteMany({
      where: { user_id: ids.user, firm_id: createdId },
    });
    await expect(
      service.updateProfile(
        createdId,
        { expectedRowVersion: 4n, name: 'Must remain unchanged' },
        context,
        at,
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect((await prisma.firms.findUniqueOrThrow({ where: { id: createdId } })).name).toBe(
      'Updated Integration',
    );
  });
});
