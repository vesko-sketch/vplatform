import {
  CanActivate,
  ExecutionContext,
  Inject,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { extractBearerToken, OidcTokenVerifier } from '@vplatform/oidc-auth';

import type { AuthenticatedOfficeRequest } from './auth.types.js';

@Injectable()
export class OfficeAuthenticationGuard implements CanActivate {
  constructor(@Inject(OidcTokenVerifier) private readonly verifier: OidcTokenVerifier) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthenticatedOfficeRequest>();
    try {
      const token = extractBearerToken(request.headers.authorization);
      request.authentication = await this.verifier.verify(token);
      request.bearerToken = token;
      return true;
    } catch {
      throw new UnauthorizedException('Bearer token is invalid');
    }
  }
}
