import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module.js';
import { AuthorizationModule } from '../authorization/authorization.module.js';
import { IdentityModule } from '../identity/identity.module.js';
import { FirmAdminController } from './firm-admin.controller.js';
import { FirmAdminService } from './firm-admin.service.js';
import { FirmReadRepository } from './firm-read.repository.js';
import { FirmWriterClient, FirmWriterService } from './firm-writer.service.js';

@Module({
  controllers: [FirmAdminController],
  imports: [AuthModule, AuthorizationModule, IdentityModule],
  providers: [FirmAdminService, FirmReadRepository, FirmWriterClient, FirmWriterService],
})
export class FirmAdminModule {}
