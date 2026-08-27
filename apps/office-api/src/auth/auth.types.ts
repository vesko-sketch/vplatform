import type { AuthenticationClaims } from '@vplatform/oidc-auth';

export interface AuthenticatedOfficeRequest {
  authentication?: AuthenticationClaims;
  bearerToken?: string;
  headers: Readonly<Record<string, string | string[] | undefined>>;
}
