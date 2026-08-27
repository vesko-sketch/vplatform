import { Module } from '@nestjs/common';

import { OfficeAuthModule } from '../auth/auth.module.js';
import {
  HttpSharedCoreAuthorizationClient,
  SharedCoreAuthorizationClient,
} from '../shared-core/shared-core.client.js';
import { OfficeController } from './office.controller.js';
import { OfficePermissionGuard } from './office-permission.guard.js';

@Module({
  controllers: [OfficeController],
  imports: [OfficeAuthModule],
  providers: [
    { provide: SharedCoreAuthorizationClient, useClass: HttpSharedCoreAuthorizationClient },
    OfficePermissionGuard,
  ],
})
export class OfficeModule {}
