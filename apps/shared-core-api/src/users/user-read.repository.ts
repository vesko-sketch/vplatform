import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../identity/prisma.service.js';
import type { InvitationView, UserAdminView } from './user.types.js';

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
}
