import { createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey, type JWTPayload } from 'jose';

export interface OidcResourceServerConfig {
  audience: string;
  clockToleranceSeconds: number;
  issuerUrl: string;
  signingAlgorithm: 'RS256';
}

export interface AuthenticationClaims {
  audience: string[];
  issuer: string;
  preferredUsername?: string;
  subject: string;
}

function normalizeAudience(audience: JWTPayload['aud']): string[] {
  if (typeof audience === 'string') return [audience];
  return audience ?? [];
}

export class OidcTokenVerifier {
  constructor(
    private readonly config: OidcResourceServerConfig,
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

export function createOidcTokenVerifier(config: OidcResourceServerConfig): OidcTokenVerifier {
  return new OidcTokenVerifier(
    config,
    createRemoteJWKSet(new URL(`${config.issuerUrl}/protocol/openid-connect/certs`)),
  );
}

export function extractBearerToken(authorization: string | string[] | undefined): string {
  if (typeof authorization !== 'string') throw new Error('Bearer token is required');
  const match = /^Bearer ([^\s]+)$/i.exec(authorization);
  if (match?.[1] === undefined) throw new Error('Authorization header must use the Bearer scheme');
  return match[1];
}
