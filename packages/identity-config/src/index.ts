export interface OidcClientConfig {
  audience: string;
  clientId: string;
  issuerUrl: string;
}

export interface OidcEnvironmentKeys {
  audience: string;
  clientId: string;
  issuerUrl: string;
}

export type Environment = Readonly<Record<string, string | undefined>>;

function requireValue(environment: Environment, key: string): string {
  const value = environment[key]?.trim();
  if (value === undefined || value.length === 0) {
    throw new Error(`Missing required OIDC configuration: ${key}`);
  }
  return value;
}

function validateIssuer(value: string, key: string): string {
  let issuer: URL;
  try {
    issuer = new URL(value);
  } catch {
    throw new Error(`Invalid OIDC issuer URL in ${key}`);
  }

  const isLocalDevelopment = issuer.hostname === 'localhost' || issuer.hostname === '127.0.0.1';
  if (issuer.protocol !== 'https:' && !(isLocalDevelopment && issuer.protocol === 'http:')) {
    throw new Error(`${key} must use HTTPS except for localhost development`);
  }

  return issuer.toString().replace(/\/$/, '');
}

export function loadOidcConfig(
  environment: Environment,
  keys: OidcEnvironmentKeys,
): OidcClientConfig {
  return {
    audience: requireValue(environment, keys.audience),
    clientId: requireValue(environment, keys.clientId),
    issuerUrl: validateIssuer(requireValue(environment, keys.issuerUrl), keys.issuerUrl),
  };
}
