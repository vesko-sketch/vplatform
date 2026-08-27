import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { Prisma, PrismaClient } from '@prisma/client';
import { randomUUID } from 'node:crypto';

import { businessDateAt } from '../authorization/authorization.service.js';
import type {
  EndRelationshipCommand,
  FirmApplicationView,
  ProvisioningContext,
  UserApplicationAccessView,
  UserFirmRoleView,
  ValidityCommand,
} from './access-provisioning.types.js';

type Transaction = Prisma.TransactionClient;
interface BaseRow {
  id: string;
  is_active: boolean;
  row_version: bigint;
  valid_from: Date | null;
  valid_to: Date | null;
}
interface FirmApplicationRow extends BaseRow {
  application_code: string;
  application_id: string;
}
interface UserAccessRow extends FirmApplicationRow {
  user_id: string;
}
interface UserRoleRow extends BaseRow {
  role_code: string;
  role_id: string;
  user_id: string;
}

@Injectable()
export class AccessProvisioningWriterClient extends PrismaClient {
  readonly configured: boolean;
  constructor() {
    const url = process.env.SHARED_CORE_ACCESS_WRITER_DATABASE_URL;
    super({
      datasourceUrl: url ?? 'postgresql://unconfigured:unconfigured@127.0.0.1:1/unconfigured',
    });
    this.configured = url !== undefined && url !== '';
  }
}

function forbidden(): never {
  throw new ForbiddenException('Access provisioning is denied');
}
function conflict(code: string, message: string): never {
  throw new ConflictException({ code, message, statusCode: 409 });
}
function json(value: unknown): string {
  return JSON.stringify(value, (_, item: unknown) =>
    typeof item === 'bigint' ? item.toString() : item,
  );
}
function sameValidity(row: BaseRow, command: ValidityCommand): boolean {
  return (
    (row.valid_from?.toISOString().slice(0, 10) ?? null) === command.validFrom &&
    (row.valid_to?.toISOString().slice(0, 10) ?? null) === command.validTo
  );
}
function firmApplication(row: FirmApplicationRow): FirmApplicationView {
  return {
    applicationCode: row.application_code,
    applicationId: row.application_id,
    id: row.id,
    isActive: row.is_active,
    rowVersion: row.row_version,
    validFrom: row.valid_from,
    validTo: row.valid_to,
  };
}
function userAccess(row: UserAccessRow): UserApplicationAccessView {
  return {
    ...firmApplication(row),
    userId: row.user_id,
  };
}
function userRole(row: UserRoleRow): UserFirmRoleView {
  return {
    id: row.id,
    isActive: row.is_active,
    roleCode: row.role_code,
    roleId: row.role_id,
    rowVersion: row.row_version,
    userId: row.user_id,
    validFrom: row.valid_from,
    validTo: row.valid_to,
  };
}

@Injectable()
export class AccessProvisioningWriterService {
  constructor(private readonly client: AccessProvisioningWriterClient) {}

  private async transaction<T>(work: (tx: Transaction) => Promise<T>): Promise<T> {
    if (!this.client.configured)
      throw new ServiceUnavailableException('Access provisioning storage is unavailable');
    try {
      return await this.client.$transaction(work);
    } catch (error) {
      if (
        error instanceof BadRequestException ||
        error instanceof ConflictException ||
        error instanceof ForbiddenException ||
        error instanceof NotFoundException
      )
        throw error;
      throw new ServiceUnavailableException('Access provisioning storage is unavailable');
    }
  }

  private async lock(tx: Transaction, key: string): Promise<void> {
    await tx.$queryRaw(Prisma.sql`
      SELECT pg_advisory_xact_lock(hashtextextended(${key}, 0))::text AS lock_result
    `);
  }

