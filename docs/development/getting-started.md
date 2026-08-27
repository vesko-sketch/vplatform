# Development setup

## Prerequisites

- Node.js 24 or newer
- pnpm 11.24 or newer
- Docker with Docker Compose

Install workspace dependencies:

```bash
pnpm install
```

Copy `.env.example` to a local `.env` only when runtime configuration is needed. Change the development Keycloak administrator password before starting the stack. Never commit `.env` or real credentials. Phase 2A applications do not connect to PostgreSQL.

## Start supporting infrastructure

Start Keycloak, Redis, and MinIO:

```bash
pnpm infra:up
```

Keycloak listens on `http://127.0.0.1:8080` and imports the `vplatform` development realm on each fresh container start. Its realm discovery document is available at `http://localhost:8080/realms/vplatform/.well-known/openid-configuration`. Redis listens on `127.0.0.1:6379`. MinIO's S3 endpoint listens on `127.0.0.1:9000` and its development console on `127.0.0.1:9001`. The existing PostgreSQL server is not part of this Compose project.

The realm contains no users. Create disposable development identities through the Keycloak administration console when interactive testing is later approved. Never encode real users, passwords, firm access, roles, or permissions in the realm import.

See [the Keycloak smoke-test procedure](keycloak-smoke-test.md) to verify discovery, JWKS, PKCE login, and the authenticated Shared Core endpoint.

Stop the services without deleting their named volumes:

```bash
pnpm infra:down
```

## Disposable Shared Core database

The Shared Core baseline and proposed migrations are tested against a separate PostgreSQL 16.13 container using tmpfs-only storage and localhost port `55432`. It does not join the live PostgreSQL container's networks and contains no Office or Accounting database.

```bash
pnpm shared-core-db:up
pnpm shared-core-db:down
```

Stopping/removing this container destroys its data. Prisma commands must receive an explicit disposable URL such as:

```text
postgresql://vplatform_dev:local-disposable-only@127.0.0.1:55432/shared_core_migrate
```

Never substitute a live URL into `prisma db push` or `prisma migrate dev`; those commands are prohibited for the existing databases.

## Run and verify the workspace

Start all application development processes:

```bash
pnpm dev
```

Run the verification pipeline:

```bash
pnpm lint
pnpm typecheck
pnpm test
pnpm build
```

The Nest APIs validate their required issuer, client ID, and audience configuration before starting. They publish health routes at `/health` and generated OpenAPI documentation at `/openapi`. The Next.js applications expose `/api/health`. `shared-core-api` validates Keycloak access tokens and resolves exact platform identity and authorization context. Office Web keeps OIDC tokens in an encrypted HttpOnly server session; Office API validates the token independently and delegates firm/permission decisions to Shared Core.

For the authenticated Office shell, provide only these variables to Office Web: `OFFICE_OIDC_ISSUER_URL`, `OFFICE_OIDC_CLIENT_ID`, `OFFICE_WEB_BASE_URL`, `OFFICE_WEB_SESSION_SECRET`, and `OFFICE_API_URL`. Provide `OIDC_ISSUER_URL`, `OIDC_OFFICE_API_CLIENT_ID`, `OIDC_OFFICE_API_AUDIENCE`, `OIDC_OFFICE_API_SIGNING_ALGORITHM`, `OIDC_CLOCK_TOLERANCE_SECONDS`, `OFFICE_WEB_ORIGIN`, and `SHARED_CORE_API_URL` to Office API. Office services receive neither `SHARED_CORE_DATABASE_URL` nor `ACCOUNTING_DATABASE_URL`.

## Application responsibilities

- `shared-core-api`: shared identity metadata and platform authorization master; no authentication passwords.
- `office-api`: public Office workflows and document domain API.
- `office-web`: public Office portal foundation.
- `accounting-api`: private Accounting domain API.
- `accounting-web`: private Accounting UI foundation.
- `document-worker`: Office-owned asynchronous processing boundary; no queue or database behavior exists in Phase 1.

## Security boundaries

Office may be exposed through public ingress. Accounting web/API must remain behind a VPN or equivalent protected network. Public applications never receive `ACCOUNTING_DATABASE_URL`, and frontend bundles never receive any database URL.

The root `.env.example` is a variable catalog, not an instruction to inject every value into every process. Deployment definitions must provide each backend only its allowed database variable.

`shared-core-api` uses `SHARED_CORE_DATABASE_URL` with the non-owner `shared_core_api` runtime role. `SHARED_CORE_MIGRATION_DATABASE_URL` is an operator-only owner credential and must not be present in the normal API process environment.

The Accounting OIDC clients do not weaken the private boundary. `accounting-web` and `accounting-api` must be attached only to the protected Accounting network when application containers are added. A token carrying the `accounting-api` audience is necessary for future API access but is never sufficient to cross the VPN, firewall, or private ingress boundary.
