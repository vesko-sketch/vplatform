# V Platform

V Platform is a pnpm monorepo for shared identity and access, public Office workflows, and private Accounting workflows.

Phase 1 contains application foundations only. It does not connect to PostgreSQL, implement domain features, or synchronize the legacy duplicated tables remaining in the historical Accounting database.

See [the development guide](docs/development/getting-started.md) and [architecture decisions](docs/architecture/).

## Development quick start

```bash
pnpm infra:up
pnpm dev:apps
```

Open V Office at [http://localhost:3100](http://localhost:3100) and sign in through the
development Keycloak realm. The application stack uses fixed ports: Office Web `3100`, Office
API `3101`, Shared Core API `3102`, and Keycloak `8080`.
