# Development setup

## Prerequisites

- Node.js 24 or newer
- pnpm 11.24 or newer
- Docker with Docker Compose

Install workspace dependencies:

```bash
pnpm install
```

Copy `.env.example` to a local `.env` only when runtime configuration is needed. Never commit `.env` or real credentials. Phase 1 applications do not connect to PostgreSQL.

## Start supporting infrastructure

Start Redis and MinIO:

```bash
pnpm infra:up
```

Redis listens on `127.0.0.1:6379`. MinIO's S3 endpoint listens on `127.0.0.1:9000` and its development console on `127.0.0.1:9001`. The existing PostgreSQL server is not part of this Compose project.

Stop the services without deleting their named volumes:

```bash
pnpm infra:down
```

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

The Nest APIs publish health routes at `/health` and generated OpenAPI documentation at `/openapi`. The Next.js applications expose `/api/health`.

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
