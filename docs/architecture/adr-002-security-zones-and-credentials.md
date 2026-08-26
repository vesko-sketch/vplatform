# ADR-002: Security zones and database credential isolation

- Status: Accepted
- Date: 2026-08-26

## Context

Office may be internet-facing. Accounting and direct access to its PostgreSQL database must remain private. UI visibility is not an authorization control.

## Decision

The platform uses three logical network zones:

- `public-edge` for explicitly public ingress and public web/API endpoints.
- `platform-internal` for backend dependencies and internal communication.
- `accounting-private` for Accounting web/API and future Accounting workers, reachable only through a protected network or VPN.

Each backend receives only its owning database credential:

- `shared-core-api` may receive `SHARED_CORE_DATABASE_URL` only.
- `office-api` and the Office-owned `document-worker` may receive `OFFICE_DATABASE_URL` only.
- `accounting-api` may receive `ACCOUNTING_DATABASE_URL` only.
- Browser code and public Next.js applications receive no database URL.

The Accounting API remains private even when it validates a legitimate Keycloak token. Backend APIs enforce authenticated user, application access, firm access, permission, and resource scope.

## Consequences

- No universal database environment file will be injected into all deployables.
- Public services cannot query Accounting directly.
- Development network segmentation documents the intended topology; production also requires firewall, ingress, VPN, DNS, and secret-management enforcement.
