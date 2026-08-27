export interface OfficeWebConfig {
  baseUrl: string;
  clientId: string;
  issuerUrl: string;
  officeApiUrl: string;
  sessionSecret: string;
}

type Environment = Readonly<Record<string, string | undefined>>;

function required(environment: Environment, key: string): string {
  const value = environment[key]?.trim();
  if (value === undefined || value.length === 0) throw new Error(`Missing configuration: ${key}`);
  return value;
}

function url(environment: Environment, key: string): string {
  return new URL(required(environment, key)).toString().replace(/\/$/, '');
}

function issuerUrl(environment: Environment): string {
  const value = new URL(required(environment, 'OFFICE_OIDC_ISSUER_URL'));
  const isLocalDevelopmentIssuer = value.hostname === 'localhost' || value.hostname === '127.0.0.1';
  if (value.protocol !== 'https:' && !(value.protocol === 'http:' && isLocalDevelopmentIssuer)) {
    throw new Error('OFFICE_OIDC_ISSUER_URL must use HTTPS outside local development');
  }
  return value.toString().replace(/\/$/, '');
}

export function loadOfficeWebConfig(environment: Environment = process.env): OfficeWebConfig {
  const sessionSecret = required(environment, 'OFFICE_WEB_SESSION_SECRET');
  if (sessionSecret.length < 32)
    throw new Error('OFFICE_WEB_SESSION_SECRET must be at least 32 characters');
  return {
    baseUrl: url(environment, 'OFFICE_WEB_BASE_URL'),
    clientId: required(environment, 'OFFICE_OIDC_CLIENT_ID'),
    issuerUrl: issuerUrl(environment),
    officeApiUrl: url(environment, 'OFFICE_API_URL'),
    sessionSecret,
  };
}
