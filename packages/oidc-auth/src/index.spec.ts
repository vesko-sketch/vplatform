import { createLocalJWKSet, exportJWK, generateKeyPair, SignJWT, type JSONWebKeySet } from 'jose';
import { beforeAll, describe, expect, it } from 'vitest';

import { extractBearerToken, OidcTokenVerifier } from './index.js';

const issuer = 'https://identity.example.test/realms/vplatform';
const now = Math.floor(Date.now() / 1000);
let privateKey: CryptoKey;
let verifier: OidcTokenVerifier;

async function token(
  overrides: { audience?: string; issuer?: string; expires?: number; nbf?: number } = {},
): Promise<string> {
  let jwt = new SignJWT({
    preferred_username: 'ignored-for-authorization',
    realm_access: { roles: ['admin'] },
  })
    .setProtectedHeader({ alg: 'RS256', kid: 'test-key' })
    .setIssuer(overrides.issuer ?? issuer)
    .setSubject('opaque-subject')
    .setAudience(overrides.audience ?? 'office-api')
    .setIssuedAt(now)
    .setExpirationTime(overrides.expires ?? now + 300);
  if (overrides.nbf !== undefined) jwt = jwt.setNotBefore(overrides.nbf);
  return jwt.sign(privateKey);
}

beforeAll(async () => {
  const keys = await generateKeyPair('RS256');
  privateKey = keys.privateKey;
  const jwk = await exportJWK(keys.publicKey);
  jwk.alg = 'RS256';
  jwk.kid = 'test-key';
  verifier = new OidcTokenVerifier(
    {
      audience: 'office-api',
      clockToleranceSeconds: 5,
      issuerUrl: issuer,
      signingAlgorithm: 'RS256',
    },
    createLocalJWKSet({ keys: [jwk] } satisfies JSONWebKeySet),
  );
});

describe('OIDC resource-server primitives', () => {
  it('extracts only a strict bearer token', () => {
    expect(extractBearerToken('Bearer token')).toBe('token');
    expect(() => extractBearerToken(undefined)).toThrow();
    expect(() => extractBearerToken('Basic token')).toThrow();
  });

  it('validates issuer, audience, expiry and not-before', async () => {
    await expect(verifier.verify(await token())).resolves.toMatchObject({
      subject: 'opaque-subject',
    });
    await expect(verifier.verify(await token({ audience: 'shared-core-api' }))).rejects.toThrow();
    await expect(
      verifier.verify(await token({ issuer: 'https://wrong.example.test' })),
    ).rejects.toThrow();
    await expect(verifier.verify(await token({ expires: now - 60 }))).rejects.toThrow();
    await expect(verifier.verify(await token({ nbf: now + 60 }))).rejects.toThrow();
    await expect(verifier.verify('malformed')).rejects.toThrow();
  });
});
