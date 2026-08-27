import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module.js';
import { IdentityModule } from '../identity/identity.module.js';
import {
  AuthorizationClock,
  AuthorizationController,
  SystemAuthorizationClock,
} from './authorization.controller.js';
import { AuthorizationRepository } from './authorization.repository.js';
import { AuthorizationService } from './authorization.service.js';

@Module({
  controllers: [AuthorizationController],
  exports: [AuthorizationService],
  imports: [AuthModule, IdentityModule],
  providers: [
    AuthorizationRepository,
    AuthorizationService,
    { provide: AuthorizationClock, useClass: SystemAuthorizationClock },
  ],
})
export class AuthorizationModule {}
