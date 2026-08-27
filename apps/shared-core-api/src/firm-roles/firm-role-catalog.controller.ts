import { Controller, Get, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';

import { AuthenticationGuard } from '../auth/authentication.guard.js';
import type { AuthenticatedRequest } from '../auth/auth.types.js';
import { IdentityResolutionService } from '../identity/identity-resolution.service.js';
import type { FirmRoleCatalogItem } from './firm-role-catalog.repository.js';
import { FirmRoleCatalogService } from './firm-role-catalog.service.js';

@ApiTags('firm role administration')
@ApiBearerAuth()
@UseGuards(AuthenticationGuard)
@Controller('firm-roles')
export class FirmRoleCatalogController {
  constructor(
    private readonly identities: IdentityResolutionService,
    private readonly roles: FirmRoleCatalogService,
  ) {}

  @Get()
  @ApiOperation({ summary: 'List active firm roles for application administration' })
  async list(@Req() request: AuthenticatedRequest): Promise<FirmRoleCatalogItem[]> {
    if (!request.authentication) throw new Error('Authentication claims missing');
    const identity = await this.identities.resolve(request.authentication);
    return this.roles.list(identity.platformUserId, new Date());
  }
}
