import { loadOidcConfig, type OidcClientConfig } from '@vplatform/identity-config';

export function loadSharedCoreOidcConfig(
  environment: NodeJS.ProcessEnv = process.env,
): OidcClientConfig {
  return loadOidcConfig(environment, {
    audience: 'OIDC_SHARED_CORE_API_AUDIENCE',
    clientId: 'OIDC_SHARED_CORE_API_CLIENT_ID',
    issuerUrl: 'OIDC_ISSUER_URL',
  });
}
