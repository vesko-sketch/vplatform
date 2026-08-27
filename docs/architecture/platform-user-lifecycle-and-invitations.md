# Platform user lifecycle and invitations (Phase 3A.6 review)

Status: database foundation live; Phase 3A.6B command implementation in development.

## Boundaries and lifecycle

Keycloak authenticates; Shared Core owns the platform user and durable `(normalized issuer, opaque
subject)` link. Email and username are evidence, never identity keys. Invitation, identity linking,
application access, firm access, and firm roles remain separate commands.

`users.lifecycle_status` explicitly distinguishes `INVITED`, `ACTIVE`, and `DISABLED`.
`users.is_active` remains the resolver's fast gate and is constrained to true exactly for `ACTIVE`.
Existing active/inactive users migrate to `ACTIVE`/`DISABLED`. Relationships are retained unchanged
when a user is disabled and become ineffective through the existing active-user gate.

## Invitation and redemption

One `user_invitations` row is both the delivery invitation and the single-use identity-linking
intent. A separate linking-intent table would duplicate target, expiry, cancellation, and
consumption state; recovery/relinking is a distinct future high-risk model.

Invitation creation atomically creates an `INVITED`/inactive user, a 48-hour `PENDING` invitation,
and audit events. It creates no access or role rows. The raw 256-bit random URL token is returned
once only when both the runtime is non-production and
`INVITATION_DEVELOPMENT_RESPONSE_ENABLED=true`; only its SHA-256 digest is stored. No invitation
outbox event is emitted until a secure delivery-envelope design is separately approved.

Redemption requires a valid token and a completed Keycloak Authorization Code + PKCE flow. Shared
Core rechecks the invitation, expiry, cancellation, row version, target user, verified normalized
OIDC email, and `(issuer, subject)` conflict inside one writer transaction. It inserts the external
identity with invitation provenance, consumes the invitation, and activates the exact target user.
Concurrent/replayed redemption permits exactly one success. Public failures collapse to a safe
`INVITATION_INVALID` where detail would disclose account state.

Email normalization is trim plus lowercase only; provider-specific dot or plus rewriting is
forbidden. Redemption requires `email_verified=true` and exact normalized equality. A mismatch
fails closed and remains unconsumed. Any existing user at the same normalized email or an existing
subject linked to another user requires manual review; neither is merged or reassigned.

## Identity history and recovery

`user_external_identities(issuer, subject)` remains permanently unique regardless of `active`,
`disabled`, or `unlinked` status. One user may have at most one active identity for a given issuer;
future approved issuers may add other identities. The reviewed migration should add a partial unique
index on `(user_id, issuer) WHERE status='active'` before redemption is implemented.

Disabling a user changes only `users.lifecycle_status/is_active` and writes audit. Reactivation is a
separate admin-only operation; it does not create or relink identity. An active existing identity
becomes usable again. Unlinked/recreated identities require future recovery with admin authority,
reason, recent strong authentication/MFA, a new short-lived intent, conflict checks, and audit.

## Application permissions

Existing `users.view/create/edit/disable` remain FIRM scoped and are not bootstrap authority. The
reviewed OFFICE APPLICATION permissions are:

- `users.catalog.view`
- `users.invite`
- `users.platform.disable`
- `users.platform.reactivate`
- `users.invitations.view`
- `users.invitations.cancel`

Application admin receives all six. Application manager receives catalog, invite, invitation view,
and cancellation. Disable/reactivate remain admin-only. No other default role receives them.
`users.invite` also authorizes replacement issuance: the old pending row is cancelled and a new
token/row is created atomically. A separate resend permission is unnecessary because tokens are
never reused.

## Read and command models

The application catalog exposes only `id`, `displayName`, `email`, `lifecycleStatus`, `isActive`,
`identityLinked`, current invitation state/expiry, `rowVersion`, `createdAt`, and `updatedAt`.
Subjects, issuers, token digests, metadata, credentials, and Keycloak internals are excluded.

Proposed commands are `POST /users/invitations`, `POST /users/invitations/:id/cancel`,
`POST /users/:id/disable`, and `POST /users/:id/reactivate`. Proposed reads are `GET /users`,
`GET /users/:id`, and `GET /users/invitations`. Redemption is a narrowly public route bound to an
authenticated OIDC callback, not an authorization-free user endpoint.

All lifecycle/cancellation commands use `expectedRowVersion`. Relationship-level advisory locks
serialize invitation issue/redemption keys; update predicates still enforce optimistic concurrency.

## Keycloak and delivery

Self-registration remains disabled. Initial development can require separately administered
Keycloak accounts. The production recommendation is a dedicated internal identity-administration
adapter/service with isolated Keycloak Admin API credentials and a narrow account-creation policy;
Shared Core and Office API must not receive those credentials.

Core writes, audit, and outbox insertion are atomic. Email delivery is asynchronous and idempotent.
The existing outbox is suitable for invitation ID, user ID, destination evidence, expiry,
correlation ID, and an encrypted delivery envelope. It must never contain the raw token, issuer/sub,
password, or bearer token.

## Audit and errors

Allowlisted actions: `user.created_pending`, `user.invitation.created`,
`user.invitation.cancelled`, `user.invitation.consumed`, `user.activated`, `user.disabled`,
`user.reactivated`, and `user.identity.linked`. Conflict attempts use a security audit action with
opaque invitation/user IDs rather than a broad subject value.

Internal deterministic errors include `INVITATION_INVALID`, `INVITATION_EXPIRED`,
`INVITATION_CANCELLED`, `INVITATION_ALREADY_CONSUMED`, `INVITATION_IDENTITY_MISMATCH`,
`EXTERNAL_IDENTITY_CONFLICT`, `USER_EMAIL_REVIEW_REQUIRED`, `USER_DISABLED`, and
`ROW_VERSION_CONFLICT`.

## Threat controls

- Theft/forwarding: short expiry, high entropy, verified-email binding, and mandatory Keycloak login.
- Replay/expiry/cancellation/concurrency: atomic status predicate plus row version and advisory lock.
- Wrong account/same-email confusion: verified exact normalized email plus subject uniqueness; no merge.
- Recreated subject: historical tuple reservation; no email relink.
- Administrator abuse: atomic permissions, admin-only lifecycle recovery, reason, MFA boundary, audit.
- Privilege leakage: invitation creates no application/firm/role/override row.
- Database/audit leakage: digest only; no raw token or subject in broad projections/audit.

## Writer isolation

`shared_core_user_writer` is separate from both existing writers. It receives narrow authorization
reads; allowlisted user lifecycle writes; invitation lifecycle writes; identity-link INSERT only;
and audit/outbox INSERT. It receives no DELETE/TRUNCATE, schema CREATE, access-assignment writes,
permission/role writes, reference writes, identity reassignment/update, Office DB, or Accounting DB.
