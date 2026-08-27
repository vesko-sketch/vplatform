import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module.js';
import { IdentityModule } from '../identity/identity.module.js';
import { ReferenceDataController } from './reference-data.controller.js';
import { ReferenceDataRepository } from './reference-data.repository.js';

@Module({
  controllers: [ReferenceDataController],
  imports: [AuthModule, IdentityModule],
  providers: [ReferenceDataRepository],
})
export class ReferenceDataModule {}
