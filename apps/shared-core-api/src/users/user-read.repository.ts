import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../identity/prisma.service.js';
import type { InvitationView, UserAccessView, UserAdminView } from './user.types.js';

interface UserRow {
  created_at: Date;
  display_name: string | null;
  email: string;
  expires_at: Date | null;
  id: string;
  identity_linked: boolean;
  invitation_status: string | null;
  is_active: boolean;
  lifecycle_status: string;
  row_version: bigint;
  updated_at: Date;
}
interface InvitationRow {
  cancelled_at: Date | null;
  cancellation_reason: string | null;
  consumed_at: Date | null;
  created_at: Date;
  expires_at: Date;
  id: string;
  invited_email: string;
  row_version: bigint;
  status: string;
  updated_at: Date;
}
function user(row: UserRow): UserAdminView {
  return {
    createdAt: row.created_at,
    currentInvitationExpiresAt: row.expires_at,
    currentInvitationState: row.invitation_status,
    displayName: row.display_name,
    email: row.email,
    id: row.id,
    identityLinked: row.identity_linked,
    isActive: row.is_active,
    lifecycleStatus: row.lifecycle_status,
    rowVersion: row.row_version,
    updatedAt: row.updated_at,
  };
}
function invitation(row: InvitationRow): InvitationView {
  return {
    cancelledAt: row.cancelled_at,
    cancellationReason: row.cancellation_reason,
    consumedAt: row.consumed_at,
    createdAt: row.created_at,
    expiresAt: row.expires_at,
    id: row.id,
    invitedEmail: row.invited_email,
    rowVersion: row.row_version,
    status: row.status,
    updatedAt: row.updated_at,
  };
}
const projection = Prisma.sql`u.id,u.email,u.display_name,u.lifecycle_status,u.is_active,u.row_version,u.created_at,u.updated_at, EXISTS(SELECT 1 FROM public.user_external_identities e WHERE e.user_id=u.id AND e.status='active') AS identity_linked, i.status AS invitation_status,i.expires_at`;
@Injectable()
export class UserReadRepository {
  constructor(private readonly prisma: PrismaService) {}
  async list(): Promise<UserAdminView[]> {
    const rows = await this.prisma.$queryRaw<UserRow[]>(
      Prisma.sql`SELECT ${projection} FROM public.users u LEFT JOIN LATERAL (SELECT status,expires_at FROM public.user_invitations WHERE user_id=u.id ORDER BY created_at DESC LIMIT 1) i ON true ORDER BY u.email,u.id`,
    );
    return rows.map(user);
  }
  async find(id: string): Promise<UserAdminView | null> {
    const rows = await this.prisma.$queryRaw<UserRow[]>(
      Prisma.sql`SELECT ${projection} FROM public.users u LEFT JOIN LATERAL (SELECT status,expires_at FROM public.user_invitations WHERE user_id=u.id ORDER BY created_at DESC LIMIT 1) i ON true WHERE u.id=${id}::uuid`,
    );
    return rows[0] ? user(rows[0]) : null;
  }
  async invitations(userId: string): Promise<InvitationView[]> {
    const rows = await this.prisma.$queryRaw<InvitationRow[]>(
      Prisma.sql`SELECT id,invited_email,status,expires_at,consumed_at,cancelled_at,cancellation_reason,row_version,created_at,updated_at FROM public.user_invitations WHERE user_id=${userId}::uuid ORDER BY created_at DESC,id`,
    );
    return rows.map(invitation);
  }

