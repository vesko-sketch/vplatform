import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { randomUUID } from 'node:crypto';

import { AuthenticationGuard } from '../auth/authentication.guard.js';
import type { AuthenticatedRequest } from '../auth/auth.types.js';
import { IdentityResolutionService } from '../identity/identity-resolution.service.js';
import { UserAdminService } from './user-admin.service.js';
import { publicInvitation, publicUser, type UserAdminContext } from './user.types.js';
import { createInvitation, redemptionToken, versionedReason } from './user.validation.js';

function uuid(value: unknown): string {
  return typeof value === 'string' && /^[0-9a-f-]{36}$/i.test(value) ? value : randomUUID();
}
@ApiTags('user administration')
@ApiBearerAuth()
@UseGuards(AuthenticationGuard)
@Controller()
export class UserAdminController {
  constructor(
    private readonly users: UserAdminService,
    private readonly identities: IdentityResolutionService,
  ) {}
  private base(request: AuthenticatedRequest): Omit<UserAdminContext, 'actorUserId'> {
    const requestId = uuid(request.headers['x-request-id']);
    return {
      correlationId: uuid(request.headers['x-correlation-id'] ?? requestId),
      evaluatedAt: new Date(),
      requestId,
    };
  }
  private async context(request: AuthenticatedRequest): Promise<UserAdminContext> {
    if (!request.authentication) throw new Error('Authentication claims missing');
    const identity = await this.identities.resolve(request.authentication);
    return { ...this.base(request), actorUserId: identity.platformUserId };
  }
  @Get('users') async list(
    @Req() request: AuthenticatedRequest,
  ): Promise<Record<string, unknown>[]> {
    const context = await this.context(request);
    return (await this.users.list(context.actorUserId, context.evaluatedAt)).map(publicUser);
  }
  @Get('users/:userId') async find(
    @Req() request: AuthenticatedRequest,
    @Param('userId', ParseUUIDPipe) userId: string,
  ): Promise<Record<string, unknown>> {
    const context = await this.context(request);
    return publicUser(await this.users.find(context.actorUserId, userId, context.evaluatedAt));
  }
  @Get('users/:userId/invitations') async invitations(
    @Req() request: AuthenticatedRequest,
    @Param('userId', ParseUUIDPipe) userId: string,
  ): Promise<Record<string, unknown>[]> {
    const context = await this.context(request);
    return (await this.users.invitations(context.actorUserId, userId, context.evaluatedAt)).map(
      publicInvitation,
    );
  }
  @Post('users/invitations') async create(
    @Req() request: AuthenticatedRequest,
    @Body() body: unknown,
  ): Promise<Record<string, unknown>> {
    const result = await this.users.create(createInvitation(body), await this.context(request));
    return {
      invitation: publicInvitation(result.invitation),
      ...(result.invitationUrl ? { invitationUrl: result.invitationUrl } : {}),
      user: publicUser(result.user),
    };
  }
  @Post('users/:userId/invitations/reissue') async reissue(
    @Req() request: AuthenticatedRequest,
    @Param('userId', ParseUUIDPipe) userId: string,
  ): Promise<Record<string, unknown>> {
    const result = await this.users.reissue(userId, await this.context(request));
    return {
      invitation: publicInvitation(result.invitation),
      ...(result.invitationUrl ? { invitationUrl: result.invitationUrl } : {}),
      user: publicUser(result.user),
    };
  }
  @Post('users/:userId/invitations/:invitationId/cancel') async cancel(
    @Req() request: AuthenticatedRequest,
    @Param('userId', ParseUUIDPipe) userId: string,
    @Param('invitationId', ParseUUIDPipe) invitationId: string,
    @Body() body: unknown,
  ): Promise<Record<string, unknown>> {
    return publicInvitation(
      await this.users.cancel(
        userId,
        invitationId,
        versionedReason(body),
        await this.context(request),
      ),
    );
  }
  @Post('users/:userId/disable') async disable(
    @Req() request: AuthenticatedRequest,
    @Param('userId', ParseUUIDPipe) userId: string,
    @Body() body: unknown,
  ): Promise<{ status: 'DISABLED' }> {
    await this.users.lifecycle(
      userId,
      'disable',
      versionedReason(body),
      await this.context(request),
    );
    return { status: 'DISABLED' };
  }
  @Post('users/:userId/reactivate') async reactivate(
    @Req() request: AuthenticatedRequest,
    @Param('userId', ParseUUIDPipe) userId: string,
    @Body() body: unknown,
  ): Promise<{ status: 'ACTIVE' }> {
    await this.users.lifecycle(
      userId,
      'reactivate',
      versionedReason(body),
      await this.context(request),
    );
    return { status: 'ACTIVE' };
  }
  @Post('invitations/redeem') async redeem(
    @Req() request: AuthenticatedRequest,
    @Body() body: unknown,
  ): Promise<{ identityId: string; userId: string }> {
    if (!request.authentication) throw new Error('Authentication claims missing');
    return this.users.redeem(redemptionToken(body), request.authentication, this.base(request));
  }
}
