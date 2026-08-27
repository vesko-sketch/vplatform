import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../identity/prisma.service.js';
import type {
  AccessCandidate,
  ApplicationRecord,
  DatedRecord,
  FirmRecord,
  PermissionOverrideRecord,
  PermissionRecord,
  RoleAssignmentRecord,
  RolePermissionRecord,
  UserRecord,
} from './authorization.types.js';

const applicationSelect = {
  access_zone: true,
  code: true,
  id: true,
  is_active: true,
  name: true,
} as const;

const firmSelect = {
  code: true,
  id: true,
  is_active: true,
  name: true,
  short_name: true,
} as const;

function application(record: {
  access_zone: string;
  code: string;
  id: string;
  is_active: boolean;
  name: string;
}): ApplicationRecord {
  return {
    accessZone: record.access_zone,
    code: record.code,
    id: record.id,
    isActive: record.is_active,
    name: record.name,
  };
}

function firm(record: {
  code: string;
  id: string;
  is_active: boolean;
  name: string;
  short_name: string | null;
}): FirmRecord {
  return {
    code: record.code,
    id: record.id,
    isActive: record.is_active,
    name: record.name,
    shortName: record.short_name,
  };
}

function dated(record: {
  is_active: boolean;
  valid_from: Date | null;
  valid_to: Date | null;
}): DatedRecord {
  return { isActive: record.is_active, validFrom: record.valid_from, validTo: record.valid_to };
}

@Injectable()
export class AuthorizationRepository {
  constructor(private readonly prisma: PrismaService) {}

  async findUser(id: string): Promise<UserRecord | null> {
    const row = await this.prisma.users.findUnique({
      select: { display_name: true, email: true, id: true, is_active: true },
      where: { id },
    });
    return row === null
      ? null
      : { displayName: row.display_name, email: row.email, id: row.id, isActive: row.is_active };
  }

  async findApplication(code: string): Promise<ApplicationRecord | null> {
    const row = await this.prisma.applications.findUnique({
      select: applicationSelect,
      where: { code },
    });
    return row === null ? null : application(row);
  }

  async findFirm(id: string): Promise<FirmRecord | null> {
    const row = await this.prisma.firms.findUnique({ select: firmSelect, where: { id } });
    return row === null ? null : firm(row);
  }

  async findFirmApplication(firmId: string, applicationId: string): Promise<DatedRecord | null> {
    const rows = await this.prisma.$queryRaw<
      Array<{ is_active: boolean; valid_from: Date | null; valid_to: Date | null }>
    >(Prisma.sql`
      SELECT is_active, valid_from, valid_to
      FROM public.firm_applications
      WHERE firm_id = ${firmId}::uuid AND application_id = ${applicationId}::uuid
    `);
    const row = rows[0];
    return row === undefined ? null : dated(row);
  }

  async findUserApplication(
    userId: string,
    firmId: string,
    applicationId: string,
  ): Promise<DatedRecord | null> {
    const rows = await this.prisma.$queryRaw<
      Array<{ is_active: boolean; valid_from: Date | null; valid_to: Date | null }>
    >(Prisma.sql`
      SELECT is_active, valid_from, valid_to
      FROM public.user_firm_applications
      WHERE user_id = ${userId}::uuid
        AND firm_id = ${firmId}::uuid
        AND application_id = ${applicationId}::uuid
    `);
    const row = rows[0];
    return row === undefined ? null : dated(row);
  }

  async listApplicationPermissions(applicationId: string): Promise<PermissionRecord[]> {
    const rows = await this.prisma.permissions.findMany({
      orderBy: { code: 'asc' },
      select: { application_id: true, code: true, id: true, is_active: true },
      where: { application_id: applicationId },
    });
    return rows.map((row) => ({
      applicationId: row.application_id,
      code: row.code,
      id: row.id,
      isActive: row.is_active,
    }));
  }

  async permissionCodeExistsOutsideApplication(
    code: string,
    applicationId: string,
  ): Promise<boolean> {
    return (
      (await this.prisma.permissions.count({
        where: { application_id: { not: applicationId }, code },
      })) > 0
    );
  }

