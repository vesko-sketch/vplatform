import {
  Controller,
  Body,
  ForbiddenException,
  Get,
  Patch,
  Param,
  ParseUUIDPipe,
  Req,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';

import { OfficeAuthenticationGuard } from '../auth/authentication.guard.js';
import type { AuthenticatedOfficeRequest } from '../auth/auth.types.js';
import {
  type AccessibleFirm,
  type FirmMaster,
  type PlatformIdentity,
  SharedCoreAuthorizationClient,
} from '../shared-core/shared-core.client.js';
import { OfficePermissionGuard, RequireOfficePermission } from './office-permission.guard.js';

function token(request: AuthenticatedOfficeRequest): string {
  if (request.bearerToken === undefined)
    throw new Error('Authentication guard did not attach token');
  return request.bearerToken;
}

@ApiTags('office authorization')
@ApiBearerAuth()
@UseGuards(OfficeAuthenticationGuard)
@Controller('office')
export class OfficeController {
  constructor(private readonly sharedCore: SharedCoreAuthorizationClient) {}

  @Get('me')
  @ApiOperation({ summary: 'Resolve the current Office platform identity' })
  async me(@Req() request: AuthenticatedOfficeRequest): Promise<PlatformIdentity> {
    return this.sharedCore.resolveMe(token(request));
  }

  @Get('firms')
  @ApiOperation({ summary: 'List firms accessible to the current Office user' })
  async firms(@Req() request: AuthenticatedOfficeRequest): Promise<AccessibleFirm[]> {
    return this.sharedCore.listFirms(token(request));
  }

  @Get('firms/:firmId/context')
  @ApiOperation({ summary: 'Get base OFFICE authorization context for one firm' })
  async context(
    @Req() request: AuthenticatedOfficeRequest,
    @Param('firmId', ParseUUIDPipe) firmId: string,
  ): Promise<{ authorizationLevel: 'base'; firm: AccessibleFirm; permissions: string[] }> {
    const permissions = await this.sharedCore.getOfficePermissions(token(request), firmId);
    const firms = await this.sharedCore.listFirms(token(request));
    const selectedFirm = firms.find((firm) => firm.id === firmId);
    if (selectedFirm === undefined) throw new ForbiddenException('Office firm access is denied');
    return { authorizationLevel: 'base', firm: selectedFirm, permissions: permissions.permissions };
  }

  @Get('firms/:firmId/proof/documents')
  @UseGuards(OfficePermissionGuard)
  @RequireOfficePermission('documents.view')
  @ApiOperation({ summary: 'Prove delegated OFFICE documents.view authorization' })
  proofDocuments(@Param('firmId', ParseUUIDPipe) firmId: string): {
    authorizationLevel: 'base';
    authorized: true;
    firmId: string;
    permission: 'documents.view';
    requiresDomainPolicy: true;
  } {
    return {
      authorizationLevel: 'base' as const,
      authorized: true,
      firmId,
      permission: 'documents.view' as const,
      requiresDomainPolicy: true as const,
    };
  }

  @Get('admin/firms')
  @ApiOperation({ summary: 'List the delegated Shared Core firm administration catalog' })
  adminFirms(@Req() request: AuthenticatedOfficeRequest): Promise<FirmMaster[]> {
    return this.sharedCore.listAdminFirms(token(request));
  }

  @Get('admin/firms/:firmId')
  adminFirm(
    @Req() request: AuthenticatedOfficeRequest,
    @Param('firmId', ParseUUIDPipe) firmId: string,
  ): Promise<FirmMaster> {
    return this.sharedCore.getAdminFirm(token(request), firmId);
  }

  @Post('admin/firms')
  createFirm(
    @Req() request: AuthenticatedOfficeRequest,
    @Body() body: unknown,
  ): Promise<FirmMaster> {
    return this.sharedCore.createFirm(token(request), body);
  }

  @Patch('admin/firms/:firmId/profile')
  profile(
    @Req() request: AuthenticatedOfficeRequest,
    @Param('firmId', ParseUUIDPipe) firmId: string,
    @Body() body: unknown,
  ): Promise<FirmMaster> {
    return this.sharedCore.firmCommand(
      token(request),
      'PATCH',
      `${encodeURIComponent(firmId)}/profile`,
      body,
    );
  }

  @Patch('admin/firms/:firmId/identity')
  identity(
    @Req() request: AuthenticatedOfficeRequest,
    @Param('firmId', ParseUUIDPipe) firmId: string,
    @Body() body: unknown,
  ): Promise<FirmMaster> {
    return this.sharedCore.firmCommand(
      token(request),
      'PATCH',
      `${encodeURIComponent(firmId)}/identity`,
      body,
    );
  }

  @Patch('admin/firms/:firmId/settings')
  settings(
    @Req() request: AuthenticatedOfficeRequest,
    @Param('firmId', ParseUUIDPipe) firmId: string,
    @Body() body: unknown,
  ): Promise<FirmMaster> {
    return this.sharedCore.firmCommand(
      token(request),
      'PATCH',
      `${encodeURIComponent(firmId)}/settings`,
      body,
    );
  }

  @Post('admin/firms/:firmId/deactivate')
  deactivate(
    @Req() request: AuthenticatedOfficeRequest,
    @Param('firmId', ParseUUIDPipe) firmId: string,
    @Body() body: unknown,
  ): Promise<FirmMaster> {
    return this.sharedCore.firmCommand(
      token(request),
      'POST',
      `${encodeURIComponent(firmId)}/deactivate`,
      body,
    );
  }

  @Post('admin/firms/:firmId/activate')
  activate(
    @Req() request: AuthenticatedOfficeRequest,
    @Param('firmId', ParseUUIDPipe) firmId: string,
    @Body() body: unknown,
  ): Promise<FirmMaster> {
    return this.sharedCore.firmCommand(
      token(request),
      'POST',
      `${encodeURIComponent(firmId)}/activate`,
      body,
    );
  }
}
