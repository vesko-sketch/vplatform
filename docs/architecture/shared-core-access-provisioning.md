# Shared Core access provisioning

## Bootstrap authorization decision

The existing `applications.manage`, `access.manage`, and `roles.manage` permissions remain FIRM scoped. They are useful only after the normal firm/application/user gates succeed and cannot bootstrap a newly created firm. Reclassifying them would broaden existing client-facing semantics, while bypassing the firm resolver would weaken its fail-closed contract.

The reviewed proposal therefore adds six atomic OFFICE APPLICATION permissions:

- `firms.applications.enable`
- `firms.applications.disable`
- `firms.access.grant`
- `firms.access.revoke`
- `firms.roles.assign`
- `firms.roles.remove`

They are default capabilities of the global `admin` and `manager` roles only when those roles are explicitly assigned through `user_application_roles`. They do not grant firm access or any firm-domain permission. Existing FIRM permissions remain unchanged for later, constrained in-firm administration.

## Command ordering and state

Provisioning preserves four independent states:

1. firm master;
2. `firm_applications` application enablement;
3. `user_firm_applications` user access;
4. `user_firm_roles` role assignment.

Each table reserves its logical tuple with a unique constraint. Disable, revoke, and remove set `is_active=false`; a later enable, grant, or assign reactivates the same row and updates its validity window. Normal commands never physically delete these records.

Disabling a firm application is rejected with a conflict while any currently active user application access exists. User access must be revoked explicitly first. Firm roles are application-neutral and are not cascaded or deleted; without a current `user_firm_applications` row they cannot authorize that application.

## Role-target policy

Application `admin` may assign or remove any reviewed firm role. Application `manager` may assign or remove `manager`, `accountant`, `payroll`, `client_owner`, `client_staff`, and `upload_only`, but may not assign or remove `admin`. Client-side actors do not receive the new APPLICATION permissions. Future constrained client administration must use the existing FIRM-scoped permissions and may target only `client_owner`, `client_staff`, and `upload_only` within an already authorized firm.

## Transaction and audit

The Shared Core endpoint performs a preliminary read authorization check and repeats the APPLICATION permission decision inside the narrow access-writer transaction. The state mutation and its `audit_log` row commit together. Audit actions are:

- `firm_application.enabled` / `firm_application.disabled`
- `user_firm_application.granted` / `user_firm_application.revoked`
- `user_firm_role.assigned` / `user_firm_role.removed`

Audit payloads contain allowlisted identifiers, validity/state transitions, request/correlation IDs, and required reasons; they never contain tokens or credentials.

## Runtime boundaries and concurrency

`shared_core_api` remains the read-only authorization/query connection. Mutations use only
`shared_core_access_writer`; `shared_core_firm_writer` is not available to this module. Office API
delegates the validated bearer token over HTTP and has no Shared Core database credential.

Each write transaction takes a transaction-scoped PostgreSQL advisory lock derived from the unique
logical relationship key. This serializes insert/reactivation races without requiring table-wide
UPDATE privileges. Existing-row changes additionally use `row_version` in the UPDATE predicate and
return `ROW_VERSION_CONFLICT` for a stale expected version. Exact-state retries are successful and
do not create a second audit event.

## API

Commands:

- `POST /firms/:firmId/applications/:applicationCode/enable`
- `POST /firms/:firmId/applications/:applicationCode/disable`
- `POST /firms/:firmId/applications/:applicationCode/users/:userId/grant`
- `POST /firms/:firmId/applications/:applicationCode/users/:userId/revoke`
- `POST /firms/:firmId/users/:userId/roles/:roleCode/assign`
- `POST /firms/:firmId/users/:userId/roles/:roleCode/remove`

Read administration views use the corresponding APPLICATION permission and return allowlisted state only:

- `GET /firms/:firmId/applications`
- `GET /firms/:firmId/applications/:applicationCode/users`
- `GET /firms/:firmId/users/:userId/roles`

These routes are distinct from ordinary `/me` authorization context. Office API may proxy them with a validated user token; it receives no Shared Core database credential.

The corresponding Office API routes are under `/office/admin/firms/:firmId/...`; Office only
authenticates and delegates them. Shared Core performs both the preliminary authorization decision
and the repeated transaction-local APPLICATION-scope decision.
