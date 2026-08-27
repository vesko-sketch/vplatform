# V Office authorization foundation

Permissions are atomic business actions identified by `(application_id, code)`. Permission code alone is not a unique lookup key. Global roles may contain permissions from multiple applications, but roles and permissions never grant firm or application access by themselves.

The reviewed Office catalog contains 69 permissions. Its default role mappings contain 297 rows:

| Role           | Office permissions |
| -------------- | -----------------: |
| `admin`        |                 69 |
| `manager`      |                 68 |
| `accountant`   |                 54 |
| `payroll`      |                 47 |
| `client_owner` |                 33 |
| `client_staff` |                 17 |
| `upload_only`  |                  9 |

`manager` means an internal manager of the accounting firm, never a manager of a client company. Role mappings are default capability, not application access, firm access, or immutable limits.

The default application provisioning policy is:

| Role           | Office | Accounting | Payroll       | Invoices      | Schedules     |
| -------------- | ------ | ---------- | ------------- | ------------- | ------------- |
| `admin`        | yes    | yes        | yes           | yes           | yes           |
| `manager`      | yes    | yes        | yes           | yes           | yes           |
| `accountant`   | yes    | yes        | no by default | yes           | no by default |
| `payroll`      | yes    | no         | yes           | no by default | yes           |
| `client_owner` | yes    | no         | no by default | yes           | yes           |
| `client_staff` | yes    | no         | no by default | no by default | yes           |
| `upload_only`  | yes    | no         | no            | no            | no            |

This matrix does not create access assignments. Explicit valid `firm_applications` and `user_firm_applications` rows remain mandatory.

Shared Core will resolve base application/firm permissions. Office must separately enforce document ownership, lifecycle, functional scope, and safe/redacted views. In particular, `upload_only` document/archive permissions require future `OWN_UPLOADED_DOCUMENTS` policy; payroll operations require future functional scope; and client-owner processing/routing views require safe external projections. Base permission granted does not mean a final resource operation is allowed.

Firm groups grant no authorization. Resource scopes and document lifecycle authorization remain deferred. `routing.for_posting` is an Office routing action and never grants Accounting `journal.post`.

The complete reviewed permission and role mapping is encoded with deterministic UUIDs in the Office catalog migration. Permission display grouping is a UI concern and is not an authorization primitive.

## Read-only authorization resolution

Shared Core evaluates base authorization in this order: active platform user; exact active application; active firm; current active `firm_applications`; current active `user_firm_applications`; application-qualified active permission; current active role assignments and roles; active role-permission union; then current user overrides. Neither a role nor an override can bypass the firm/application gates.

Permission lookup always uses `(application, code)`. For example, `OFFICE + documents.view` and `ACCOUNTING + documents.view` are distinct capabilities. Code-only lookup is invalid.

All `DATE` validity fields use the inclusive rule `valid_from <= evaluatedDate <= valid_to`, with either null bound treated as open. The resolver derives `evaluatedDate` once from the supplied `evaluatedAt` instant using the platform business timezone `Europe/Sofia`. PostgreSQL `DATE` values are compared as calendar dates; the resolver does not mix UTC and local calendar dates or call the wall clock inside decision logic.

Multiple current active roles are unordered. Their active permissions for the requested application are unioned and deduplicated by permission UUID. Global overrides are applied to that base result first, then firm-specific overrides replace the global result. At one specificity, deny wins; duplicate active allows, duplicate active denies, an allow/deny conflict, or an unknown effect fails closed and is retained as internal diagnostic context.

An allowed Shared Core result has authorization level `base` and always requires application-domain policy before a resource operation. Shared Core does not claim to know Office document ownership, lifecycle, functional/category scope, or safe-field redaction. In particular:

- `upload_only` document and archive capabilities require future `OWN_UPLOADED_DOCUMENTS` enforcement in Office; document mutation also requires lifecycle enforcement.
- Payroll Office capabilities require future functional/category scope.
- Client-owner processing, routing, integration, and automation views require safe/redacted Office representations.
- Client-owner administration capability requires a second-stage policy that prevents internal-role assignment, cross-firm grants, and self-elevation.

The `manager` role always means an internal manager of the accounting firm. Firm groups remain organizational/reporting structures and are not read by the authorization resolver. Adding a firm to a group grants nothing.
