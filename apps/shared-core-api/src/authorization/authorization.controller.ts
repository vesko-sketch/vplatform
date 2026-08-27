import { Controller, Get, Param, ParseUUIDPipe, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';

import { AuthenticationGuard } from '../auth/authentication.guard.js';
import type { AuthenticatedRequest } from '../auth/auth.types.js';
import { IdentityResolutionService } from '../identity/identity-resolution.service.js';
import { AuthorizationService } from './authorization.service.js';
interface ApplicationResponse {
  code: string;
  name: string;
}

interface FirmResponse {
  code: string;
  id: string;
  name: string;
  shortName: string | null;
}

interface PermissionContextResponse {
  applicationCode: string;
  authorizationLevel: 'base';
  firmId: string;
  permissions: string[];
  requiresDomainPolicy: true;
}

interface PublicDecisionResponse {
  allowed: boolean;
  authorizationLevel: 'base';
  requiresDomainPolicy: true;
}

export abstract class AuthorizationClock {
  abstract now(): Date;
}

export class SystemAuthorizationClock extends AuthorizationClock {
  now(): Date {
    return new Date();
  }
}

async function platformUserId(
  request: AuthenticatedRequest,
  identities: IdentityResolutionService,
): Promise<string> {
  if (request.authentication === undefined)
    throw new Error('Authentication guard did not attach claims');
  return (await identities.resolve(request.authentication)).platformUserId;
}

@ApiTags('authorization context')
@ApiBearerAuth()
@UseGuards(AuthenticationGuard)
@Controller('me')
export class AuthorizationController {
  constructor(
    private readonly authorization: AuthorizationService,
    private readonly clock: AuthorizationClock,
    private readonly identities: IdentityResolutionService,
  ) {}

  @Get('applications')
  @ApiOperation({ summary: 'List applications available through current firm/application grants' })
  @ApiOkResponse({
    description: 'Current accessible applications; role defaults are not consulted.',
  })
  async applications(@Req() request: AuthenticatedRequest): Promise<ApplicationResponse[]> {
    const userId = await platformUserId(request, this.identities);
    return (await this.authorization.listApplications(userId, this.clock.now())).map(
      ({ code, name }) => ({
        code,
        name,
      }),
    );
  }

  @Get('firms')
  @ApiOperation({ summary: 'List firms available through current firm/application grants' })
  @ApiOkResponse({ description: 'Current accessible firms; firm groups and roles grant nothing.' })
  async firms(@Req() request: AuthenticatedRequest): Promise<FirmResponse[]> {
    const userId = await platformUserId(request, this.identities);
    return (await this.authorization.listFirms(userId, this.clock.now())).map(
      ({ code, id, name, shortName }) => ({ code, id, name, shortName }),
    );
  }

  @Get('firms/:firmId/applications')
  @ApiOperation({ summary: 'List currently accessible applications for one firm' })
  async firmApplications(
    @Req() request: AuthenticatedRequest,
    @Param('firmId', ParseUUIDPipe) firmId: string,
  ): Promise<ApplicationResponse[]> {
    const userId = await platformUserId(request, this.identities);
    return (await this.authorization.listFirmApplications(userId, firmId, this.clock.now())).map(
      ({ code, name }) => ({ code, name }),
    );
  }

  @Get('firms/:firmId/applications/:applicationCode/permissions')
  @ApiOperation({ summary: 'List base permissions for one accessible firm/application' })
  async permissions(
    @Req() request: AuthenticatedRequest,
    @Param('firmId', ParseUUIDPipe) firmId: string,
    @Param('applicationCode') applicationCode: string,
  ): Promise<PermissionContextResponse> {
    const userId = await platformUserId(request, this.identities);
    const result = await this.authorization.listEffectivePermissions(
      userId,
      applicationCode,
      firmId,
      this.clock.now(),
    );
    return {
      applicationCode,
      authorizationLevel: 'base' as const,
      firmId,
      permissions: result.permissions,
      requiresDomainPolicy: true as const,
    };
  }

  @Get('firms/:firmId/applications/:applicationCode/permissions/:permissionCode')
  @ApiOperation({ summary: 'Evaluate one application-qualified base permission' })
  async permissionDecision(
    @Req() request: AuthenticatedRequest,
    @Param('firmId', ParseUUIDPipe) firmId: string,
    @Param('applicationCode') applicationCode: string,
    @Param('permissionCode') permissionCode: string,
  ): Promise<PublicDecisionResponse> {
    const userId = await platformUserId(request, this.identities);
    const result = await this.authorization.can({
      applicationCode,
      evaluatedAt: this.clock.now(),
      firmId,
      permissionCode,
      platformUserId: userId,
    });
    return {
      allowed: result.basePermissionGranted,
      authorizationLevel: result.authorizationLevel,
      requiresDomainPolicy: result.requiresDomainPolicy,
    };
  }
}