  private async actorRoles(
    tx: Transaction,
    actorUserId: string,
    permissionCode: string,
    evaluatedAt: Date,
  ): Promise<string[]> {
    const date = businessDateAt(evaluatedAt);
    const rows = await tx.$queryRaw<Array<{ role_code: string }>>(Prisma.sql`
      SELECT DISTINCT r.code AS role_code
      FROM public.users u
      JOIN public.applications a ON a.code='OFFICE' AND a.is_active
      JOIN public.permissions p ON p.application_id=a.id AND p.code=${permissionCode}
        AND p.scope_type='APPLICATION' AND p.is_active
      JOIN public.role_permissions rp ON rp.permission_id=p.id AND rp.is_active
      JOIN public.roles r ON r.id=rp.role_id AND r.is_active
      JOIN public.user_application_roles uar
        ON uar.user_id=u.id AND uar.application_id=a.id AND uar.role_id=r.id AND uar.is_active
      WHERE u.id=${actorUserId}::uuid AND u.is_active
        AND (uar.valid_from IS NULL OR uar.valid_from <= ${date}::date)
        AND (uar.valid_to IS NULL OR uar.valid_to >= ${date}::date)
    `);
    if (rows.length === 0) forbidden();
    return rows.map((row) => row.role_code);
  }

  private async targets(
    tx: Transaction,
    firmId: string,
    applicationCode = 'OFFICE',
  ): Promise<{ id: string; is_active: boolean }> {
    if (applicationCode !== 'OFFICE') forbidden();
    const firms = await tx.$queryRaw<Array<{ is_active: boolean }>>(
      Prisma.sql`SELECT is_active FROM public.firms WHERE id=${firmId}::uuid`,
    );
    if (firms[0] === undefined) throw new NotFoundException('Firm not found');
    if (!firms[0].is_active) throw new BadRequestException('Firm is inactive');
    const applications = await tx.$queryRaw<Array<{ id: string; is_active: boolean }>>(
      Prisma.sql`SELECT id,is_active FROM public.applications WHERE code=${applicationCode}`,
    );
    if (applications[0] === undefined) throw new NotFoundException('Application not found');
    if (!applications[0].is_active) throw new BadRequestException('Application is inactive');
    return applications[0];
  }

  private async targetUser(tx: Transaction, userId: string): Promise<void> {
    const users = await tx.$queryRaw<Array<{ is_active: boolean }>>(
      Prisma.sql`SELECT is_active FROM public.users WHERE id=${userId}::uuid`,
    );
    if (users[0] === undefined) throw new NotFoundException('User not found');
    if (!users[0].is_active) throw new BadRequestException('User is inactive');
  }

  private async audit(
    tx: Transaction,
    context: ProvisioningContext,
    entityType: string,
    entityId: string,
    action: string,
    firmId: string,
    oldValues: unknown,
    newValues: unknown,
    reason?: string,
  ): Promise<void> {
    await tx.$executeRaw(Prisma.sql`
      INSERT INTO public.audit_log
        (firm_id,user_id,entity_type,entity_id,action,old_values,new_values,reason,source_type,request_id,correlation_id)
      VALUES
        (${firmId}::uuid,${context.actorUserId}::uuid,${entityType},${entityId}::uuid,${action},
         ${json(oldValues)}::jsonb,${json(newValues)}::jsonb,${reason ?? null},'shared-core-api',
         ${context.requestId}::uuid,${context.correlationId}::uuid)
    `);
  }

  private requireVersion(row: BaseRow, expected: bigint | undefined): void {
    if (expected === undefined || row.row_version !== expected)
      conflict('ROW_VERSION_CONFLICT', 'Relationship row version differs');
  }

