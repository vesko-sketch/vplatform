import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { Prisma, PrismaClient } from '@prisma/client';
import { createHash, randomBytes, randomUUID } from 'node:crypto';

import { businessDateAt } from '../authorization/authorization.service.js';
import type { AuthenticationClaims } from '../auth/auth.types.js';
import type {
  CreateInvitationCommand,
  InvitationResult,
  InvitationView,
  UserAdminContext,
  UserAdminView,
  VersionedReasonCommand,
} from './user.types.js';
import { normalizeEmail } from './user.validation.js';

type Tx = Prisma.TransactionClient;
interface UserRow {
  created_at: Date;
  display_name: string | null;
  email: string;
  id: string;
  is_active: boolean;
  lifecycle_status: string;
  row_version: bigint;
  updated_at: Date;
}
interface InvitationRow {
  application_id: string;
  cancelled_at: Date | null;
  cancellation_reason: string | null;
  consumed_at: Date | null;
  created_at: Date;
  expires_at: Date;
  id: string;
  invited_email: string;
  normalized_email: string;
  row_version: bigint;
  status: string;
  token_digest: Uint8Array;
  updated_at: Date;
  user_id: string;
}

@Injectable()
export class UserWriterClient extends PrismaClient {
  readonly configured: boolean;
  constructor() {
    const url = process.env.SHARED_CORE_USER_WRITER_DATABASE_URL;
    super({
      datasourceUrl: url ?? 'postgresql://unconfigured:unconfigured@127.0.0.1:1/unconfigured',
    });
    this.configured = Boolean(url);
  }
}
function conflict(code: string, message: string): never {
  throw new ConflictException({ code, message, statusCode: 409 });
}
function digest(token: string): Buffer {
  return createHash('sha256').update(token, 'utf8').digest();
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
function user(
  row: UserRow,
  identityLinked = false,
  state: string | null = null,
  expires: Date | null = null,
): UserAdminView {
  return {
    createdAt: row.created_at,
    currentInvitationExpiresAt: expires,
    currentInvitationState: state,
    displayName: row.display_name,
    email: row.email,
    id: row.id,
    identityLinked,
    isActive: row.is_active,
    lifecycleStatus: row.lifecycle_status,
    rowVersion: row.row_version,
    updatedAt: row.updated_at,
  };
}
function safeJson(value: unknown): string {
  const encoded = JSON.stringify(value, (_key: string, item: unknown) =>
    typeof item === 'bigint' ? item.toString() : item,
  );
  return encoded ?? 'null';
}

@Injectable()
export class UserWriterService {
  constructor(private readonly client: UserWriterClient) {}
  private async run<T>(work: (tx: Tx) => Promise<T>): Promise<T> {
    if (!this.client.configured)
      throw new ServiceUnavailableException('User administration storage is unavailable');
    try {
      return await this.client.$transaction(work, {
        isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
      });
    } catch (error) {
      if (
        error instanceof BadRequestException ||
        error instanceof ConflictException ||
        error instanceof ForbiddenException ||
        error instanceof NotFoundException
      )
        throw error;
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002')
        conflict('USER_EMAIL_REVIEW_REQUIRED', 'User email requires administrative review');
      throw new ServiceUnavailableException('User administration storage is unavailable');
    }
  }
  private async authorize(tx: Tx, actor: string, permission: string, at: Date): Promise<void> {
    const date = businessDateAt(at);
    const rows = await tx.$queryRaw<Array<{ ok: number }>>(
      Prisma.sql`SELECT 1 AS ok FROM public.users u JOIN public.applications a ON a.code='OFFICE' AND a.is_active JOIN public.permissions p ON p.application_id=a.id AND p.code=${permission} AND p.scope_type='APPLICATION' AND p.is_active JOIN public.role_permissions rp ON rp.permission_id=p.id AND rp.is_active JOIN public.roles r ON r.id=rp.role_id AND r.is_active JOIN public.user_application_roles uar ON uar.user_id=u.id AND uar.application_id=a.id AND uar.role_id=r.id AND uar.is_active WHERE u.id=${actor}::uuid AND u.is_active AND u.lifecycle_status='ACTIVE' AND (uar.valid_from IS NULL OR uar.valid_from<=${date}::date) AND (uar.valid_to IS NULL OR uar.valid_to>=${date}::date) LIMIT 1`,
    );
    if (!rows[0]) throw new ForbiddenException('User administration is denied');
  }
  private async application(tx: Tx): Promise<string> {
    const rows = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`SELECT id FROM public.applications WHERE code='OFFICE' AND is_active`,
    );
    if (!rows[0]) throw new ServiceUnavailableException('OFFICE application is unavailable');
    return rows[0].id;
  }
  private async audit(
    tx: Tx,
    context: UserAdminContext,
    entityType: string,
    entityId: string,
    action: string,
    oldValue: unknown,
    newValue: unknown,
    reason?: string,
  ): Promise<void> {
    await tx.$executeRaw(
      Prisma.sql`INSERT INTO public.audit_log(user_id,entity_type,entity_id,action,old_values,new_values,reason,source_type,request_id,correlation_id) VALUES(${context.actorUserId}::uuid,${entityType},${entityId}::uuid,${action},${safeJson(oldValue)}::jsonb,${safeJson(newValue)}::jsonb,${reason ?? null},'shared-core-api',${context.requestId}::uuid,${context.correlationId}::uuid)`,
    );
  }
  private url(token: string): string | undefined {
    if (
      process.env.NODE_ENV === 'production' ||
      process.env.INVITATION_DEVELOPMENT_RESPONSE_ENABLED !== 'true'
    )
      return undefined;
    const base =
      process.env.INVITATION_REDEMPTION_BASE_URL ?? 'http://localhost:3000/invitations/redeem';
    return `${base}?token=${encodeURIComponent(token)}`;
  }
  async create(
    command: CreateInvitationCommand,
    context: UserAdminContext,
  ): Promise<InvitationResult> {
    const raw = randomBytes(32).toString('base64url');
    const result = await this.run(async (tx) => {
      await this.authorize(tx, context.actorUserId, 'users.invite', context.evaluatedAt);
      await tx.$queryRaw(
        Prisma.sql`SELECT pg_advisory_xact_lock(hashtextextended(${`user-email:${command.email}`},0))::text`,
      );
      const existing = await tx.$queryRaw<Array<{ id: string }>>(
        Prisma.sql`SELECT id,lifecycle_status FROM public.users WHERE email=${command.email}`,
      );
      if (existing[0])
        conflict('USER_EMAIL_REVIEW_REQUIRED', 'User email requires administrative review');
      const applicationId = await this.application(tx);
      const userId = randomUUID(),
        invitationId = randomUUID();
      const insertedUsers = await tx.$queryRaw<
        Array<{
          email: string;
          id: string;
          is_active: boolean;
          lifecycle_status: string;
          row_version: bigint;
        }>
      >(
        Prisma.sql`INSERT INTO public.users(id,email,display_name,is_active,lifecycle_status) VALUES(${userId}::uuid,${command.email},${command.displayName},false,'INVITED') RETURNING id,email,is_active,lifecycle_status,row_version`,
      );
      const users: UserRow[] = [
        {
          ...insertedUsers[0]!,
          created_at: context.evaluatedAt,
          display_name: command.displayName,
          updated_at: context.evaluatedAt,
        },
      ];
      const invitations = await tx.$queryRaw<InvitationRow[]>(
        Prisma.sql`INSERT INTO public.user_invitations(id,user_id,application_id,invited_email,normalized_email,token_digest,expires_at,created_by,request_id,correlation_id) VALUES(${invitationId}::uuid,${userId}::uuid,${applicationId}::uuid,${command.email},${command.email},${digest(raw)},${new Date(context.evaluatedAt.getTime() + 48 * 60 * 60 * 1000)},${context.actorUserId}::uuid,${context.requestId}::uuid,${context.correlationId}::uuid) RETURNING *`,
      );
      await this.audit(tx, context, 'user', userId, 'user.created_pending', null, {
        email: command.email,
        lifecycleStatus: 'INVITED',
      });
      await this.audit(
        tx,
        context,
        'user_invitation',
        invitationId,
        'user.invitation.created',
        null,
        { userId, status: 'PENDING', expiresAt: invitations[0]!.expires_at },
      );
      return {
        invitation: invitation(invitations[0]!),
        user: user(users[0]!, false, 'PENDING', invitations[0]!.expires_at),
      };
    });
    return { ...result, ...(this.url(raw) ? { invitationUrl: this.url(raw) } : {}) };
  }
  async reissue(userId: string, context: UserAdminContext): Promise<InvitationResult> {
    const raw = randomBytes(32).toString('base64url');
    const result = await this.run(async (tx) => {
      await this.authorize(tx, context.actorUserId, 'users.invite', context.evaluatedAt);
      await tx.$queryRaw(
        Prisma.sql`SELECT pg_advisory_xact_lock(hashtextextended(${`user-invitation:${userId}`},0))::text`,
      );
      const users = await tx.$queryRaw<UserRow[]>(
        Prisma.sql`SELECT id,email,NULL::varchar AS display_name,is_active,lifecycle_status,row_version,now() AS created_at,now() AS updated_at FROM public.users WHERE id=${userId}::uuid`,
      );
      const target = users[0];
      if (!target) throw new NotFoundException('User not found');
      if (target.lifecycle_status !== 'INVITED')
        conflict('RELATIONSHIP_STATE_CONFLICT', 'Only invited users may be reissued');
      const pending = await tx.$queryRaw<InvitationRow[]>(
        Prisma.sql`SELECT * FROM public.user_invitations WHERE user_id=${userId}::uuid AND status='PENDING' FOR UPDATE`,
      );
      if (pending[0]) {
        await tx.$executeRaw(
          Prisma.sql`UPDATE public.user_invitations SET status='CANCELLED',cancelled_at=now(),cancelled_by=${context.actorUserId}::uuid,cancellation_reason='Replaced by a new invitation' WHERE id=${pending[0].id}::uuid AND row_version=${pending[0].row_version}`,
        );
        await this.audit(
          tx,
          context,
          'user_invitation',
          pending[0].id,
          'user.invitation.cancelled',
          { status: 'PENDING' },
          { status: 'CANCELLED' },
          'Replaced by a new invitation',
        );
      }
      const applicationId = await this.application(tx),
        id = randomUUID();
      const rows = await tx.$queryRaw<InvitationRow[]>(
        Prisma.sql`INSERT INTO public.user_invitations(id,user_id,application_id,invited_email,normalized_email,token_digest,expires_at,created_by,request_id,correlation_id) VALUES(${id}::uuid,${userId}::uuid,${applicationId}::uuid,${target.email},${target.email},${digest(raw)},${new Date(context.evaluatedAt.getTime() + 48 * 60 * 60 * 1000)},${context.actorUserId}::uuid,${context.requestId}::uuid,${context.correlationId}::uuid) RETURNING *`,
      );
      await this.audit(tx, context, 'user_invitation', id, 'user.invitation.created', null, {
        userId,
        status: 'PENDING',
        expiresAt: rows[0]!.expires_at,
      });
      return {
        invitation: invitation(rows[0]!),
        user: user(target, false, 'PENDING', rows[0]!.expires_at),
      };
    });
    return { ...result, ...(this.url(raw) ? { invitationUrl: this.url(raw) } : {}) };
  }
  async cancel(
    userId: string,
    invitationId: string,
    command: VersionedReasonCommand,
    context: UserAdminContext,
  ): Promise<InvitationView> {
    return this.run(async (tx) => {
      await this.authorize(
        tx,
        context.actorUserId,
        'users.invitations.cancel',
        context.evaluatedAt,
      );
      const rows = await tx.$queryRaw<InvitationRow[]>(
        Prisma.sql`SELECT * FROM public.user_invitations WHERE id=${invitationId}::uuid AND user_id=${userId}::uuid FOR UPDATE`,
      );
      const row = rows[0];
      if (!row) throw new NotFoundException('Invitation not found');
      if (row.status !== 'PENDING')
        conflict('INVITATION_STATE_CONFLICT', 'Only pending invitations may be cancelled');
      if (row.row_version !== command.expectedRowVersion)
        conflict('ROW_VERSION_CONFLICT', 'Invitation row version differs');
      const updated = await tx.$queryRaw<InvitationRow[]>(
        Prisma.sql`UPDATE public.user_invitations SET status='CANCELLED',cancelled_at=now(),cancelled_by=${context.actorUserId}::uuid,cancellation_reason=${command.reason} WHERE id=${row.id}::uuid AND row_version=${row.row_version} RETURNING *`,
      );
      if (!updated[0]) conflict('ROW_VERSION_CONFLICT', 'Invitation row version differs');
      await this.audit(
        tx,
        context,
        'user_invitation',
        row.id,
        'user.invitation.cancelled',
        { status: row.status },
        { status: 'CANCELLED' },
        command.reason,
      );
      return invitation(updated[0]);
    });
  }
  async lifecycle(
    userId: string,
    action: 'disable' | 'reactivate',
    command: VersionedReasonCommand,
    context: UserAdminContext,
  ): Promise<void> {
    await this.run(async (tx) => {
      await this.authorize(
        tx,
        context.actorUserId,
        action === 'disable' ? 'users.platform.disable' : 'users.platform.reactivate',
        context.evaluatedAt,
      );
      const rows = await tx.$queryRaw<UserRow[]>(
        Prisma.sql`SELECT id,email,NULL::varchar AS display_name,is_active,lifecycle_status,row_version,now() AS created_at,now() AS updated_at FROM public.users WHERE id=${userId}::uuid FOR UPDATE`,
      );
      const row = rows[0];
      if (!row) throw new NotFoundException('User not found');
      if (row.row_version !== command.expectedRowVersion)
        conflict('ROW_VERSION_CONFLICT', 'User row version differs');
      if (action === 'disable') {
        if (row.lifecycle_status === 'INVITED') {
          const pending = await tx.$queryRaw<Array<{ id: string }>>(
            Prisma.sql`SELECT id FROM public.user_invitations WHERE user_id=${userId}::uuid AND status='PENDING'`,
          );
          if (pending[0])
            conflict(
              'PENDING_INVITATION_EXISTS',
              'Cancel the invitation before disabling the user',
            );
        }
        if (row.lifecycle_status === 'DISABLED') return;
        await tx.$executeRaw(
          Prisma.sql`UPDATE public.users SET lifecycle_status='DISABLED',is_active=false WHERE id=${userId}::uuid AND row_version=${row.row_version}`,
        );
        await this.audit(
          tx,
          context,
          'user',
          userId,
          'user.disabled',
          { lifecycleStatus: row.lifecycle_status },
          { lifecycleStatus: 'DISABLED' },
          command.reason,
        );
      } else {
        if (row.lifecycle_status !== 'DISABLED')
          conflict('USER_STATE_CONFLICT', 'Only disabled users may be reactivated');
        const identities = await tx.$queryRaw<Array<{ id: string }>>(
          Prisma.sql`SELECT id FROM public.user_external_identities WHERE user_id=${userId}::uuid AND status='active' LIMIT 1`,
        );
        if (!identities[0])
          conflict('ACTIVE_IDENTITY_REQUIRED', 'Recovery or relinking is required');
        await tx.$executeRaw(
          Prisma.sql`UPDATE public.users SET lifecycle_status='ACTIVE',is_active=true WHERE id=${userId}::uuid AND row_version=${row.row_version}`,
        );
        await this.audit(
          tx,
          context,
          'user',
          userId,
          'user.reactivated',
          { lifecycleStatus: 'DISABLED' },
          { lifecycleStatus: 'ACTIVE' },
          command.reason,
        );
      }
    });
  }
  async redeem(
    raw: string,
    claims: AuthenticationClaims,
    context: Omit<UserAdminContext, 'actorUserId'>,
  ): Promise<{ identityId: string; userId: string }> {
    if (claims.emailVerified !== true || !claims.email)
      throw new ForbiddenException('INVITATION_INVALID');
    const normalized = normalizeEmail(claims.email);
    return this.run(async (tx) => {
      const rows = await tx.$queryRaw<InvitationRow[]>(
        Prisma.sql`SELECT * FROM public.user_invitations WHERE token_digest=${digest(raw)} FOR UPDATE`,
      );
      const row = rows[0];
      if (!row || row.status !== 'PENDING' || row.expires_at <= context.evaluatedAt)
        throw new ForbiddenException('INVITATION_INVALID');
      if (row.normalized_email !== normalized)
        throw new ForbiddenException('INVITATION_IDENTITY_MISMATCH');
      const users = await tx.$queryRaw<UserRow[]>(
        Prisma.sql`SELECT id,email,NULL::varchar AS display_name,is_active,lifecycle_status,row_version,now() AS created_at,now() AS updated_at FROM public.users WHERE id=${row.user_id}::uuid FOR UPDATE`,
      );
      const target = users[0];
      if (!target || target.lifecycle_status !== 'INVITED' || target.is_active)
        throw new ForbiddenException('INVITATION_INVALID');
      const existing = await tx.$queryRaw<Array<{ id: string; user_id: string }>>(
        Prisma.sql`SELECT id,user_id FROM public.user_external_identities WHERE issuer=${claims.issuer} AND subject=${claims.subject}`,
      );
      if (existing[0])
        conflict('EXTERNAL_IDENTITY_CONFLICT', 'External identity is already linked');
      const sameIssuer = await tx.$queryRaw<Array<{ id: string }>>(
        Prisma.sql`SELECT id FROM public.user_external_identities WHERE user_id=${target.id}::uuid AND issuer=${claims.issuer} AND status='active'`,
      );
      if (sameIssuer[0])
        conflict('EXTERNAL_IDENTITY_CONFLICT', 'External identity is already linked');
      const identityId = randomUUID();
      await tx.$executeRaw(
        Prisma.sql`INSERT INTO public.user_external_identities(id,user_id,issuer,subject,status,link_provenance,linked_at,status_changed_at) VALUES(${identityId}::uuid,${target.id}::uuid,${claims.issuer},${claims.subject},'active','invitation',now(),now())`,
      );
      await tx.$executeRaw(
        Prisma.sql`UPDATE public.user_invitations SET status='CONSUMED',consumed_at=now(),consumed_identity_id=${identityId}::uuid WHERE id=${row.id}::uuid AND row_version=${row.row_version}`,
      );
      await tx.$executeRaw(
        Prisma.sql`UPDATE public.users SET lifecycle_status='ACTIVE',is_active=true WHERE id=${target.id}::uuid AND row_version=${target.row_version}`,
      );
      const auditContext: {
        actorUserId: string;
        requestId: string;
        correlationId: string;
        evaluatedAt: Date;
      } = { ...context, actorUserId: target.id };
      await this.audit(
        tx,
        auditContext,
        'user_invitation',
        row.id,
        'user.invitation.consumed',
        { status: 'PENDING' },
        { status: 'CONSUMED' },
      );
      await this.audit(
        tx,
        auditContext,
        'user_external_identity',
        identityId,
        'user.identity.linked',
        null,
        { userId: target.id, provenance: 'invitation' },
      );
      await this.audit(
        tx,
        auditContext,
        'user',
        target.id,
        'user.activated',
        { lifecycleStatus: 'INVITED' },
        { lifecycleStatus: 'ACTIVE' },
      );
      return { identityId, userId: target.id };
    });
  }
}
