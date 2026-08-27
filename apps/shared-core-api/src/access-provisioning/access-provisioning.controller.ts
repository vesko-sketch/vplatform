import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { randomUUID } from 'node:crypto';

import { AuthenticationGuard } from '../auth/authentication.guard.js';
import type { AuthenticatedRequest } from '../auth/auth.types.js';
import { IdentityResolutionService } from '../identity/identity-resolution.service.js';
import { AccessProvisioningService } from './access-provisioning.service.js';
import { relationshipResponse, type ProvisioningContext } from './access-provisioning.types.js';
import { endRelationship, validity } from './access-provisioning.validation.js';

function safeUuid(value: unknown): string {
  return typeof value === 'string' && /^[0-9a-f-]{36}$/i.test(value) ? value : randomUUID();
}

@ApiTags('access provisioning')
@ApiBearerAuth()
@UseGuards(AuthenticationGuard)
@Controller('firms')
export class AccessProvisioningController {
  constructor(
    private readonly provisioning: AccessProvisioningService,
    private readonly identities: IdentityResolutionService,
  ) {}

  private async context(request: AuthenticatedRequest): Promise<ProvisioningContext> {
    if (request.authentication === undefined) throw new Error('Authentication claims are missing');
    const identity = await this.identities.resolve(request.authentication);
    const requestId = safeUuid(request.headers['x-request-id']);
    return {
      actorUserId: identity.platformUserId,
      correlationId: safeUuid(request.headers['x-correlation-id'] ?? requestId),
      evaluatedAt: new Date(),
      requestId,
    };
  }

  @Get(':firmId/applications')
  async applications(
    @Req() request: AuthenticatedRequest,
    @Param('firmId', ParseUUIDPipe) firmId: string,
  ): Promise<Record<string, unknown>[]> {
    const context = await this.context(request);
    return (
      await this.provisioning.listApplications(context.actorUserId, firmId, context.evaluatedAt)
    ).map(relationshipResponse);
  }

  @Get(':firmId/applications/:applicationCode/users')
  async users(
    @Req() request: AuthenticatedRequest,
    @Param('firmId', ParseUUIDPipe) firmId: string,
    @Param('applicationCode') applicationCode: string,
  ): Promise<Record<string, unknown>[]> {
    const context = await this.context(request);
    return (
      await this.provisioning.listUsers(
        context.actorUserId,
        firmId,
        applicationCode,
        context.evaluatedAt,
      )
    ).map(relationshipResponse);
  }

  @Get(':firmId/users/:userId/roles')
  async roles(
    @Req() request: AuthenticatedRequest,
    @Param('firmId', ParseUUIDPipe) firmId: string,
    @Param('userId', ParseUUIDPipe) userId: string,
  ): Promise<Record<string, unknown>[]> {
    const context = await this.context(request);
    return (
      await this.provisioning.listRoles(context.actorUserId, firmId, userId, context.evaluatedAt)
    ).map(relationshipResponse);
  }

  @Post(':firmId/applications/:applicationCode/enable')
  async enable(
    @Req() request: AuthenticatedRequest,
    @Param('firmId', ParseUUIDPipe) firmId: string,
    @Param('applicationCode') applicationCode: string,
    @Body() value: unknown,
  ): Promise<Record<string, unknown>> {
    return relationshipResponse(
      await this.provisioning.enable(
        firmId,
        applicationCode,
        validity(value),
        await this.context(request),
      ),
    );
  }

  @Post(':firmId/applications/:applicationCode/disable')
  async disable(
    @Req() request: AuthenticatedRequest,
    @Param('firmId', ParseUUIDPipe) firmId: string,
    @Param('applicationCode') applicationCode: string,
    @Body() value: unknown,
  ): Promise<Record<string, unknown>> {
    return relationshipResponse(
      await this.provisioning.disable(
        firmId,
        applicationCode,
        endRelationship(value),
        await this.context(request),
      ),
    );
  }

  @Post(':firmId/applications/:applicationCode/users/:userId/grant')
  async grant(
    @Req() request: AuthenticatedRequest,
    @Param('firmId', ParseUUIDPipe) firmId: string,
    @Param('applicationCode') applicationCode: string,
    @Param('userId', ParseUUIDPipe) userId: string,
    @Body() value: unknown,
  ): Promise<Record<string, unknown>> {
    return relationshipResponse(
      await this.provisioning.grant(
        firmId,
        applicationCode,
        userId,
        validity(value),
        await this.context(request),
      ),
    );
  }

  @Post(':firmId/applications/:applicationCode/users/:userId/revoke')
  async revoke(
    @Req() request: AuthenticatedRequest,
    @Param('firmId', ParseUUIDPipe) firmId: string,
    @Param('applicationCode') applicationCode: string,
    @Param('userId', ParseUUIDPipe) userId: string,
    @Body() value: unknown,
  ): Promise<Record<string, unknown>> {
    return relationshipResponse(
      await this.provisioning.revoke(
        firmId,
        applicationCode,
        userId,
        endRelationship(value),
        await this.context(request),
      ),
    );
  }

  @Post(':firmId/users/:userId/roles/:roleCode/assign')
  async assign(
    @Req() request: AuthenticatedRequest,
    @Param('firmId', ParseUUIDPipe) firmId: string,
    @Param('userId', ParseUUIDPipe) userId: string,
    @Param('roleCode') roleCode: string,
    @Body() value: unknown,
  ): Promise<Record<string, unknown>> {
    return relationshipResponse(
      await this.provisioning.assign(
        firmId,
        userId,
        roleCode,
        validity(value),
        await this.context(request),
      ),
    );
  }

  @Post(':firmId/users/:userId/roles/:roleCode/remove')
  async remove(
    @Req() request: AuthenticatedRequest,
    @Param('firmId', ParseUUIDPipe) firmId: string,
    @Param('userId', ParseUUIDPipe) userId: string,
    @Param('roleCode') roleCode: string,
    @Body() value: unknown,
  ): Promise<Record<string, unknown>> {
    return relationshipResponse(
      await this.provisioning.remove(
        firmId,
        userId,
        roleCode,
        endRelationship(value),
        await this.context(request),
      ),
    );
  }
}
