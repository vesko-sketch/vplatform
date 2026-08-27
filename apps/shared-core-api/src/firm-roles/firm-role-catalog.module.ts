import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module.js';
import { AuthorizationModule } from '../authorization/authorization.module.js';
import { IdentityModule } from '../identity/identity.module.js';
import { FirmRoleCatalogController } from './firm-role-catalog.controller.js';
import { FirmRoleCatalogRepository } from './firm-role-catalog.repository.js';
import { FirmRoleCatalogService } from './firm-role-catalog.service.js';

@Module({
  controllers: [FirmRoleCatalogController],
  imports: [AuthModule, AuthorizationModule, IdentityModule],
  providers: [FirmRoleCatalogRepository, FirmRoleCatalogService],
})
export class FirmRoleCatalogModule {}
