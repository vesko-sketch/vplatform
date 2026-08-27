import { Injectable } from '@nestjs/common';

import { PrismaService } from '../identity/prisma.service.js';
import type {
  FirmApplicationView,
  UserApplicationAccessView,
  UserFirmRoleView,
} from './access-provisioning.types.js';

@Injectable()
export class AccessProvisioningReadRepository {
  constructor(private readonly prisma: PrismaService) {}

  listFirmApplications(firmId: string): Promise<FirmApplicationView[]> {
    return this.prisma.firm_applications
      .findMany({
        orderBy: { applications: { code: 'asc' } },
        select: {
          applications: { select: { code: true, id: true, name: true } },
          created_at: true,
          id: true,
          is_active: true,
          row_version: true,
          updated_at: true,
          valid_from: true,
          valid_to: true,
        },
        where: { firm_id: firmId },
      })
      .then((rows) =>
        rows.map((row) => ({
          applicationCode: row.applications.code,
          applicationId: row.applications.id,
          applicationName: row.applications.name,
          createdAt: row.created_at,
          id: row.id,
          isActive: row.is_active,
          rowVersion: row.row_version,
          updatedAt: row.updated_at,
          validFrom: row.valid_from,
          validTo: row.valid_to,
        })),
      );
  }

  listUserAccess(firmId: string, applicationCode: string): Promise<UserApplicationAccessView[]> {
    return this.prisma.user_firm_applications
      .findMany({
        orderBy: [{ users: { display_name: 'asc' } }, { user_id: 'asc' }],
        select: {
          applications: { select: { code: true, id: true, name: true } },
          created_at: true,
          id: true,
          is_active: true,
          row_version: true,
          updated_at: true,
          users: { select: { display_name: true, email: true, id: true } },
          valid_from: true,
          valid_to: true,
        },
        where: { applications: { code: applicationCode }, firm_id: firmId },
      })
      .then((rows) =>
        rows.map((row) => ({
          applicationCode: row.applications.code,
          applicationId: row.applications.id,
          applicationName: row.applications.name,
          createdAt: row.created_at,
          displayName: row.users.display_name,
          email: row.users.email,
          id: row.id,
          isActive: row.is_active,
          rowVersion: row.row_version,
          updatedAt: row.updated_at,
          userId: row.users.id,
          validFrom: row.valid_from,
          validTo: row.valid_to,
        })),
      );
  }

  listUserRoles(firmId: string, userId: string): Promise<UserFirmRoleView[]> {
    return this.prisma.user_firm_roles
      .findMany({
        orderBy: { roles: { code: 'asc' } },
        select: {
          created_at: true,
          id: true,
          is_active: true,
          roles: { select: { code: true, id: true, name: true } },
          row_version: true,
          updated_at: true,
          user_id: true,
          valid_from: true,
          valid_to: true,
        },
        where: { firm_id: firmId, user_id: userId },
      })
      .then((rows) =>
        rows.map((row) => ({
          createdAt: row.created_at,
          id: row.id,
          isActive: row.is_active,
          roleCode: row.roles.code,
          roleId: row.roles.id,
          roleName: row.roles.name,
          rowVersion: row.row_version,
          updatedAt: row.updated_at,
          userId: row.user_id,
          validFrom: row.valid_from,
          validTo: row.valid_to,
        })),
      );
  }
}
