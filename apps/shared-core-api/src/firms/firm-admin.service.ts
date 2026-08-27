import {
  ForbiddenException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';

import { AuthorizationService } from '../authorization/authorization.service.js';
import { FirmReadRepository } from './firm-read.repository.js';
import type {
  AuditContext,
  CreateFirmCommand,
  FirmLifecycleCommand,
  FirmMaster,
  UpdateFirmIdentityCommand,
  UpdateFirmProfileCommand,
  UpdateFirmSettingsCommand,
} from './firm.types.js';
import { FirmWriterService } from './firm-writer.service.js';

@Injectable()
export class FirmAdminService {
  constructor(
    private readonly authorization: AuthorizationService,
    private readonly reads: FirmReadRepository,
    private readonly writer: FirmWriterService,
  ) {}

  private async application(
    userId: string,
    permissionCode: string,
    evaluatedAt: Date,
  ): Promise<void> {
    try {
      const result = await this.authorization.canAtApplicationScope({
        applicationCode: 'OFFICE',
        evaluatedAt,
        permissionCode,
        platformUserId: userId,
      });
      if (!result.basePermissionGranted)
        throw new ForbiddenException('Firm administration is denied');
    } catch (error) {
      if (error instanceof ForbiddenException) throw error;
      throw new ServiceUnavailableException('Authorization is unavailable');
    }
  }

  private async firm(
    userId: string,
    firmId: string,
    permissionCode: string,
    evaluatedAt: Date,
  ): Promise<void> {
    try {
      const result = await this.authorization.can({
        applicationCode: 'OFFICE',
        evaluatedAt,
        firmId,
        permissionCode,
        platformUserId: userId,
      });
      if (!result.basePermissionGranted)
        throw new ForbiddenException('Firm administration is denied');
    } catch (error) {
      if (error instanceof ForbiddenException) throw error;
      throw new ServiceUnavailableException('Authorization is unavailable');
    }
  }

  async list(userId: string, evaluatedAt: Date): Promise<FirmMaster[]> {
    await this.application(userId, 'firms.catalog.view', evaluatedAt);
    try {
      return await this.reads.list();
    } catch {
      throw new ServiceUnavailableException('Firm catalog is unavailable');
    }
  }
  async find(userId: string, firmId: string, evaluatedAt: Date): Promise<FirmMaster> {
    await this.application(userId, 'firms.catalog.view', evaluatedAt);
    try {
      const firm = await this.reads.find(firmId);
      if (firm === null) throw new NotFoundException('Firm not found');
      return firm;
    } catch (error) {
      if (error instanceof NotFoundException) throw error;
      throw new ServiceUnavailableException('Firm catalog is unavailable');
    }
  }
  async create(
    command: CreateFirmCommand,
    context: AuditContext,
    evaluatedAt: Date,
  ): Promise<FirmMaster> {
    await this.application(context.actorUserId, 'firms.create', evaluatedAt);
    return this.writer.create(command, context, evaluatedAt);
  }
  async updateProfile(
    firmId: string,
    command: UpdateFirmProfileCommand,
    context: AuditContext,
    evaluatedAt: Date,
  ): Promise<FirmMaster> {
    await this.firm(context.actorUserId, firmId, 'firms.edit', evaluatedAt);
    return this.writer.updateProfile(firmId, command, context, evaluatedAt);
  }
  async updateIdentity(
    firmId: string,
    command: UpdateFirmIdentityCommand,
    context: AuditContext,
    evaluatedAt: Date,
  ): Promise<FirmMaster> {
    await this.firm(context.actorUserId, firmId, 'firms.identity.edit', evaluatedAt);
    return this.writer.updateIdentity(firmId, command, context, evaluatedAt);
  }
  async updateSettings(
    firmId: string,
    command: UpdateFirmSettingsCommand,
    context: AuditContext,
    evaluatedAt: Date,
  ): Promise<FirmMaster> {
    await this.firm(context.actorUserId, firmId, 'firms.settings.edit', evaluatedAt);
    return this.writer.updateSettings(firmId, command, context, evaluatedAt);
  }
  async deactivate(
    firmId: string,
    command: FirmLifecycleCommand,
    context: AuditContext,
    evaluatedAt: Date,
  ): Promise<FirmMaster> {
    await this.firm(context.actorUserId, firmId, 'firms.disable', evaluatedAt);
    return this.writer.deactivate(firmId, command, context, evaluatedAt);
  }
  async activate(
    firmId: string,
    command: FirmLifecycleCommand,
    context: AuditContext,
    evaluatedAt: Date,
  ): Promise<FirmMaster> {
    await this.application(context.actorUserId, 'firms.activate', evaluatedAt);
    return this.writer.activate(firmId, command, context, evaluatedAt);
  }
}
