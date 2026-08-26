import { loadOidcConfig, type OidcClientConfig } from '@vplatform/identity-config';

export function loadOfficeApiOidcConfig(
  environment: NodeJS.ProcessEnv = process.env,
): OidcClientConfig {
  return loadOidcConfig(environment, {
    audience: 'OIDC_OFFICE_API_AUDIENCE',
    clientId: 'OIDC_OFFICE_API_CLIENT_ID',
    issuerUrl: 'OIDC_ISSUER_URL',
  });
}
