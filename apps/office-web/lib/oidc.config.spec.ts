import { describe, expect, it } from 'vitest';

import { loadOfficeWebConfig } from './oidc.config';

describe('loadOfficeWebConfig', () => {
  it('requires server-only URLs and a strong session secret', () => {
    expect(
      loadOfficeWebConfig({
        OFFICE_API_URL: 'http://localhost:3002',
        OFFICE_OIDC_CLIENT_ID: 'office-web',
        OFFICE_OIDC_ISSUER_URL: 'http://localhost:8080/realms/vplatform',
        OFFICE_WEB_BASE_URL: 'http://localhost:3000',
        OFFICE_WEB_SESSION_SECRET: 'development-only-secret-at-least-32-characters',
      }),
    ).toMatchObject({ clientId: 'office-web', officeApiUrl: 'http://localhost:3002' });
  });

  it('rejects a weak cookie encryption secret', () => {
    expect(() =>
      loadOfficeWebConfig({
        OFFICE_API_URL: 'http://localhost:3002',
        OFFICE_OIDC_CLIENT_ID: 'office-web',
        OFFICE_OIDC_ISSUER_URL: 'http://localhost:8080/realms/vplatform',
        OFFICE_WEB_BASE_URL: 'http://localhost:3000',
        OFFICE_WEB_SESSION_SECRET: 'short',
      }),
    ).toThrow();
  });

  it('rejects an insecure non-local issuer', () => {
    expect(() =>
      loadOfficeWebConfig({
        OFFICE_API_URL: 'https://office-api.example.test',
        OFFICE_OIDC_CLIENT_ID: 'office-web',
        OFFICE_OIDC_ISSUER_URL: 'http://identity.example.test/realms/vplatform',
        OFFICE_WEB_BASE_URL: 'https://office.example.test',
        OFFICE_WEB_SESSION_SECRET: 'development-only-secret-at-least-32-characters',
      }),
    ).toThrow('must use HTTPS');
  });
});
