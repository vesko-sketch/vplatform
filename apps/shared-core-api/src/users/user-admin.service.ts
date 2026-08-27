import {
  ForbiddenException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';

import type { AuthenticationClaims } from '../auth/auth.types.js';
import { AuthorizationService, businessDateAt } from '../authorization/authorization.service.js';
import { UserReadRepository } from './user-read.repository.js';
import type {
  CreateInvitationCommand,
  InvitationResult,
  InvitationView,
  UserAdminContext,
  UserAdminView,
  UserAccessView,
  VersionedReasonCommand,
} from './user.types.js';
import { UserWriterService } from './user-writer.service.js';

@Injectable()
export class UserAdminService {
  constructor(
    private readonly authorization: AuthorizationService,
    private readonly reads: UserReadRepository,
    private readonly writer: UserWriterService,
  ) {}
  private async allowed(userId: string, permission: string, at: Date): Promise<void> {
    try {
      const result = await this.authorization.canAtApplicationScope({
        applicationCode: 'OFFICE',
        evaluatedAt: at,
        permissionCode: permission,
        platformUserId: userId,
      });
      if (!result.basePermissionGranted)
        throw new ForbiddenException('User administration is denied');
    } catch (error) {
      if (error instanceof ForbiddenException) throw error;
      throw new ServiceUnavailableException('Authorization is unavailable');
    }
  }
  async list(actor: string, at: Date): Promise<UserAdminView[]> {
    await this.allowed(actor, 'users.catalog.view', at);
    return this.reads.list();
  }
  async find(actor: string, id: string, at: Date): Promise<UserAdminView> {
    await this.allowed(actor, 'users.catalog.view', at);
    const value = await this.reads.find(id);
    if (!value) throw new NotFoundException('User not found');
    return value;
  }
  async invitations(actor: string, id: string, at: Date): Promise<InvitationView[]> {
    await this.allowed(actor, 'users.invitations.view', at);
    return this.reads.invitations(id);
  }
  async access(actor: string, id: string, at: Date): Promise<UserAccessView> {
    await this.allowed(actor, 'users.catalog.view', at);
    const value = await this.reads.access(id, businessDateAt(at));
    if (!value) throw new NotFoundException('User not found');
    return value;
  }
  async create(
    command: CreateInvitationCommand,
    context: UserAdminContext,
  ): Promise<InvitationResult> {
    await this.allowed(context.actorUserId, 'users.invite', context.evaluatedAt);
    return this.writer.create(command, context);
  }
  async reissue(userId: string, context: UserAdminContext): Promise<InvitationResult> {
    await this.allowed(context.actorUserId, 'users.invite', context.evaluatedAt);
    return this.writer.reissue(userId, context);
  }
  async cancel(
    userId: string,
    invitationId: string,
    command: VersionedReasonCommand,
    context: UserAdminContext,
  ): Promise<InvitationView> {
    await this.allowed(context.actorUserId, 'users.invitations.cancel', context.evaluatedAt);
    return this.writer.cancel(userId, invitationId, command, context);
  }
  async lifecycle(
    userId: string,
    action: 'disable' | 'reactivate',
    command: VersionedReasonCommand,
    context: UserAdminContext,
  ): Promise<void> {
    await this.allowed(
      context.actorUserId,
      action === 'disable' ? 'users.platform.disable' : 'users.platform.reactivate',
      context.evaluatedAt,
    );
    return this.writer.lifecycle(userId, action, command, context);
  }
  redeem(
    token: string,
    claims: AuthenticationClaims,
    context: Omit<UserAdminContext, 'actorUserId'>,
  ): Promise<{ identityId: string; userId: string }> {
    return this.writer.redeem(token, claims, context);
  }
}
