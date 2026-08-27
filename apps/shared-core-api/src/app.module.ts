import { Module } from '@nestjs/common';

import { AuthModule } from './auth/auth.module.js';
import { AuthorizationModule } from './authorization/authorization.module.js';
import { FirmAdminModule } from './firms/firm-admin.module.js';
import { HealthController } from './health.controller.js';

@Module({
  controllers: [HealthController],
  imports: [AuthModule, AuthorizationModule, FirmAdminModule],
})
export class AppModule {}
