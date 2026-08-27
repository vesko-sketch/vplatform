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
