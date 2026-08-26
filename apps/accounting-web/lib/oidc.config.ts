import { loadOidcConfig, type OidcClientConfig } from '@vplatform/identity-config';

export function loadAccountingWebOidcConfig(
  environment: NodeJS.ProcessEnv = process.env,
): OidcClientConfig {
  return loadOidcConfig(environment, {
    audience: 'NEXT_PUBLIC_ACCOUNTING_OIDC_AUDIENCE',
    clientId: 'NEXT_PUBLIC_ACCOUNTING_OIDC_CLIENT_ID',
    issuerUrl: 'NEXT_PUBLIC_ACCOUNTING_OIDC_ISSUER_URL',
  });
}
