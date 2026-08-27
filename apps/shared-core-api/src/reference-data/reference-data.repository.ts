import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../identity/prisma.service.js';

@Injectable()
export class ReferenceDataRepository {
  constructor(private readonly prisma: PrismaService) {}

  countries(): Promise<Array<Record<string, unknown>>> {
    return this.prisma.$queryRaw(Prisma.sql`
      SELECT id,iso2_code "iso2Code",iso3_code "iso3Code",name_bg "nameBg",name_en "nameEn"
      FROM public.ref_countries WHERE is_active ORDER BY iso2_code,id
    `);
  }
  currencies(): Promise<Array<Record<string, unknown>>> {
    return this.prisma.$queryRaw(Prisma.sql`
      SELECT id,iso_code "code",name,decimal_places "decimalPlaces",is_crypto "isCrypto"
      FROM public.ref_currencies WHERE is_active ORDER BY iso_code,id
    `);
  }
  languages(): Promise<Array<Record<string, unknown>>> {
    return this.prisma.$queryRaw(Prisma.sql`
      SELECT id,iso_code "code",name_bg "nameBg",name_en "nameEn"
      FROM public.ref_languages WHERE is_active ORDER BY iso_code,id
    `);
  }
  legalForms(): Promise<Array<Record<string, unknown>>> {
    return this.prisma.$queryRaw(Prisma.sql`
      SELECT id,code,short_name "shortName",full_name "fullName"
      FROM public.ref_legal_forms WHERE is_active ORDER BY code,id
    `);
  }
}
