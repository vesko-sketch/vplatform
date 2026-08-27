import { Injectable } from '@nestjs/common';

import { PrismaService } from '../identity/prisma.service.js';

export interface FirmRoleCatalogItem {
  code: string;
  id: string;
  name: string;
}

@Injectable()
export class FirmRoleCatalogRepository {
  constructor(private readonly prisma: PrismaService) {}

  async listActive(): Promise<FirmRoleCatalogItem[]> {
    return this.prisma.roles.findMany({
      orderBy: [{ code: 'asc' }, { id: 'asc' }],
      select: { code: true, id: true, name: true },
      where: { is_active: true },
    });
  }
}
