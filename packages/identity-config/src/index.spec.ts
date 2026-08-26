import { describe, expect, it } from 'vitest';

import { loadOidcConfig } from './index.js';

const keys = {
  audience: 'OIDC_AUDIENCE',
  clientId: 'OIDC_CLIENT_ID',
  issuerUrl: 'OIDC_ISSUER_URL',
};

describe('loadOidcConfig', () => {
  it('loads a complete localhost development configuration', () => {
    expect(
      loadOidcConfig(
        {
          OIDC_AUDIENCE: 'office-api',
          OIDC_CLIENT_ID: 'office-web',
          OIDC_ISSUER_URL: 'http://localhost:8080/realms/vplatform/',
        },
        keys,
      ),
    ).toEqual({
      audience: 'office-api',
      clientId: 'office-web',
      issuerUrl: 'http://localhost:8080/realms/vplatform',
    });
  });

  it('rejects a missing audience', () => {
    expect(() =>
      loadOidcConfig(
        {
          OIDC_CLIENT_ID: 'office-web',
          OIDC_ISSUER_URL: 'https://identity.example.com/realms/vplatform',
        },
        keys,
      ),
    ).toThrow('Missing required OIDC configuration: OIDC_AUDIENCE');
  });

  it('rejects insecure non-local issuers', () => {
    expect(() =>
      loadOidcConfig(
        {
          OIDC_AUDIENCE: 'office-api',
          OIDC_CLIENT_ID: 'office-web',
          OIDC_ISSUER_URL: 'http://identity.example.com/realms/vplatform',
        },
        keys,
      ),
    ).toThrow('OIDC_ISSUER_URL must use HTTPS except for localhost development');
  });
});