  async enableFirmApplication(
    firmId: string,
    applicationCode: string,
    command: ValidityCommand,
    context: ProvisioningContext,
  ): Promise<FirmApplicationView> {
    return this.transaction(async (tx) => {
      await this.actorRoles(
        tx,
        context.actorUserId,
        'firms.applications.enable',
        context.evaluatedAt,
      );
      await this.lock(tx, `firm-application:${firmId}:${applicationCode}`);
      const application = await this.targets(tx, firmId, applicationCode);
      const rows = await tx.$queryRaw<FirmApplicationRow[]>(Prisma.sql`
        SELECT fa.id,fa.application_id,fa.valid_from,fa.valid_to,fa.is_active,
          fa.row_version,a.code AS application_code
        FROM public.firm_applications fa JOIN public.applications a ON a.id=fa.application_id
        WHERE fa.firm_id=${firmId}::uuid AND fa.application_id=${application.id}::uuid
      `);
      const current = rows[0];
      if (current !== undefined) {
        if (!sameValidity(current, command))
          conflict('RELATIONSHIP_STATE_CONFLICT', 'Relationship validity differs');
        if (current.is_active) return firmApplication(current);
        this.requireVersion(current, command.expectedRowVersion);
        const updated = await tx.$queryRaw<FirmApplicationRow[]>(Prisma.sql`
          UPDATE public.firm_applications SET is_active=true
          WHERE id=${current.id}::uuid AND row_version=${current.row_version}
          RETURNING id,application_id,valid_from,valid_to,is_active,row_version,
            ${applicationCode}::text AS application_code
        `);
        if (updated[0] === undefined)
          conflict('ROW_VERSION_CONFLICT', 'Relationship row version differs');
        await this.audit(
          tx,
          context,
          'firm_application',
          current.id,
          'firm_application.enabled',
          firmId,
          current,
          updated[0],
        );
        return firmApplication(updated[0]);
      }
      const id = randomUUID();
      const inserted = await tx.$queryRaw<FirmApplicationRow[]>(Prisma.sql`
        INSERT INTO public.firm_applications (id,firm_id,application_id,valid_from,valid_to)
        VALUES (${id}::uuid,${firmId}::uuid,${application.id}::uuid,${command.validFrom}::date,${command.validTo}::date)
        RETURNING id,application_id,valid_from,valid_to,is_active,row_version,
          ${applicationCode}::text AS application_code
      `);
      await this.audit(
        tx,
        context,
        'firm_application',
        id,
        'firm_application.enabled',
        firmId,
        null,
        inserted[0],
      );
      return firmApplication(inserted[0]!);
    });
  }

  async disableFirmApplication(
    firmId: string,
    applicationCode: string,
    command: EndRelationshipCommand,
    context: ProvisioningContext,
  ): Promise<FirmApplicationView> {
    return this.transaction(async (tx) => {
      await this.actorRoles(
        tx,
        context.actorUserId,
        'firms.applications.disable',
        context.evaluatedAt,
      );
      await this.lock(tx, `firm-application:${firmId}:${applicationCode}`);
      const application = await this.targets(tx, firmId, applicationCode);
      const rows = await tx.$queryRaw<FirmApplicationRow[]>(Prisma.sql`
        SELECT fa.id,fa.application_id,fa.valid_from,fa.valid_to,fa.is_active,
          fa.row_version,a.code AS application_code
        FROM public.firm_applications fa JOIN public.applications a ON a.id=fa.application_id
        WHERE fa.firm_id=${firmId}::uuid AND fa.application_id=${application.id}::uuid
      `);
      const current = rows[0];
      if (current === undefined) throw new NotFoundException('Firm application not found');
      if (!current.is_active) return firmApplication(current);
      this.requireVersion(current, command.expectedRowVersion);
      const date = businessDateAt(context.evaluatedAt);
      const dependencies = await tx.$queryRaw<Array<{ count: bigint }>>(Prisma.sql`
        SELECT count(*)::bigint AS count FROM public.user_firm_applications
        WHERE firm_id=${firmId}::uuid AND application_id=${application.id}::uuid AND is_active
          AND (valid_from IS NULL OR valid_from <= ${date}::date)
          AND (valid_to IS NULL OR valid_to >= ${date}::date)
      `);
      if ((dependencies[0]?.count ?? 0n) > 0n)
        conflict('DEPENDENT_ACTIVE_USER_ACCESS', 'Active user access must be revoked first');
      const updated = await tx.$queryRaw<FirmApplicationRow[]>(Prisma.sql`
        UPDATE public.firm_applications SET is_active=false
        WHERE id=${current.id}::uuid AND row_version=${current.row_version}
        RETURNING id,application_id,valid_from,valid_to,is_active,row_version,
          ${applicationCode}::text AS application_code
      `);
      if (updated[0] === undefined)
        conflict('ROW_VERSION_CONFLICT', 'Relationship row version differs');
      await this.audit(
        tx,
        context,
        'firm_application',
        current.id,
        'firm_application.disabled',
        firmId,
        current,
        updated[0],
        command.reason,
      );
      return firmApplication(updated[0]);
    });
  }

