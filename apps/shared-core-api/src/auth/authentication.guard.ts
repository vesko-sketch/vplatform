import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { extractBearerToken as extractOidcBearerToken } from '@vplatform/oidc-auth';

import type { AuthenticatedRequest } from './auth.types.js';
import { TokenVerifier } from './token-verifier.js';

export function extractBearerToken(authorization: string | string[] | undefined): string {
  try {
    return extractOidcBearerToken(authorization);
  } catch (error) {
    throw new UnauthorizedException(
      error instanceof Error ? error.message : 'Bearer token is invalid',
    );
  }
}

@Injectable()
export class AuthenticationGuard implements CanActivate {
  constructor(private readonly tokenVerifier: TokenVerifier) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
    const token = extractBearerToken(request.headers.authorization);

    try {
      request.authentication = await this.tokenVerifier.verify(token);
      return true;
    } catch {
      throw new UnauthorizedException('Bearer token is invalid');
    }
  }
}
