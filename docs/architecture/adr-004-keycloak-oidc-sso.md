# ADR-004: Keycloak OIDC and platform authorization

- Status: Accepted
- Date: 2026-08-26

## Context

V Platform needs central SSO across public and private applications without creating a custom password system.

## Decision

Keycloak is the selected OpenID Connect provider.

Keycloak owns authentication, passwords, MFA, login/session/SSO behavior, and token issuance. Shared Core owns the V Platform user UUID, firms, firm groups, application enablement, firm access, roles, permissions, and authorization truth.

Applications use five separate OIDC clients: `shared-core-api`, `office-web`, `office-api`, `accounting-web`, and `accounting-api`. Web clients use the authorization-code flow with PKCE. API clients are bearer-only audiences and cannot initiate browser login or use direct password grants. Accounting also requires the private network boundary; token validity alone does not grant network access.

The future identity link maps an immutable Keycloak issuer and subject pair (`iss`, `sub`) to exactly one `shared_core.users.id`. Email is mutable and must not be the durable identity key. Account linking, uniqueness, lifecycle, migration, and recovery behavior must be designed and migrated before implementation against the database.

Backend APIs validate tokens and then enforce current Shared Core application, firm, role, permission, and resource access. Client-supplied `firm_id` is never trusted without server-side authorization.

Phase 2B.1 validates Shared Core API bearer tokens against the exact trusted issuer, the `shared-core-api` audience, Keycloak's remote JWKS, token time claims, and the RS256 signing algorithm with a five-second default clock tolerance. Successful JWT validation establishes authentication only. No token role, username, email, or other claim becomes V Platform authorization.

The reproducible development realm is imported by Keycloak at container startup. It contains no development users, business roles, firm grants, application grants, or client secrets. Those authorization concepts remain in Shared Core.

## Consequences

- Phase 2A runs a development-only Keycloak service and validates OIDC configuration, but does not implement login or token verification.
- No password or token tables are added to Shared Core.
- The identity-link design must receive a reviewed Shared Core schema decision before user login is connected to live data.
