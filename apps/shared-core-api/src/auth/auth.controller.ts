import { Controller, Get, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';

import { AuthenticationGuard } from './authentication.guard.js';
import type { AuthenticatedRequest, AuthenticationClaims } from './auth.types.js';

@ApiTags('authentication')
@ApiBearerAuth()
@Controller('auth')
export class AuthController {
  @Get('me')
  @UseGuards(AuthenticationGuard)
  @ApiOperation({ summary: 'Return safe claims for the authenticated Keycloak identity' })
  @ApiOkResponse({ description: 'Authentication claims only; no platform authorization.' })
  getMe(@Req() request: AuthenticatedRequest): AuthenticationClaims {
    if (request.authentication === undefined) {
      throw new Error('Authentication guard did not attach claims');
    }
    return request.authentication;
  }
}
