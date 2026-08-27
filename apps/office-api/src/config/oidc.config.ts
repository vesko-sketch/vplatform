import { loadOidcConfig, type OidcClientConfig } from '@vplatform/identity-config';

export interface OfficeApiConfig extends OidcClientConfig {
  clockToleranceSeconds: number;
  officeWebOrigin: string;
  sharedCoreApiUrl: string;
  signingAlgorithm: 'RS256';
}

function requiredUrl(environment: NodeJS.ProcessEnv, key: string): string {
  const value = environment[key]?.trim();
  if (value === undefined || value.length === 0) throw new Error(`Missing configuration: ${key}`);
  return new URL(value).toString().replace(/\/$/, '');
}

export function loadOfficeApiConfig(environment: NodeJS.ProcessEnv = process.env): OfficeApiConfig {
  const oidc = loadOidcConfig(environment, {
    audience: 'OIDC_OFFICE_API_AUDIENCE',
    clientId: 'OIDC_OFFICE_API_CLIENT_ID',
    issuerUrl: 'OIDC_ISSUER_URL',
  });
  const signingAlgorithm = environment.OIDC_OFFICE_API_SIGNING_ALGORITHM ?? 'RS256';
  if (signingAlgorithm !== 'RS256')
    throw new Error('OIDC_OFFICE_API_SIGNING_ALGORITHM must be RS256');
  const clockToleranceSeconds = Number(environment.OIDC_CLOCK_TOLERANCE_SECONDS ?? '5');
  if (
    !Number.isInteger(clockToleranceSeconds) ||
    clockToleranceSeconds < 0 ||
    clockToleranceSeconds > 60
  ) {
    throw new Error('OIDC_CLOCK_TOLERANCE_SECONDS must be an integer between 0 and 60');
  }
  return {
    ...oidc,
    clockToleranceSeconds,
    officeWebOrigin: requiredUrl(environment, 'OFFICE_WEB_ORIGIN'),
    sharedCoreApiUrl: requiredUrl(environment, 'SHARED_CORE_API_URL'),
    signingAlgorithm,
  };
}
