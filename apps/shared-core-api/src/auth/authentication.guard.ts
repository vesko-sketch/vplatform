import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';

import type { AuthenticatedRequest } from './auth.types.js';
import { TokenVerifier } from './token-verifier.js';

export function extractBearerToken(authorization: string | string[] | undefined): string {
  if (typeof authorization !== 'string') {
    throw new UnauthorizedException('Bearer token is required');
  }

  const match = /^Bearer ([^\s]+)$/i.exec(authorization);
  if (match?.[1] === undefined) {
    throw new UnauthorizedException('Authorization header must use the Bearer scheme');
  }
  return match[1];
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
