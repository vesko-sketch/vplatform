import { createOidcTokenVerifier, OidcTokenVerifier } from '@vplatform/oidc-auth';

import type { SharedCoreAuthConfig } from '../config/oidc.config.js';

export { OidcTokenVerifier as TokenVerifier };

export function createKeycloakTokenVerifier(config: SharedCoreAuthConfig): OidcTokenVerifier {
  return createOidcTokenVerifier(config);
}
