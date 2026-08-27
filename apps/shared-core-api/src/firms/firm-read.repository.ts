import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../identity/prisma.service.js';
import type { FirmMaster } from './firm.types.js';

export const firmProjection = Prisma.sql`
  id, code, name, short_name, legal_form_id, country_id,
  registration_number, base_currency_id, default_language_id,
  timezone, is_active, row_version, created_at, updated_at
`;

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

export function firmMaster(row: FirmRow): FirmMaster {
  return {
    baseCurrencyId: row.base_currency_id,
    code: row.code,
    countryId: row.country_id,
    createdAt: row.created_at,
    defaultLanguageId: row.default_language_id,
    id: row.id,
    isActive: row.is_active,
    legalFormId: row.legal_form_id,
    name: row.name,
    registrationNumber: row.registration_number,
    rowVersion: row.row_version,
    shortName: row.short_name,
    timezone: row.timezone,
    updatedAt: row.updated_at,
  };
}

@Injectable()
export class FirmReadRepository {
  constructor(private readonly prisma: PrismaService) {}

  async list(): Promise<FirmMaster[]> {
    const rows = await this.prisma.$queryRaw<FirmRow[]>(
      Prisma.sql`SELECT ${firmProjection} FROM public.firms ORDER BY code, id`,
    );
    return rows.map(firmMaster);
  }

  async find(id: string): Promise<FirmMaster | null> {
    const rows = await this.prisma.$queryRaw<FirmRow[]>(
      Prisma.sql`SELECT ${firmProjection} FROM public.firms WHERE id=${id}::uuid`,
    );
    return rows[0] === undefined ? null : firmMaster(rows[0]);
  }
}
