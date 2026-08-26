import { UnauthorizedException } from '@nestjs/common';
import { createLocalJWKSet, exportJWK, generateKeyPair, SignJWT, type JSONWebKeySet } from 'jose';
import { beforeAll, describe, expect, it } from 'vitest';

import type { SharedCoreAuthConfig } from '../config/oidc.config.js';
import { extractBearerToken } from './authentication.guard.js';
import { TokenVerifier } from './token-verifier.js';

const issuer = 'https://identity.example.test/realms/vplatform';
const audience = 'shared-core-api';
const keyId = 'deterministic-test-key-id';
const now = Math.floor(Date.now() / 1000);

const config: SharedCoreAuthConfig = {
  audience,
  clientId: 'shared-core-api',
  clockToleranceSeconds: 5,
  issuerUrl: issuer,
  signingAlgorithm: 'RS256',
};

let privateKey: CryptoKey;
let verifier: TokenVerifier;

interface TokenOverrides {
  audience?: string;
  expiresAt?: number;
  issuer?: string;
  notBefore?: number;
}

async function signToken(overrides: TokenOverrides = {}): Promise<string> {
  let token = new SignJWT({
    email: 'mutable@example.test',
    preferred_username: 'development-user',
    realm_access: { roles: ['ignored-role'] },
  })
    .setProtectedHeader({ alg: 'RS256', kid: keyId })
    .setIssuer(overrides.issuer ?? issuer)
    .setSubject('keycloak-subject-123')
    .setAudience(overrides.audience ?? audience)
    .setIssuedAt(now)
    .setExpirationTime(overrides.expiresAt ?? now + 300);

  if (overrides.notBefore !== undefined) {
    token = token.setNotBefore(overrides.notBefore);
  }
  return token.sign(privateKey);
}

beforeAll(async () => {
  const keyPair = await generateKeyPair('RS256');
  privateKey = keyPair.privateKey;
  const publicJwk = await exportJWK(keyPair.publicKey);
  publicJwk.alg = 'RS256';
  publicJwk.kid = keyId;
  const localJwks: JSONWebKeySet = { keys: [publicJwk] };
  verifier = new TokenVerifier(config, createLocalJWKSet(localJwks));
});

describe('Bearer token extraction', () => {
  it('rejects a missing token', () => {
    expect(() => extractBearerToken(undefined)).toThrow(UnauthorizedException);
  });

  it('rejects a malformed authorization header', () => {
    expect(() => extractBearerToken('Basic credentials')).toThrow(
      'Authorization header must use the Bearer scheme',
    );
  });
});

describe('TokenVerifier', () => {
  it('rejects a malformed token', async () => {
    await expect(verifier.verify('not-a-jwt')).rejects.toThrow();
  });

  it('rejects the wrong issuer', async () => {
    await expect(
      verifier.verify(await signToken({ issuer: 'https://wrong.example.test/realms/vplatform' })),
    ).rejects.toThrow();
  });

  it('rejects the wrong audience', async () => {
    await expect(verifier.verify(await signToken({ audience: 'office-api' }))).rejects.toThrow();
  });

  it('rejects an expired token beyond clock tolerance', async () => {
    await expect(verifier.verify(await signToken({ expiresAt: now - 60 }))).rejects.toThrow();
  });

  it('rejects a token that is not active yet', async () => {
    await expect(verifier.verify(await signToken({ notBefore: now + 60 }))).rejects.toThrow();
  });

  it('accepts a valid token and returns authentication claims only', async () => {
    await expect(verifier.verify(await signToken())).resolves.toEqual({
      audience: ['shared-core-api'],
      issuer,
      preferredUsername: 'development-user',
      subject: 'keycloak-subject-123',
    });
  });
});
