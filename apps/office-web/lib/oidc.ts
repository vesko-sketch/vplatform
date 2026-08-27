import * as oidc from 'openid-client';

import { loadOfficeWebConfig } from './oidc.config';

let configuration: Promise<oidc.Configuration> | undefined;

export function getOidcConfiguration(): Promise<oidc.Configuration> {
  const config = loadOfficeWebConfig();
  const issuer = new URL(config.issuerUrl);
  const allowLocalHttp =
    issuer.protocol === 'http:' &&
    (issuer.hostname === 'localhost' || issuer.hostname === '127.0.0.1');
  configuration ??= oidc.discovery(
    issuer,
    config.clientId,
    { token_endpoint_auth_method: 'none' },
    undefined,
    allowLocalHttp ? { execute: [oidc.allowInsecureRequests] } : undefined,
  );
  return configuration;
}

export { oidc };
