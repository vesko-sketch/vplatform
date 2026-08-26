import { createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey, type JWTPayload } from 'jose';

import type { SharedCoreAuthConfig } from '../config/oidc.config.js';
import type { AuthenticationClaims } from './auth.types.js';

function normalizeAudience(audience: JWTPayload['aud']): string[] {
  if (typeof audience === 'string') {
    return [audience];
  }
  return audience ?? [];
}

export class TokenVerifier {
  constructor(
    private readonly config: SharedCoreAuthConfig,
    private readonly verificationKey: JWTVerifyGetKey,
  ) {}

  async verify(token: string): Promise<AuthenticationClaims> {
    const { payload } = await jwtVerify(token, this.verificationKey, {
      algorithms: [this.config.signingAlgorithm],
      audience: this.config.audience,
      clockTolerance: this.config.clockToleranceSeconds,
      issuer: this.config.issuerUrl,
    });

    if (payload.iss === undefined || payload.sub === undefined) {
      throw new Error('Token must contain issuer and subject claims');
    }

    const preferredUsername = payload.preferred_username;
    return {
      audience: normalizeAudience(payload.aud),
      issuer: payload.iss,
      ...(typeof preferredUsername === 'string' ? { preferredUsername } : {}),
      subject: payload.sub,
    };
  }
}

export function createKeycloakTokenVerifier(config: SharedCoreAuthConfig): TokenVerifier {
  const jwksUrl = new URL(`${config.issuerUrl}/protocol/openid-connect/certs`);
  return new TokenVerifier(config, createRemoteJWKSet(jwksUrl));
}
