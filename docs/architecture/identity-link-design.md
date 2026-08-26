# Keycloak to Shared Core identity-link design

- Status: Design only; not implemented
- Date: 2026-08-26

## Purpose and ownership

Keycloak authenticates a human and issues tokens. Shared Core identifies that human inside V Platform and decides which firms, applications, roles, permissions, and resources they may access.

The durable external identity key is the tuple `(issuer, subject)`, where:

- `issuer` is the exact normalized OIDC `iss` value for the trusted Keycloak realm.
- `subject` is the opaque OIDC `sub` value issued for that realm identity.
- the tuple maps to one immutable `shared_core.users.id` platform UUID.

Email, username, display name, and token claims are mutable attributes. None may be used as the durable link key or as an automatic authorization grant.

## Proposed storage

A future Shared Core-owned identity-link entity should minimally contain:

- link UUID
- `user_id` referencing the authoritative Shared Core user
- normalized `issuer`
- opaque `subject`
- lifecycle status such as `active`, `disabled`, or `unlinked`
- first-linked and last-seen timestamps
- created/updated audit context
- local `row_version`
- optional provider metadata that contains no passwords, access tokens, or refresh tokens

The exact table and column names will be chosen only after approved Shared Core introspection. No schema change is authorized by this design.

## Uniqueness and invariants

- `(issuer, subject)` must be globally unique among live links.
- An external identity can map to only one platform user.
- A platform user may have multiple external identities.
- Issuer comparison must use a documented normalized form; an arbitrary token-supplied issuer is never trusted.
- A link change is security-sensitive and must be audited.
- Deleting or disabling a link must not delete the Shared Core user, firm memberships, or audit history.

The unconditional `(issuer, subject)` unique constraint permanently reserves disabled and unlinked historical tuples against accidental reassignment.

## First-login provisioning

Automatic first-login provisioning is not enabled by Phase 2A. The recommended default is invite/admin-led provisioning:

1. An authorized administrator creates or selects the Shared Core user and grants no implicit access beyond the approved invitation.
2. The platform issues a short-lived, single-use linking intent bound to that `user_id`, expected realm, and correlation/audit context.
3. After Keycloak authentication, the backend validates signature, issuer, audience, time claims, and the linking intent.
4. The backend creates the `(issuer, subject)` link transactionally after uniqueness checks.
5. Authentication succeeds only after current Shared Core application and firm access is evaluated.

Self-service creation from an unknown `sub` is denied unless a later policy explicitly approves it. A newly authenticated Keycloak account must never gain firms, roles, or application access merely because an email matches.

## Linking existing users

Existing users are linked through an authenticated administrative or invitation flow. Email may be displayed as evidence for a human reviewer, but it cannot perform the link automatically. The operation requires recent Keycloak authentication, a single-use intent, uniqueness checks, and an immutable audit record.

Conflict handling must fail closed. If `(issuer, subject)` is already linked, or the target user has a conflicting active link under a one-link policy, no reassignment occurs automatically.

## Unlink and recovery

Normal users should not be able to remove their only login method without a separately verified recovery method. Administrative unlinking requires a privileged permission, a reason, recent strong authentication, and audit context.

Recovery must use a controlled help-desk/admin process or a separately enrolled strong factor. Email possession by itself is insufficient. Re-linking should create a new lifecycle event rather than silently overwriting historical identity evidence.

Active sessions and refresh tokens should be revoked in Keycloak when an identity is compromised or intentionally unlinked. Shared Core must deny access immediately when its local link or user is disabled, even if a previously issued token remains cryptographically valid.

## Disabled or deleted Keycloak identities

- A disabled Keycloak user cannot obtain new tokens. Shared Core should retain the platform user and link for audit and possible controlled recovery.
- Existing tokens remain subject to their short lifetime and current Shared Core checks. High-risk operations may later require token introspection or a fresh-authentication policy.
- A deleted Keycloak identity does not delete the Shared Core user or authorization history.
- A recreated Keycloak user receives a new `sub` and is not automatically linked by matching email or username.
- A provider lifecycle event or periodic reconciliation may mark a link disabled, but Keycloak availability must not be required for every ordinary API request.

## Deferred decisions

- Invitation/linking-intent storage and expiry
- Required MFA/authentication context for linking and sensitive operations
- Keycloak user lifecycle event delivery versus periodic reconciliation
- Token revocation/introspection policy for high-risk operations
