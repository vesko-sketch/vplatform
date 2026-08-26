import { Module } from '@nestjs/common';

import { loadSharedCoreOidcConfig } from '../config/oidc.config.js';
import { AuthController } from './auth.controller.js';
import { AuthenticationGuard } from './authentication.guard.js';
import { createKeycloakTokenVerifier, TokenVerifier } from './token-verifier.js';

@Module({
  controllers: [AuthController],
  providers: [
    {
      provide: TokenVerifier,
      useFactory: (): TokenVerifier => createKeycloakTokenVerifier(loadSharedCoreOidcConfig()),
    },
    AuthenticationGuard,
  ],
})
export class AuthModule {}
