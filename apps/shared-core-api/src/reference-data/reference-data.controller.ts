import { Controller, Get, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';

import { AuthenticationGuard } from '../auth/authentication.guard.js';
import type { AuthenticatedRequest } from '../auth/auth.types.js';
import { IdentityResolutionService } from '../identity/identity-resolution.service.js';
import { ReferenceDataRepository } from './reference-data.repository.js';

@ApiTags('reference data')
@ApiBearerAuth()
@UseGuards(AuthenticationGuard)
@Controller('reference-data')
export class ReferenceDataController {
  constructor(
    private readonly identities: IdentityResolutionService,
    private readonly references: ReferenceDataRepository,
  ) {}

  private async authenticated(request: AuthenticatedRequest): Promise<void> {
    if (!request.authentication) throw new Error('Authentication claims missing');
    await this.identities.resolve(request.authentication);
  }

  @Get('countries') async countries(
    @Req() request: AuthenticatedRequest,
  ): Promise<Array<Record<string, unknown>>> {
    await this.authenticated(request);
    return this.references.countries();
  }
  @Get('currencies') async currencies(
    @Req() request: AuthenticatedRequest,
  ): Promise<Array<Record<string, unknown>>> {
    await this.authenticated(request);
    return this.references.currencies();
  }
  @Get('languages') async languages(
    @Req() request: AuthenticatedRequest,
  ): Promise<Array<Record<string, unknown>>> {
    await this.authenticated(request);
    return this.references.languages();
  }
  @Get('legal-forms') async legalForms(
    @Req() request: AuthenticatedRequest,
  ): Promise<Array<Record<string, unknown>>> {
    await this.authenticated(request);
    return this.references.legalForms();
  }
}
