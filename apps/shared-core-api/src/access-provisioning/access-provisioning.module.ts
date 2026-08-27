import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module.js';
import { AuthorizationModule } from '../authorization/authorization.module.js';
import { IdentityModule } from '../identity/identity.module.js';
import { AccessProvisioningReadRepository } from './access-provisioning-read.repository.js';
import { AccessProvisioningController } from './access-provisioning.controller.js';
import { AccessProvisioningService } from './access-provisioning.service.js';
import {
  AccessProvisioningWriterClient,
  AccessProvisioningWriterService,
} from './access-provisioning-writer.service.js';

@Module({
  controllers: [AccessProvisioningController],
  imports: [AuthModule, AuthorizationModule, IdentityModule],
  providers: [
    AccessProvisioningReadRepository,
    AccessProvisioningService,
    AccessProvisioningWriterClient,
    AccessProvisioningWriterService,
  ],
})
export class AccessProvisioningModule {}
