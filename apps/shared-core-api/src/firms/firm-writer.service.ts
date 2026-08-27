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
import { firmMaster, firmProjection } from './firm-read.repository.js';
import type {
  AuditContext,
  CreateFirmCommand,
  FirmLifecycleCommand,
  FirmMaster,
  UpdateFirmIdentityCommand,
  UpdateFirmProfileCommand,
  UpdateFirmSettingsCommand,
} from './firm.types.js';

type Transaction = Prisma.TransactionClient;
interface FirmRow {
  base_currency_id: string;
  code: string;
  country_id: string;
  created_at: Date;
  default_language_id: string | null;
  id: string;
  is_active: boolean;
  legal_form_id: string | null;
  name: string;
  registration_number: string | null;
  row_version: bigint;
  short_name: string | null;
  timezone: string;
  updated_at: Date;
}

@Injectable()
export class FirmWriterClient extends PrismaClient {
  readonly configured: boolean;

  constructor() {
    const url = process.env.SHARED_CORE_FIRM_WRITER_DATABASE_URL;
    super({
      datasourceUrl: url ?? 'postgresql://unconfigured:unconfigured@127.0.0.1:1/unconfigured',
    });
    this.configured = url !== undefined && url !== '';
  }
}

function denied(): never {
  throw new ForbiddenException('Firm administration is denied');
}

function json(value: unknown): string {
  return JSON.stringify(value, (_, item: unknown) =>
    typeof item === 'bigint' ? item.toString() : item,
  );
}

@Injectable()
export class FirmWriterService {
  constructor(private readonly client: FirmWriterClient) {}

  private async transaction<T>(work: (tx: Transaction) => Promise<T>): Promise<T> {
    if (!this.client.configured)
      throw new ServiceUnavailableException('Firm command storage is unavailable');
    try {
      return await this.client.$transaction(work);
    } catch (error) {
      if (
        error instanceof BadRequestException ||
        error instanceof ConflictException ||
        error instanceof ForbiddenException ||
        error instanceof NotFoundException ||
        error instanceof ServiceUnavailableException
      )
        throw error;
      const code =
        typeof error === 'object' &&
        error !== null &&
        'meta' in error &&
        typeof error.meta === 'object' &&
        error.meta !== null &&
        'code' in error.meta
          ? String(error.meta.code)
          : '';
      if (code === '23505')
        throw new ConflictException({
          code: 'FIRM_CODE_CONFLICT',
          message: 'Firm code already exists',
          statusCode: 409,
        });
      if (code === '23503') throw new BadRequestException('A referenced catalog value is invalid');
      throw new ServiceUnavailableException('Firm command storage is unavailable');
    }
  }

  private async requireApplicationPermission(
    tx: Transaction,
    userId: string,
    permissionCode: string,
    evaluatedAt: Date,
  ): Promise<void> {
    const date = businessDateAt(evaluatedAt);
    const rows = await tx.$queryRaw<Array<{ allowed: boolean }>>(Prisma.sql`
      SELECT EXISTS (
        SELECT 1
        FROM public.users u
        JOIN public.applications a ON a.code='OFFICE' AND a.is_active
        JOIN public.permissions p ON p.application_id=a.id AND p.code=${permissionCode} AND p.scope_type='APPLICATION' AND p.is_active
        JOIN public.role_permissions rp ON rp.permission_id=p.id AND rp.is_active
        JOIN public.roles r ON r.id=rp.role_id AND r.is_active
        JOIN public.user_application_roles uar ON uar.user_id=u.id AND uar.application_id=a.id AND uar.role_id=r.id
        WHERE u.id=${userId}::uuid AND u.is_active AND uar.is_active
          AND (uar.valid_from IS NULL OR uar.valid_from <= ${date}::date)
          AND (uar.valid_to IS NULL OR uar.valid_to >= ${date}::date)
      ) AS allowed
    `);
    if (rows[0]?.allowed !== true) denied();
  }

