import { Module } from '@nestjs/common';

import { HealthController } from './health.controller.js';
import { OfficeModule } from './office/office.module.js';

@Module({ controllers: [HealthController], imports: [OfficeModule] })
export class AppModule {}