  async access(userId: string, currentDate: string): Promise<UserAccessView | null> {
    const exists = await this.prisma.users.count({ where: { id: userId } });
    if (exists === 0) return null;
    const applicationRoles = await this.prisma.$queryRaw<
      Array<{
        application_code: string;
        role_code: string;
        valid_from: Date | null;
        valid_to: Date | null;
      }>
    >(Prisma.sql`
      SELECT a.code application_code,r.code role_code,uar.valid_from,uar.valid_to
      FROM public.user_application_roles uar
      JOIN public.applications a ON a.id=uar.application_id AND a.is_active
      JOIN public.roles r ON r.id=uar.role_id AND r.is_active
      WHERE uar.user_id=${userId}::uuid AND uar.is_active
        AND (uar.valid_from IS NULL OR uar.valid_from <= ${currentDate}::date)
        AND (uar.valid_to IS NULL OR uar.valid_to >= ${currentDate}::date)
      ORDER BY a.code,r.code
    `);
    const access = await this.prisma.$queryRaw<
      Array<{
        application_code: string;
        firm_code: string;
        firm_id: string;
        firm_name: string;
        valid_from: Date | null;
        valid_to: Date | null;
      }>
    >(Prisma.sql`
      SELECT f.id firm_id,f.code firm_code,f.name firm_name,a.code application_code,
             ufa.valid_from,ufa.valid_to
      FROM public.user_firm_applications ufa
      JOIN public.firms f ON f.id=ufa.firm_id AND f.is_active
      JOIN public.applications a ON a.id=ufa.application_id AND a.is_active
      JOIN public.firm_applications fa
        ON fa.firm_id=ufa.firm_id AND fa.application_id=ufa.application_id AND fa.is_active
      WHERE ufa.user_id=${userId}::uuid AND ufa.is_active
        AND (fa.valid_from IS NULL OR fa.valid_from <= ${currentDate}::date)
        AND (fa.valid_to IS NULL OR fa.valid_to >= ${currentDate}::date)
        AND (ufa.valid_from IS NULL OR ufa.valid_from <= ${currentDate}::date)
        AND (ufa.valid_to IS NULL OR ufa.valid_to >= ${currentDate}::date)
      ORDER BY f.code,a.code
    `);
    const roles = await this.prisma.$queryRaw<
      Array<{
        firm_code: string;
        firm_id: string;
        firm_name: string;
        role_code: string;
        role_name: string;
        valid_from: Date | null;
        valid_to: Date | null;
      }>
    >(Prisma.sql`
      SELECT f.id firm_id,f.code firm_code,f.name firm_name,r.code role_code,r.name role_name,
             ufr.valid_from,ufr.valid_to
      FROM public.user_firm_roles ufr
      JOIN public.firms f ON f.id=ufr.firm_id AND f.is_active
      JOIN public.roles r ON r.id=ufr.role_id AND r.is_active
      WHERE ufr.user_id=${userId}::uuid AND ufr.is_active
        AND (ufr.valid_from IS NULL OR ufr.valid_from <= ${currentDate}::date)
        AND (ufr.valid_to IS NULL OR ufr.valid_to >= ${currentDate}::date)
      ORDER BY f.code,r.code
    `);
    const firms = new Map<string, UserAccessView['firms'][number]>();
    const firmEntry = (row: {
      firm_code: string;
      firm_id: string;
      firm_name: string;
    }): UserAccessView['firms'][number] => {
      let value = firms.get(row.firm_id);
      if (!value) {
        value = {
          applications: [],
          firm: { code: row.firm_code, id: row.firm_id, name: row.firm_name },
          roles: [],
        };
        firms.set(row.firm_id, value);
      }
      return value;
    };
    for (const row of access)
      firmEntry(row).applications.push({
        accessActive: true,
        applicationCode: row.application_code,
        validFrom: row.valid_from,
        validTo: row.valid_to,
      });
    for (const row of roles)
      firmEntry(row).roles.push({
        isActive: true,
        roleCode: row.role_code,
        roleName: row.role_name,
        validFrom: row.valid_from,
        validTo: row.valid_to,
      });
    return {
      applicationRoles: applicationRoles.map((row) => ({
        applicationCode: row.application_code,
        isActive: true,
        roleCode: row.role_code,
        validFrom: row.valid_from,
        validTo: row.valid_to,
      })),
      firms: [...firms.values()],
      userId,
    };
  }
}
