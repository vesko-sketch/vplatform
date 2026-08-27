import { ForbiddenException, Injectable, ServiceUnavailableException } from '@nestjs/common';

import { AuthorizationService } from '../authorization/authorization.service.js';
import { AccessProvisioningReadRepository } from './access-provisioning-read.repository.js';
import type {
  EndRelationshipCommand,
  FirmApplicationView,
  ProvisioningContext,
  UserApplicationAccessView,
  UserFirmRoleView,
  ValidityCommand,
} from './access-provisioning.types.js';
import { AccessProvisioningWriterService } from './access-provisioning-writer.service.js';

@Injectable()
export class AccessProvisioningService {
  constructor(
    private readonly authorization: AuthorizationService,
    private readonly reads: AccessProvisioningReadRepository,
    private readonly writer: AccessProvisioningWriterService,
  ) {}

  private async allow(userId: string, permissionCode: string, evaluatedAt: Date): Promise<void> {
    try {
      const result = await this.authorization.canAtApplicationScope({
        applicationCode: 'OFFICE',
        evaluatedAt,
        permissionCode,
        platformUserId: userId,
      });
      if (!result.basePermissionGranted)
        throw new ForbiddenException('Access provisioning is denied');
    } catch (error) {
      if (error instanceof ForbiddenException) throw error;
      throw new ServiceUnavailableException('Authorization is unavailable');
    }
  }

  async listApplications(
    userId: string,
    firmId: string,
    evaluatedAt: Date,
  ): Promise<FirmApplicationView[]> {
    await this.allow(userId, 'firms.applications.view', evaluatedAt);
    return this.reads.listFirmApplications(firmId);
  }
  async listUsers(
    userId: string,
    firmId: string,
    applicationCode: string,
    evaluatedAt: Date,
  ): Promise<UserApplicationAccessView[]> {
    await this.allow(userId, 'firms.access.view', evaluatedAt);
    return this.reads.listUserAccess(firmId, applicationCode);
  }
  async listRoles(
    userId: string,
    firmId: string,
    targetUserId: string,
    evaluatedAt: Date,
  ): Promise<UserFirmRoleView[]> {
    await this.allow(userId, 'firms.roles.view', evaluatedAt);
    return this.reads.listUserRoles(firmId, targetUserId);
  }
  async enable(
    firmId: string,
    applicationCode: string,
    command: ValidityCommand,
    context: ProvisioningContext,
  ): Promise<FirmApplicationView> {
    await this.allow(context.actorUserId, 'firms.applications.enable', context.evaluatedAt);
    return this.writer.enableFirmApplication(firmId, applicationCode, command, context);
  }
  async disable(
    firmId: string,
    applicationCode: string,
    command: EndRelationshipCommand,
    context: ProvisioningContext,
  ): Promise<FirmApplicationView> {
    await this.allow(context.actorUserId, 'firms.applications.disable', context.evaluatedAt);
    return this.writer.disableFirmApplication(firmId, applicationCode, command, context);
  }
  async grant(
    firmId: string,
    applicationCode: string,
    targetUserId: string,
    command: ValidityCommand,
    context: ProvisioningContext,
  ): Promise<UserApplicationAccessView> {
    await this.allow(context.actorUserId, 'firms.access.grant', context.evaluatedAt);
    return this.writer.grantUserAccess(firmId, applicationCode, targetUserId, command, context);
  }
  async revoke(
    firmId: string,
    applicationCode: string,
    targetUserId: string,
    command: EndRelationshipCommand,
    context: ProvisioningContext,
  ): Promise<UserApplicationAccessView> {
    await this.allow(context.actorUserId, 'firms.access.revoke', context.evaluatedAt);
    return this.writer.revokeUserAccess(firmId, applicationCode, targetUserId, command, context);
  }
  async assign(
    firmId: string,
    targetUserId: string,
    roleCode: string,
    command: ValidityCommand,
    context: ProvisioningContext,
  ): Promise<UserFirmRoleView> {
    await this.allow(context.actorUserId, 'firms.roles.assign', context.evaluatedAt);
    return this.writer.assignRole(firmId, targetUserId, roleCode, command, context);
  }
  async remove(
    firmId: string,
    targetUserId: string,
    roleCode: string,
    command: EndRelationshipCommand,
    context: ProvisioningContext,
  ): Promise<UserFirmRoleView> {
    await this.allow(context.actorUserId, 'firms.roles.remove', context.evaluatedAt);
    return this.writer.removeRole(firmId, targetUserId, roleCode, command, context);
  }
}
