import { Controller, Get, Req, UseGuards } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiForbiddenResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';

import { AuthenticationGuard } from './authentication.guard.js';
import type { AuthenticatedRequest } from './auth.types.js';
import {
  type AuthenticatedPlatformUser,
  IdentityResolutionService,
} from '../identity/identity-resolution.service.js';

@ApiTags('authentication')
@ApiBearerAuth()
@Controller('auth')
export class AuthController {
  constructor(private readonly identityResolution: IdentityResolutionService) {}

  @Get('me')
  @UseGuards(AuthenticationGuard)
  @ApiOperation({ summary: 'Resolve an authenticated Keycloak identity to a platform user' })
  @ApiOkResponse({ description: 'Safe authentication claims and platform identity IDs only.' })
  @ApiForbiddenResponse({ description: 'Identity is not linked or the link/user is disabled.' })
  async getMe(@Req() request: AuthenticatedRequest): Promise<AuthenticatedPlatformUser> {
    if (request.authentication === undefined) {
      throw new Error('Authentication guard did not attach claims');
    }
    return this.identityResolution.resolve(request.authentication);
  }
}
