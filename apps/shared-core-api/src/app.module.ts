import { Module } from '@nestjs/common';

import { AccessProvisioningModule } from './access-provisioning/access-provisioning.module.js';
import { AuthModule } from './auth/auth.module.js';
import { AuthorizationModule } from './authorization/authorization.module.js';
import { FirmAdminModule } from './firms/firm-admin.module.js';
import { FirmRoleCatalogModule } from './firm-roles/firm-role-catalog.module.js';
import { HealthController } from './health.controller.js';
import { ReferenceDataModule } from './reference-data/reference-data.module.js';
import { UserAdminModule } from './users/user-admin.module.js';

@Module({
  controllers: [HealthController],
  imports: [
    AccessProvisioningModule,
    AuthModule,
    AuthorizationModule,
    FirmAdminModule,
    FirmRoleCatalogModule,
    ReferenceDataModule,
    UserAdminModule,
  ],
})
export class AppModule {}
