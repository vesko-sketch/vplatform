import { loadOidcConfig, type OidcClientConfig } from '@vplatform/identity-config';

export function loadAccountingApiOidcConfig(
  environment: NodeJS.ProcessEnv = process.env,
): OidcClientConfig {
  return loadOidcConfig(environment, {
    audience: 'OIDC_ACCOUNTING_API_AUDIENCE',
    clientId: 'OIDC_ACCOUNTING_API_CLIENT_ID',
    issuerUrl: 'OIDC_ISSUER_URL',
  });
}