  private async requireFirmPermission(
    tx: Transaction,
    userId: string,
    firmId: string,
    permissionCode: string,
    evaluatedAt: Date,
  ): Promise<void> {
    const date = businessDateAt(evaluatedAt);
    const gates = await tx.$queryRaw<
      Array<{ allowed: boolean; permission_id: string | null }>
    >(Prisma.sql`
      SELECT
        EXISTS (
          SELECT 1 FROM public.users u
          JOIN public.applications a ON a.code='OFFICE' AND a.is_active
          JOIN public.firms f ON f.id=${firmId}::uuid AND f.is_active
          JOIN public.firm_applications fa ON fa.firm_id=f.id AND fa.application_id=a.id AND fa.is_active
          JOIN public.user_firm_applications ufa ON ufa.user_id=u.id AND ufa.firm_id=f.id AND ufa.application_id=a.id AND ufa.is_active
          WHERE u.id=${userId}::uuid AND u.is_active
            AND (fa.valid_from IS NULL OR fa.valid_from <= ${date}::date)
            AND (fa.valid_to IS NULL OR fa.valid_to >= ${date}::date)
            AND (ufa.valid_from IS NULL OR ufa.valid_from <= ${date}::date)
            AND (ufa.valid_to IS NULL OR ufa.valid_to >= ${date}::date)
        ) AS allowed,
        (SELECT p.id FROM public.permissions p JOIN public.applications a ON a.id=p.application_id
          WHERE a.code='OFFICE' AND p.code=${permissionCode} AND p.scope_type='FIRM' AND p.is_active) AS permission_id
    `);
    const gate = gates[0];
    if (gate?.allowed !== true || gate.permission_id === null) denied();

    const base = await tx.$queryRaw<Array<{ allowed: boolean }>>(Prisma.sql`
      SELECT EXISTS (
        SELECT 1 FROM public.user_firm_roles ufr
        JOIN public.roles r ON r.id=ufr.role_id AND r.is_active
        JOIN public.role_permissions rp ON rp.role_id=r.id AND rp.permission_id=${gate.permission_id}::uuid AND rp.is_active
        WHERE ufr.user_id=${userId}::uuid AND ufr.firm_id=${firmId}::uuid AND ufr.is_active
          AND (ufr.valid_from IS NULL OR ufr.valid_from <= ${date}::date)
          AND (ufr.valid_to IS NULL OR ufr.valid_to >= ${date}::date)
      ) AS allowed
    `);
    const overrides = await tx.$queryRaw<
      Array<{ effect: string; firm_id: string | null }>
    >(Prisma.sql`
      SELECT effect,firm_id FROM public.user_permission_overrides
      WHERE user_id=${userId}::uuid AND permission_id=${gate.permission_id}::uuid
        AND (firm_id IS NULL OR firm_id=${firmId}::uuid)
        AND (valid_from IS NULL OR valid_from <= ${date}::date)
        AND (valid_to IS NULL OR valid_to >= ${date}::date)
    `);
    let allowed = base[0]?.allowed === true;
    for (const firmSpecific of [false, true]) {
      const level = overrides.filter((item) => (item.firm_id !== null) === firmSpecific);
      const allows = level.filter((item) => item.effect.toLowerCase() === 'allow').length;
      const denies = level.filter((item) => item.effect.toLowerCase() === 'deny').length;
      if (
        allows > 1 ||
        denies > 1 ||
        (allows > 0 && denies > 0) ||
        allows + denies !== level.length
      )
        denied();
      if (denies === 1) allowed = false;
      else if (allows === 1) allowed = true;
    }
    if (!allowed) denied();
  }

  private async requireReference(
    tx: Transaction,
    table: 'ref_countries' | 'ref_currencies' | 'ref_languages' | 'ref_legal_forms',
    id: string | null | undefined,
  ): Promise<void> {
    if (id === null || id === undefined) return;
    const tableName = Prisma.raw(`public.${table}`);
    const rows = await tx.$queryRaw<Array<{ found: boolean }>>(
      Prisma.sql`SELECT EXISTS (SELECT 1 FROM ${tableName} WHERE id=${id}::uuid AND is_active) AS found`,
    );
    if (rows[0]?.found !== true)
      throw new BadRequestException('A referenced catalog value is invalid');
  }

  private async audit(
    tx: Transaction,
    context: AuditContext,
    firmId: string,
    action: string,
    oldValues: unknown,
    newValues: unknown,
    reason?: string,
  ): Promise<void> {
    await tx.$executeRaw(Prisma.sql`
      INSERT INTO public.audit_log (firm_id,user_id,entity_type,entity_id,action,old_values,new_values,reason,source_type,request_id,correlation_id)
      VALUES (${firmId}::uuid,${context.actorUserId}::uuid,'firm',${firmId}::uuid,${action},${json(oldValues)}::jsonb,${json(newValues)}::jsonb,${reason ?? null},'shared-core-api',${context.requestId}::uuid,${context.correlationId}::uuid)
    `);
  }

