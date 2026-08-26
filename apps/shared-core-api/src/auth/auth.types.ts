export interface AuthenticationClaims {
  audience: string[];
  issuer: string;
  preferredUsername?: string;
  subject: string;
}

export interface AuthenticatedRequest {
  authentication?: AuthenticationClaims;
  headers: Readonly<Record<string, string | string[] | undefined>>;
}
