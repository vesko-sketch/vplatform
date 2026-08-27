import { describe, expect, it } from 'vitest';

import { loadOfficeApiConfig } from './oidc.config.js';

const environment = {
  OFFICE_WEB_ORIGIN: 'http://localhost:3000',
  OIDC_ISSUER_URL: 'http://localhost:8080/realms/vplatform',
  OIDC_OFFICE_API_AUDIENCE: 'office-api',
  OIDC_OFFICE_API_CLIENT_ID: 'office-api',
  SHARED_CORE_API_URL: 'http://localhost:3001',
};

describe('loadOfficeApiConfig', () => {
  it('loads an exact RS256 resource-server and internal-client configuration', () => {
    expect(loadOfficeApiConfig(environment)).toMatchObject({
      audience: 'office-api',
      clockToleranceSeconds: 5,
      issuerUrl: 'http://localhost:8080/realms/vplatform',
      officeWebOrigin: 'http://localhost:3000',
      sharedCoreApiUrl: 'http://localhost:3001',
      signingAlgorithm: 'RS256',
    });
  });

  it('rejects unsupported algorithms and missing Shared Core URLs', () => {
    expect(() =>
      loadOfficeApiConfig({ ...environment, OIDC_OFFICE_API_SIGNING_ALGORITHM: 'HS256' }),
    ).toThrow();
    expect(() => loadOfficeApiConfig({ ...environment, SHARED_CORE_API_URL: '' })).toThrow();
  });
});