  private async currentFirm(tx: Transaction, firmId: string): Promise<FirmMaster | null> {
    const rows = await tx.$queryRaw<FirmRow[]>(
      Prisma.sql`SELECT ${firmProjection} FROM public.firms WHERE id=${firmId}::uuid`,
    );
    return rows[0] === undefined ? null : firmMaster(rows[0]);
  }

  private async conflictOrMissing(tx: Transaction, firmId: string): Promise<never> {
    if ((await this.currentFirm(tx, firmId)) === null)
      throw new NotFoundException('Firm not found');
    throw new ConflictException({
      code: 'ROW_VERSION_CONFLICT',
      message: 'Firm row version differs',
      statusCode: 409,
    });
  }

  async create(
    command: CreateFirmCommand,
    context: AuditContext,
    evaluatedAt: Date,
  ): Promise<FirmMaster> {
    return this.transaction(async (tx) => {
      await this.requireApplicationPermission(tx, context.actorUserId, 'firms.create', evaluatedAt);
      await Promise.all([
        this.requireReference(tx, 'ref_countries', command.countryId),
        this.requireReference(tx, 'ref_currencies', command.baseCurrencyId),
        this.requireReference(tx, 'ref_languages', command.defaultLanguageId),
        this.requireReference(tx, 'ref_legal_forms', command.legalFormId),
      ]);
      const id = randomUUID();
      const rows = await tx.$queryRaw<FirmRow[]>(
        Prisma.sql`INSERT INTO public.firms (id,code,name,short_name,legal_form_id,country_id,registration_number,base_currency_id,default_language_id,timezone) VALUES (${id}::uuid,${command.code},${command.name},${command.shortName ?? null},${command.legalFormId ?? null}::uuid,${command.countryId}::uuid,${command.registrationNumber ?? null},${command.baseCurrencyId}::uuid,${command.defaultLanguageId ?? null}::uuid,${command.timezone ?? 'Europe/Sofia'}) RETURNING ${firmProjection}`,
      );
      const firm = firmMaster(rows[0]!);
      await this.audit(tx, context, firm.id, 'firm.created', null, firm);
      return firm;
    });
  }

  async updateProfile(
    firmId: string,
    command: UpdateFirmProfileCommand,
    context: AuditContext,
    evaluatedAt: Date,
  ): Promise<FirmMaster> {
    return this.transaction(async (tx) => {
      await this.requireFirmPermission(tx, context.actorUserId, firmId, 'firms.edit', evaluatedAt);
      await this.requireReference(tx, 'ref_languages', command.defaultLanguageId);
      const old = await this.currentFirm(tx, firmId);
      if (old === null) throw new NotFoundException('Firm not found');
      const rows = await tx.$queryRaw<FirmRow[]>(
        Prisma.sql`UPDATE public.firms SET name=CASE WHEN ${command.name !== undefined} THEN ${command.name ?? null} ELSE name END,short_name=CASE WHEN ${command.shortName !== undefined} THEN ${command.shortName ?? null} ELSE short_name END,default_language_id=CASE WHEN ${command.defaultLanguageId !== undefined} THEN ${command.defaultLanguageId ?? null}::uuid ELSE default_language_id END,timezone=CASE WHEN ${command.timezone !== undefined} THEN ${command.timezone ?? null} ELSE timezone END WHERE id=${firmId}::uuid AND row_version=${command.expectedRowVersion} RETURNING ${firmProjection}`,
      );
      if (rows[0] === undefined) return this.conflictOrMissing(tx, firmId);
      const firm = firmMaster(rows[0]);
      await this.audit(tx, context, firmId, 'firm.profile_updated', old, firm);
      return firm;
    });
  }