  async grantUserAccess(
    firmId: string,
    applicationCode: string,
    userId: string,
    command: ValidityCommand,
    context: ProvisioningContext,
  ): Promise<UserApplicationAccessView> {
    return this.transaction(async (tx) => {
      await this.actorRoles(tx, context.actorUserId, 'firms.access.grant', context.evaluatedAt);
      await this.lock(tx, `user-access:${firmId}:${applicationCode}:${userId}`);
      const application = await this.targets(tx, firmId, applicationCode);
      await this.targetUser(tx, userId);
      const date = businessDateAt(context.evaluatedAt);
      const enabled = await tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
        SELECT id FROM public.firm_applications WHERE firm_id=${firmId}::uuid
          AND application_id=${application.id}::uuid AND is_active
          AND (valid_from IS NULL OR valid_from <= ${date}::date)
          AND (valid_to IS NULL OR valid_to >= ${date}::date)
      `);
      if (enabled[0] === undefined)
        throw new BadRequestException('Firm application is not enabled');
      const rows = await tx.$queryRaw<UserAccessRow[]>(Prisma.sql`
        SELECT ufa.id,ufa.user_id,ufa.application_id,ufa.valid_from,ufa.valid_to,ufa.is_active,
          ufa.row_version,a.code AS application_code
        FROM public.user_firm_applications ufa JOIN public.applications a ON a.id=ufa.application_id
        WHERE ufa.user_id=${userId}::uuid AND ufa.firm_id=${firmId}::uuid
          AND ufa.application_id=${application.id}::uuid
      `);
      const current = rows[0];
      if (current !== undefined) {
        if (!sameValidity(current, command))
          conflict('RELATIONSHIP_STATE_CONFLICT', 'Relationship validity differs');
        if (current.is_active) return userAccess(current);
        this.requireVersion(current, command.expectedRowVersion);
        const updated = await tx.$queryRaw<UserAccessRow[]>(Prisma.sql`
          UPDATE public.user_firm_applications SET is_active=true
          WHERE id=${current.id}::uuid AND row_version=${current.row_version}
          RETURNING id,user_id,application_id,valid_from,valid_to,is_active,row_version,
            ${applicationCode}::text AS application_code
        `);
        if (updated[0] === undefined)
          conflict('ROW_VERSION_CONFLICT', 'Relationship row version differs');
        await this.audit(
          tx,
          context,
          'user_firm_application',
          current.id,
          'user_firm_application.granted',
          firmId,
          current,
          updated[0],
        );
        return userAccess(updated[0]);
      }
      const id = randomUUID();
      const inserted = await tx.$queryRaw<UserAccessRow[]>(Prisma.sql`
        INSERT INTO public.user_firm_applications (id,user_id,firm_id,application_id,valid_from,valid_to)
        VALUES (${id}::uuid,${userId}::uuid,${firmId}::uuid,${application.id}::uuid,${command.validFrom}::date,${command.validTo}::date)
        RETURNING id,user_id,application_id,valid_from,valid_to,is_active,row_version,
          ${applicationCode}::text AS application_code
      `);
      await this.audit(
        tx,
        context,
        'user_firm_application',
        id,
        'user_firm_application.granted',
        firmId,
        null,
        inserted[0],
      );
      return userAccess(inserted[0]!);
    });
  }

  async revokeUserAccess(
    firmId: string,
    applicationCode: string,
    userId: string,
    command: EndRelationshipCommand,
    context: ProvisioningContext,
  ): Promise<UserApplicationAccessView> {
    return this.transaction(async (tx) => {
      await this.actorRoles(tx, context.actorUserId, 'firms.access.revoke', context.evaluatedAt);
      await this.lock(tx, `user-access:${firmId}:${applicationCode}:${userId}`);
      const application = await this.targets(tx, firmId, applicationCode);
      await this.targetUser(tx, userId);
      const rows = await tx.$queryRaw<UserAccessRow[]>(Prisma.sql`
        SELECT ufa.id,ufa.user_id,ufa.application_id,ufa.valid_from,ufa.valid_to,ufa.is_active,
          ufa.row_version,a.code AS application_code
        FROM public.user_firm_applications ufa JOIN public.applications a ON a.id=ufa.application_id
        WHERE ufa.user_id=${userId}::uuid AND ufa.firm_id=${firmId}::uuid
          AND ufa.application_id=${application.id}::uuid
      `);
      const current = rows[0];
      if (current === undefined) throw new NotFoundException('User application access not found');
      if (!current.is_active) return userAccess(current);
      this.requireVersion(current, command.expectedRowVersion);
      const updated = await tx.$queryRaw<UserAccessRow[]>(Prisma.sql`
        UPDATE public.user_firm_applications SET is_active=false
        WHERE id=${current.id}::uuid AND row_version=${current.row_version}
        RETURNING id,user_id,application_id,valid_from,valid_to,is_active,row_version,
          ${applicationCode}::text AS application_code
      `);
      if (updated[0] === undefined)
        conflict('ROW_VERSION_CONFLICT', 'Relationship row version differs');
      await this.audit(
        tx,
        context,
        'user_firm_application',
        current.id,
        'user_firm_application.revoked',
        firmId,
        current,
        updated[0],
        command.reason,
      );
      return userAccess(updated[0]);
    });
  }

  async assignRole(
    firmId: string,
    userId: string,
    roleCode: string,
    command: ValidityCommand,
    context: ProvisioningContext,
  ): Promise<UserFirmRoleView> {
    return this.transaction(async (tx) => {
      const actorRoles = await this.actorRoles(
        tx,
        context.actorUserId,
        'firms.roles.assign',
        context.evaluatedAt,
      );
      await this.lock(tx, `user-role:${firmId}:${userId}:${roleCode}`);
      const application = await this.targets(tx, firmId);
      await this.targetUser(tx, userId);
      const roles = await tx.$queryRaw<Array<{ id: string; is_active: boolean }>>(
        Prisma.sql`SELECT id,is_active FROM public.roles WHERE code=${roleCode}`,
      );
      const role = roles[0];
      if (role === undefined) throw new NotFoundException('Role not found');
      if (!role.is_active) throw new BadRequestException('Role is inactive');
      if (roleCode === 'admin' && !actorRoles.includes('admin')) forbidden();
      const allowedRoleCodes = [
        'admin',
        'manager',
        'accountant',
        'payroll',
        'client_owner',
        'client_staff',
        'upload_only',
      ];
      if (!allowedRoleCodes.includes(roleCode)) forbidden();
      const date = businessDateAt(context.evaluatedAt);
      const access = await tx.$queryRaw<Array<{ allowed: boolean }>>(Prisma.sql`
        SELECT EXISTS (SELECT 1 FROM public.firm_applications fa
          JOIN public.user_firm_applications ufa
            ON ufa.firm_id=fa.firm_id AND ufa.application_id=fa.application_id AND ufa.is_active
          WHERE fa.firm_id=${firmId}::uuid AND fa.application_id=${application.id}::uuid AND fa.is_active
            AND ufa.user_id=${userId}::uuid
            AND (fa.valid_from IS NULL OR fa.valid_from <= ${date}::date)
            AND (fa.valid_to IS NULL OR fa.valid_to >= ${date}::date)
            AND (ufa.valid_from IS NULL OR ufa.valid_from <= ${date}::date)
            AND (ufa.valid_to IS NULL OR ufa.valid_to >= ${date}::date)) AS allowed
      `);
      if (access[0]?.allowed !== true)
        throw new BadRequestException('User has no current OFFICE access');
      const rows = await tx.$queryRaw<UserRoleRow[]>(Prisma.sql`
        SELECT ufr.id,ufr.user_id,ufr.role_id,ufr.valid_from,ufr.valid_to,ufr.is_active,
          ufr.row_version,${roleCode}::text AS role_code
        FROM public.user_firm_roles ufr WHERE user_id=${userId}::uuid AND firm_id=${firmId}::uuid
          AND role_id=${role.id}::uuid
      `);
      const current = rows[0];
      if (current !== undefined) {
        if (!sameValidity(current, command))
          conflict('RELATIONSHIP_STATE_CONFLICT', 'Relationship validity differs');
        if (current.is_active) return userRole(current);
        this.requireVersion(current, command.expectedRowVersion);
        const updated = await tx.$queryRaw<UserRoleRow[]>(Prisma.sql`
          UPDATE public.user_firm_roles SET is_active=true
          WHERE id=${current.id}::uuid AND row_version=${current.row_version}
          RETURNING id,user_id,role_id,valid_from,valid_to,is_active,row_version,
            ${roleCode}::text AS role_code
        `);
        if (updated[0] === undefined)
          conflict('ROW_VERSION_CONFLICT', 'Relationship row version differs');
        await this.audit(
          tx,
          context,
          'user_firm_role',
          current.id,
          'user_firm_role.assigned',
          firmId,
          current,
          updated[0],
        );
        return userRole(updated[0]);
      }
      const id = randomUUID();
      const inserted = await tx.$queryRaw<UserRoleRow[]>(Prisma.sql`
        INSERT INTO public.user_firm_roles (id,user_id,firm_id,role_id,valid_from,valid_to)
        VALUES (${id}::uuid,${userId}::uuid,${firmId}::uuid,${role.id}::uuid,${command.validFrom}::date,${command.validTo}::date)
        RETURNING id,user_id,role_id,valid_from,valid_to,is_active,row_version,
          ${roleCode}::text AS role_code
      `);
      await this.audit(
        tx,
        context,
        'user_firm_role',
        id,
        'user_firm_role.assigned',
        firmId,
        null,
        inserted[0],
      );
      return userRole(inserted[0]!);
    });
  }

  async removeRole(
    firmId: string,
    userId: string,
    roleCode: string,
    command: EndRelationshipCommand,
    context: ProvisioningContext,
  ): Promise<UserFirmRoleView> {
    return this.transaction(async (tx) => {
      const actorRoles = await this.actorRoles(
        tx,
        context.actorUserId,
        'firms.roles.remove',
        context.evaluatedAt,
      );
      await this.lock(tx, `user-role:${firmId}:${userId}:${roleCode}`);
      await this.targets(tx, firmId);
      await this.targetUser(tx, userId);
      const roles = await tx.$queryRaw<Array<{ id: string; is_active: boolean }>>(
        Prisma.sql`SELECT id,is_active FROM public.roles WHERE code=${roleCode}`,
      );
      const role = roles[0];
      if (role === undefined) throw new NotFoundException('Role not found');
      if (roleCode === 'admin' && !actorRoles.includes('admin')) forbidden();
      const rows = await tx.$queryRaw<UserRoleRow[]>(Prisma.sql`
        SELECT ufr.id,ufr.user_id,ufr.role_id,ufr.valid_from,ufr.valid_to,ufr.is_active,
          ufr.row_version,${roleCode}::text AS role_code
        FROM public.user_firm_roles ufr WHERE user_id=${userId}::uuid AND firm_id=${firmId}::uuid
          AND role_id=${role.id}::uuid
      `);
      const current = rows[0];
      if (current === undefined) throw new NotFoundException('Firm role assignment not found');
      if (!current.is_active) return userRole(current);
      this.requireVersion(current, command.expectedRowVersion);
      const updated = await tx.$queryRaw<UserRoleRow[]>(Prisma.sql`
        UPDATE public.user_firm_roles SET is_active=false
        WHERE id=${current.id}::uuid AND row_version=${current.row_version}
        RETURNING id,user_id,role_id,valid_from,valid_to,is_active,row_version,
          ${roleCode}::text AS role_code
      `);
      if (updated[0] === undefined)
        conflict('ROW_VERSION_CONFLICT', 'Relationship row version differs');
      await this.audit(
        tx,
        context,
        'user_firm_role',
        current.id,
        'user_firm_role.removed',
        firmId,
        current,
        updated[0],
        command.reason,
      );
      return userRole(updated[0]);
    });
  }
}
