import { loadOidcConfig, type OidcClientConfig } from '@vplatform/identity-config';

export interface SharedCoreAuthConfig extends OidcClientConfig {
  clockToleranceSeconds: number;
  signingAlgorithm: 'RS256';
}

export function loadSharedCoreOidcConfig(
  environment: NodeJS.ProcessEnv = process.env,
): SharedCoreAuthConfig {
  const oidc = loadOidcConfig(environment, {
    audience: 'OIDC_SHARED_CORE_API_AUDIENCE',
    clientId: 'OIDC_SHARED_CORE_API_CLIENT_ID',
    issuerUrl: 'OIDC_ISSUER_URL',
  });

  const signingAlgorithm = environment.OIDC_SHARED_CORE_API_SIGNING_ALGORITHM ?? 'RS256';
  if (signingAlgorithm !== 'RS256') {
    throw new Error('OIDC_SHARED_CORE_API_SIGNING_ALGORITHM must be RS256');
  }

  const clockToleranceSeconds = Number(environment.OIDC_CLOCK_TOLERANCE_SECONDS ?? '5');
  if (
    !Number.isInteger(clockToleranceSeconds) ||
    clockToleranceSeconds < 0 ||
    clockToleranceSeconds > 60
  ) {
    throw new Error('OIDC_CLOCK_TOLERANCE_SECONDS must be an integer between 0 and 60');
  }

  return { ...oidc, clockToleranceSeconds, signingAlgorithm };
}
