import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module.js';
import { AuthorizationModule } from '../authorization/authorization.module.js';
import { IdentityModule } from '../identity/identity.module.js';
import { UserAdminController } from './user-admin.controller.js';
import { UserAdminService } from './user-admin.service.js';
import { UserReadRepository } from './user-read.repository.js';
import { UserWriterClient, UserWriterService } from './user-writer.service.js';
@Module({
  controllers: [UserAdminController],
  imports: [AuthModule, AuthorizationModule, IdentityModule],
  providers: [UserAdminService, UserReadRepository, UserWriterClient, UserWriterService],
})
export class UserAdminModule {}
