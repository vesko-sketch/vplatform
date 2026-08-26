import { Module } from '@nestjs/common';

import { IdentityResolutionService } from './identity-resolution.service.js';
import { PrismaExternalIdentityRepository } from './prisma-external-identity.repository.js';
import { PrismaService } from './prisma.service.js';

@Module({
  exports: [IdentityResolutionService],
  providers: [PrismaService, PrismaExternalIdentityRepository, IdentityResolutionService],
})
export class IdentityModule {}