  async updateIdentity(
    firmId: string,
    command: UpdateFirmIdentityCommand,
    context: AuditContext,
    evaluatedAt: Date,
  ): Promise<FirmMaster> {
    return this.transaction(async (tx) => {
      await this.requireFirmPermission(
        tx,
        context.actorUserId,
        firmId,
        'firms.identity.edit',
        evaluatedAt,
      );
      await Promise.all([
        this.requireReference(tx, 'ref_countries', command.countryId),
        this.requireReference(tx, 'ref_legal_forms', command.legalFormId),
      ]);
      const old = await this.currentFirm(tx, firmId);
      if (old === null) throw new NotFoundException('Firm not found');
      const rows = await tx.$queryRaw<FirmRow[]>(
        Prisma.sql`UPDATE public.firms SET code=CASE WHEN ${command.code !== undefined} THEN ${command.code ?? null} ELSE code END,legal_form_id=CASE WHEN ${command.legalFormId !== undefined} THEN ${command.legalFormId ?? null}::uuid ELSE legal_form_id END,country_id=CASE WHEN ${command.countryId !== undefined} THEN ${command.countryId ?? null}::uuid ELSE country_id END,registration_number=CASE WHEN ${command.registrationNumber !== undefined} THEN ${command.registrationNumber ?? null} ELSE registration_number END WHERE id=${firmId}::uuid AND row_version=${command.expectedRowVersion} RETURNING ${firmProjection}`,
      );
      if (rows[0] === undefined) return this.conflictOrMissing(tx, firmId);
      const firm = firmMaster(rows[0]);
      await this.audit(tx, context, firmId, 'firm.identity_updated', old, firm);
      return firm;
    });
  }

  async updateSettings(
    firmId: string,
    command: UpdateFirmSettingsCommand,
    context: AuditContext,
    evaluatedAt: Date,
  ): Promise<FirmMaster> {
    return this.transaction(async (tx) => {
      await this.requireFirmPermission(
        tx,
        context.actorUserId,
        firmId,
        'firms.settings.edit',
        evaluatedAt,
      );
      await this.requireReference(tx, 'ref_currencies', command.baseCurrencyId);
      const old = await this.currentFirm(tx, firmId);
      if (old === null) throw new NotFoundException('Firm not found');
      const rows = await tx.$queryRaw<FirmRow[]>(
        Prisma.sql`UPDATE public.firms SET base_currency_id=${command.baseCurrencyId}::uuid WHERE id=${firmId}::uuid AND row_version=${command.expectedRowVersion} RETURNING ${firmProjection}`,
      );
      if (rows[0] === undefined) return this.conflictOrMissing(tx, firmId);
      const firm = firmMaster(rows[0]);
      await this.audit(tx, context, firmId, 'firm.settings_updated', old, firm);
      return firm;
    });
  }

  async deactivate(
    firmId: string,
    command: FirmLifecycleCommand,
    context: AuditContext,
    evaluatedAt: Date,
  ): Promise<FirmMaster> {
    return this.transaction(async (tx) => {
      await this.requireFirmPermission(
        tx,
        context.actorUserId,
        firmId,
        'firms.disable',
        evaluatedAt,
      );
      const old = await this.currentFirm(tx, firmId);
      if (old === null) throw new NotFoundException('Firm not found');
      const rows = await tx.$queryRaw<FirmRow[]>(
        Prisma.sql`UPDATE public.firms SET is_active=false WHERE id=${firmId}::uuid AND row_version=${command.expectedRowVersion} AND is_active RETURNING ${firmProjection}`,
      );
      if (rows[0] === undefined) return this.conflictOrMissing(tx, firmId);
      const firm = firmMaster(rows[0]);
      await this.audit(tx, context, firmId, 'firm.deactivated', old, firm, command.reason);
      return firm;
    });
  }

  async activate(
    firmId: string,
    command: FirmLifecycleCommand,
    context: AuditContext,
    evaluatedAt: Date,
  ): Promise<FirmMaster> {
    return this.transaction(async (tx) => {
      await this.requireApplicationPermission(
        tx,
        context.actorUserId,
        'firms.activate',
        evaluatedAt,
      );
      const old = await this.currentFirm(tx, firmId);
      if (old === null) throw new NotFoundException('Firm not found');
      if (old.isActive) throw new BadRequestException('Firm is already active');
      const rows = await tx.$queryRaw<FirmRow[]>(
        Prisma.sql`UPDATE public.firms SET is_active=true WHERE id=${firmId}::uuid AND row_version=${command.expectedRowVersion} AND NOT is_active RETURNING ${firmProjection}`,
      );
      if (rows[0] === undefined) return this.conflictOrMissing(tx, firmId);
      const firm = firmMaster(rows[0]);
      await this.audit(tx, context, firmId, 'firm.activated', old, firm, command.reason);
      return firm;
    });
  }
}
