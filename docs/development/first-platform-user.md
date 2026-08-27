# First development platform user

This procedure creates the minimum non-production identity and authorization fixture needed for an end-to-end Shared Core smoke test. It is explicit, fail-closed, and never runs during application startup.

It creates only:

- Keycloak user `vplatform-dev-admin`
- Shared Core user `dev-admin@vplatform.invalid`
- firm `DEV` (`V Platform Development Firm`)
- one active Keycloak identity link
- one OFFICE firm enablement
- one OFFICE user access grant
- one `admin` role assignment for the development firm

It creates no Accounting access, overrides, resource scopes, or firm-group access.

## Prerequisites and backup

Run the read-only preflight in the bootstrap SQL against `shared_core` before approving execution. Before any Shared Core write, create a timestamped custom-format backup under `/home/vbot/vplatform-backups/shared-core`, verify it with `pg_restore --list`, and record its SHA-256. Never use the API runtime credential for this operation.

## Create the Keycloak development user

Supply credentials interactively or through uncommitted shell environment variables. Never place either password in this repository or shell history.

```bash
read -rsp 'Keycloak admin password: ' KEYCLOAK_ADMIN_PASSWORD
printf '\n'
read -rsp 'Development user password: ' KEYCLOAK_DEV_PASSWORD
printf '\n'
export KEYCLOAK_ADMIN_PASSWORD KEYCLOAK_DEV_PASSWORD
```

Use Keycloak administration tooling to create the enabled `vplatform-dev-admin` user in realm `vplatform`, then set its development password. Query the resulting user by exact username and retain its opaque `id` as the OIDC subject. Do not assign Keycloak roles or encode V Platform authorization in Keycloak.

## Create or verify the Shared Core fixture

Execute the development-only script explicitly using the owner/admin database credential and the exact opaque Keycloak subject:

```bash
psql "$SHARED_CORE_MIGRATION_DATABASE_URL" \
  -X -v ON_ERROR_STOP=1 \
  -v keycloak_subject="$KEYCLOAK_SUBJECT" \
  -f scripts/dev/bootstrap-first-platform-user.sql
```

The script uses fixed development UUIDs, validates OFFICE/admin/reference identities, refuses conflicting keys, and commits all fixture rows atomically. A repeat execution reuses an exactly matching active fixture and inserts nothing.

## S256 PKCE smoke test

Use the `office-web` authorization-code client. Generate a verifier and challenge without writing them to the repository:

```bash
VERIFIER=$(openssl rand -base64 48 | tr -d '=+/\n' | cut -c1-64)
CHALLENGE=$(printf %s "$VERIFIER" | openssl dgst -binary -sha256 \
  | openssl base64 -A | tr '+/' '-_' | tr -d '=')
```

Open the authorization URL described in [keycloak-smoke-test.md](keycloak-smoke-test.md), authenticate as `vplatform-dev-admin`, exchange the returned code with the same verifier, and keep the access token only in an ephemeral shell variable. Verify `alg=RS256`, the exact issuer, the opaque subject, and the `shared-core-api` audience before calling the API.

Expected context:

- `/auth/me` resolves the fixed development platform-user and identity-link UUIDs.
- `/me/applications` contains only `OFFICE`.
- `/me/firms` contains only `DEV`.
- the OFFICE permission context contains 69 base permissions.
- `OFFICE + documents.view` is allowed at base level and requires domain policy.
- ACCOUNTING context is empty and `ACCOUNTING + documents.view` is denied.

Email, preferred username, and Keycloak roles are display/token data only and never establish V Platform authorization.

## Retirement/cleanup

First disable or delete the disposable Keycloak user through Keycloak administration. Then review and explicitly execute:

```bash
psql "$SHARED_CORE_MIGRATION_DATABASE_URL" \
  -X -v ON_ERROR_STOP=1 \
  -f scripts/dev/cleanup-first-platform-user.sql
```

The cleanup script verifies fixture markers, disables the explicit grants, firm, and platform user, and marks the external identity `unlinked`. It deliberately retains the platform user and external identity history for auditability. It is never automatic.
