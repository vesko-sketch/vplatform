import { Module } from '@nestjs/common';
import { createOidcTokenVerifier, OidcTokenVerifier } from '@vplatform/oidc-auth';

import { loadOfficeApiConfig } from '../config/oidc.config.js';
import { OfficeAuthenticationGuard } from './authentication.guard.js';

@Module({
  exports: [OfficeAuthenticationGuard, OidcTokenVerifier],
  providers: [
    {
      provide: OidcTokenVerifier,
      useFactory: (): OidcTokenVerifier => createOidcTokenVerifier(loadOfficeApiConfig()),
    },
    OfficeAuthenticationGuard,
  ],
})
export class OfficeAuthModule {}