  async listRoleAssignments(userId: string, firmId: string): Promise<RoleAssignmentRecord[]> {
    const rows = await this.prisma.user_firm_roles.findMany({
      select: {
        id: true,
        is_active: true,
        roles: { select: { code: true, id: true, is_active: true } },
        valid_from: true,
        valid_to: true,
      },
      where: { firm_id: firmId, user_id: userId },
    });
    return rows.map((row) => ({
      id: row.id,
      isActive: row.is_active,
      role: { code: row.roles.code, id: row.roles.id, isActive: row.roles.is_active },
      validFrom: row.valid_from,
      validTo: row.valid_to,
    }));
  }

  async listRolePermissions(roleIds: string[]): Promise<RolePermissionRecord[]> {
    if (roleIds.length === 0) return [];
    const rows = await this.prisma.$queryRaw<
      Array<{
        application_id: string;
        code: string;
        permission_id: string;
        permission_is_active: boolean;
        role_id: string;
        role_permission_is_active: boolean;
      }>
    >(Prisma.sql`
      SELECT rp.role_id, rp.permission_id,
             rp.is_active AS role_permission_is_active,
             p.application_id, p.code, p.is_active AS permission_is_active
      FROM public.role_permissions rp
      JOIN public.permissions p ON p.id = rp.permission_id
      WHERE rp.role_id IN (${Prisma.join(roleIds.map((roleId) => Prisma.sql`${roleId}::uuid`))})
    `);
    return rows.map((row) => ({
      isActive: row.role_permission_is_active,
      permission: {
        applicationId: row.application_id,
        code: row.code,
        id: row.permission_id,
        isActive: row.permission_is_active,
      },
      roleId: row.role_id,
    }));
  }

  async listOverrides(
    userId: string,
    firmId: string,
    applicationId: string,
  ): Promise<PermissionOverrideRecord[]> {
    const rows = await this.prisma.user_permission_overrides.findMany({
      select: {
        effect: true,
        firm_id: true,
        id: true,
        permission_id: true,
        valid_from: true,
        valid_to: true,
      },
      where: {
        OR: [{ firm_id: null }, { firm_id: firmId }],
        permissions: { application_id: applicationId },
        user_id: userId,
      },
    });
    return rows.map((row) => ({
      effect: row.effect,
      firmId: row.firm_id,
      id: row.id,
      permissionId: row.permission_id,
      validFrom: row.valid_from,
      validTo: row.valid_to,
    }));
  }

  async listAccessCandidates(userId: string): Promise<AccessCandidate[]> {
    const rows = await this.prisma.$queryRaw<
      Array<{
        application_id: string;
        firm_id: string;
        is_active: boolean;
        valid_from: Date | null;
        valid_to: Date | null;
      }>
    >(Prisma.sql`
      SELECT application_id, firm_id, is_active, valid_from, valid_to
      FROM public.user_firm_applications
      WHERE user_id = ${userId}::uuid
    `);
    const applicationIds = [...new Set(rows.map((row) => row.application_id))];
    const firmIds = [...new Set(rows.map((row) => row.firm_id))];
    const [applicationRows, firmRows] = await Promise.all([
      this.prisma.applications.findMany({
        select: applicationSelect,
        where: { id: { in: applicationIds } },
      }),
      this.prisma.firms.findMany({ select: firmSelect, where: { id: { in: firmIds } } }),
    ]);
    const applications = new Map(applicationRows.map((row) => [row.id, application(row)]));
    const firms = new Map(firmRows.map((row) => [row.id, firm(row)]));

    const candidates: AccessCandidate[] = [];
    for (const row of rows) {
      const mappedApplication = applications.get(row.application_id);
      const mappedFirm = firms.get(row.firm_id);
      if (mappedApplication === undefined || mappedFirm === undefined) continue;
      candidates.push({
        application: mappedApplication,
        firm: mappedFirm,
        firmApplication: await this.findFirmApplication(mappedFirm.id, mappedApplication.id),
        userApplication: dated(row),
      });
    }
    return candidates;
  }
}
