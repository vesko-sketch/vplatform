import {
  Controller,
  ForbiddenException,
  Get,
  Param,
  ParseUUIDPipe,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';

import { OfficeAuthenticationGuard } from '../auth/authentication.guard.js';
import type { AuthenticatedOfficeRequest } from '../auth/auth.types.js';
import {
  type AccessibleFirm,
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
}
