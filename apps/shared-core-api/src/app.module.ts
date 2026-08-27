import { Module } from '@nestjs/common';

import { AccessProvisioningModule } from './access-provisioning/access-provisioning.module.js';
import { AuthModule } from './auth/auth.module.js';
import { AuthorizationModule } from './authorization/authorization.module.js';
import { FirmAdminModule } from './firms/firm-admin.module.js';
import { HealthController } from './health.controller.js';

@Module({
  controllers: [HealthController],
  imports: [AccessProvisioningModule, AuthModule, AuthorizationModule, FirmAdminModule],
})
export class AppModule {}
