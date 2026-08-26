import { describe, expect, it } from 'vitest';

import { loadSharedCoreOidcConfig } from './oidc.config.js';

const validEnvironment = {
  OIDC_ISSUER_URL: 'http://localhost:8080/realms/vplatform',
  OIDC_SHARED_CORE_API_AUDIENCE: 'shared-core-api',
  OIDC_SHARED_CORE_API_CLIENT_ID: 'shared-core-api',
};

describe('loadSharedCoreOidcConfig', () => {
  it('uses secure validation defaults', () => {
    expect(loadSharedCoreOidcConfig(validEnvironment)).toEqual({
      audience: 'shared-core-api',
      clientId: 'shared-core-api',
      clockToleranceSeconds: 5,
      issuerUrl: 'http://localhost:8080/realms/vplatform',
      signingAlgorithm: 'RS256',
    });
  });

  it('rejects an unsupported signing algorithm', () => {
    expect(() =>
      loadSharedCoreOidcConfig({
        ...validEnvironment,
        OIDC_SHARED_CORE_API_SIGNING_ALGORITHM: 'HS256',
      }),
    ).toThrow('OIDC_SHARED_CORE_API_SIGNING_ALGORITHM must be RS256');
  });

  it('rejects excessive clock tolerance', () => {
    expect(() =>
      loadSharedCoreOidcConfig({
        ...validEnvironment,
        OIDC_CLOCK_TOLERANCE_SECONDS: '120',
      }),
    ).toThrow('OIDC_CLOCK_TOLERANCE_SECONDS must be an integer between 0 and 60');
  });
});
