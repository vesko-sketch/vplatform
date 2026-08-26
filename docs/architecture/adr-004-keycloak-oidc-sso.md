# ADR-004: Keycloak OIDC and platform authorization

- Status: Accepted
- Date: 2026-08-26

## Context

V Platform needs central SSO across public and private applications without creating a custom password system.

## Decision

Keycloak is the selected OpenID Connect provider.

Keycloak owns authentication, passwords, MFA, login/session/SSO behavior, and token issuance. Shared Core owns the V Platform user UUID, firms, firm groups, application enablement, firm access, roles, permissions, and authorization truth.

Applications use separate OIDC clients and audiences for Shared Core, Office, and Accounting. Accounting also requires the private network boundary; token validity alone does not grant network access.

The future identity link maps an immutable Keycloak issuer and subject pair (`iss`, `sub`) to exactly one `shared_core.users.id`. Email is mutable and must not be the durable identity key. Account linking, uniqueness, lifecycle, migration, and recovery behavior must be designed and migrated before implementation against the database.

Backend APIs validate tokens and then enforce current Shared Core application, firm, role, permission, and resource access. Client-supplied `firm_id` is never trusted without server-side authorization.

## Consequences

- Phase 1 records configuration placeholders but does not run Keycloak or implement login.
- No password or token tables are added to Shared Core.
- A Phase 2 identity-link ADR and reviewed schema decision are required before user login is connected to live data.
