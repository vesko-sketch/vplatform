# V Office authentication integration

V Office uses a browser-facing backend-for-frontend session and delegated authorization:

```text
browser → office-web server → Keycloak Authorization Code + PKCE
browser → office-web BFF → office-api → shared-core-api → shared_core
```

Office Web uses `openid-client` for discovery, transaction-specific state/nonce, PKCE S256, code exchange, refresh, and logout URL construction. `iron-session` stores tokens in a signed and encrypted `HttpOnly` cookie. Browser JavaScript receives only safe identity, firm, and permission-context responses. It never receives an access or refresh token.

The cookie is `SameSite=Lax`, which permits the top-level OIDC callback while limiting cross-site cookie sending. It is `Secure` whenever `OFFICE_WEB_BASE_URL` is HTTPS and only permits insecure transport for localhost development. Logout is POST-only to avoid a cross-site GET destroying sessions. The callback validates state, nonce, and PKCE verifier and destroys invalid sessions. Refresh failure destroys the local session and requires login again.

Office API independently validates every bearer token with the exact issuer, `office-api` audience, RS256, Keycloak JWKS, expiry/not-before, and bounded clock tolerance. Email, username, browser headers, and Keycloak roles are ignored for business authorization.

Office API forwards the already validated user bearer token only to the configured internal Shared Core API. Shared Core validates the token again and remains authoritative for platform identity, firms, applications, roles, permissions, validity windows, and overrides. Shared Core unavailability is a fail-closed `503`; Office never falls back to token claims or cached allows.

Firm selection is browser/session convenience only. Office API asks Shared Core for the user's accessible firms and revalidates explicit OFFICE access for every firm-scoped context or permission check. Firm groups and arbitrary `firmId` values grant nothing.

The Office permission guard is a two-stage foundation:

1. require the application-qualified Shared Core base permission;
2. require a future Office-owned resource/lifecycle policy before a real domain operation.

The current proof endpoint always reports `authorizationLevel=base` and `requiresDomainPolicy=true`. It does not query Office data. Upload ownership, document lifecycle, payroll/category scope, and client-safe redaction remain deferred.

Development CORS allows only the exact `OFFICE_WEB_ORIGIN` and does not use credentialed cross-origin requests. Normal browser traffic uses same-origin Office Web BFF routes, so the encrypted session cookie is never sent to Office API or Shared Core.
