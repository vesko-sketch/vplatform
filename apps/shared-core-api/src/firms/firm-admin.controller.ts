import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { randomUUID } from 'node:crypto';

import { AuthenticationGuard } from '../auth/authentication.guard.js';
import type { AuthenticatedRequest } from '../auth/auth.types.js';
import { IdentityResolutionService } from '../identity/identity-resolution.service.js';
import { FirmAdminService } from './firm-admin.service.js';
import { firmResponse, type AuditContext, type FirmResponse } from './firm.types.js';
import {
  createFirm,
  lifecycle,
  updateIdentity,
  updateProfile,
  updateSettings,
} from './firm.validation.js';

function header(request: AuthenticatedRequest, name: string): string | undefined {
  const value = request.headers[name];
  return typeof value === 'string' ? value : undefined;
}
function safeUuid(value: string | undefined): string {
  return value !== undefined &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)
    ? value
    : randomUUID();
}

@ApiTags('firm administration')
@ApiBearerAuth()
@UseGuards(AuthenticationGuard)
@Controller('firms')
export class FirmAdminController {
  constructor(
    private readonly firms: FirmAdminService,
    private readonly identities: IdentityResolutionService,
  ) {}

  private async context(
    request: AuthenticatedRequest,
  ): Promise<{ audit: AuditContext; at: Date; userId: string }> {
    if (request.authentication === undefined)
      throw new Error('Authentication guard did not attach claims');
    const user = await this.identities.resolve(request.authentication);
    const requestId = safeUuid(header(request, 'x-request-id'));
    return {
      at: new Date(),
      audit: {
        actorUserId: user.platformUserId,
        correlationId: safeUuid(header(request, 'x-correlation-id') ?? requestId),
        requestId,
      },
      userId: user.platformUserId,
    };
  }

  @Get()
  @ApiOperation({ summary: 'List the application-administration firm catalog' })
  async list(@Req() request: AuthenticatedRequest): Promise<FirmResponse[]> {
    const context = await this.context(request);
    return (await this.firms.list(context.userId, context.at)).map(firmResponse);
  }

  @Get(':firmId')
  @ApiOperation({ summary: 'Read one firm master record through the administration catalog' })
  async find(
    @Req() request: AuthenticatedRequest,
    @Param('firmId', ParseUUIDPipe) firmId: string,
  ): Promise<FirmResponse> {
    const context = await this.context(request);
    return firmResponse(await this.firms.find(context.userId, firmId, context.at));
  }

  @Post()
  @ApiOperation({ summary: 'Create only a Shared Core firm master record' })
  async create(
    @Req() request: AuthenticatedRequest,
    @Body() value: unknown,
  ): Promise<FirmResponse> {
    const context = await this.context(request);
    return firmResponse(await this.firms.create(createFirm(value), context.audit, context.at));
  }

  @Patch(':firmId/profile')
  async profile(
    @Req() request: AuthenticatedRequest,
    @Param('firmId', ParseUUIDPipe) firmId: string,
    @Body() value: unknown,
  ): Promise<FirmResponse> {
    const context = await this.context(request);
    return firmResponse(
      await this.firms.updateProfile(firmId, updateProfile(value), context.audit, context.at),
    );
  }

  @Patch(':firmId/identity')
  async identity(
    @Req() request: AuthenticatedRequest,
    @Param('firmId', ParseUUIDPipe) firmId: string,
    @Body() value: unknown,
  ): Promise<FirmResponse> {
    const context = await this.context(request);
    return firmResponse(
      await this.firms.updateIdentity(firmId, updateIdentity(value), context.audit, context.at),
    );
  }

  @Patch(':firmId/settings')
  async settings(
    @Req() request: AuthenticatedRequest,
    @Param('firmId', ParseUUIDPipe) firmId: string,
    @Body() value: unknown,
  ): Promise<FirmResponse> {
    const context = await this.context(request);
    return firmResponse(
      await this.firms.updateSettings(firmId, updateSettings(value), context.audit, context.at),
    );
  }

  @Post(':firmId/deactivate')
  async deactivate(
    @Req() request: AuthenticatedRequest,
    @Param('firmId', ParseUUIDPipe) firmId: string,
    @Body() value: unknown,
  ): Promise<FirmResponse> {
    const context = await this.context(request);
    return firmResponse(
      await this.firms.deactivate(firmId, lifecycle(value), context.audit, context.at),
    );
  }

  @Post(':firmId/activate')
  async activate(
    @Req() request: AuthenticatedRequest,
    @Param('firmId', ParseUUIDPipe) firmId: string,
    @Body() value: unknown,
  ): Promise<FirmResponse> {
    const context = await this.context(request);
    return firmResponse(
      await this.firms.activate(firmId, lifecycle(value), context.audit, context.at),
    );
  }
}
