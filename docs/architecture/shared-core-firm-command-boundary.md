# Shared Core firm command boundary

Status: Phase 3A.1 design; no live role, grant, schema, permission, or firm change is authorized.

## Decision boundary

`shared_core.firms` remains the single firm master. Firm commands follow `office-web -> office-api -> shared-core-api -> Shared Core command layer -> shared_core`. Office services never receive a Shared Core database credential. The existing `shared_core_api` credential remains read-only.

The existing schema can safely support firm-scoped profile updates, optimistic concurrency, soft activation state, and transactional audit without alteration. It cannot unambiguously authorize creating a firm or enumerating the complete administration catalog: all current application access and role assignments are firm-scoped, while a firm being created has no access gate. Phase 3A.2 must not expose `POST /firms` or an unrestricted `GET /firms` until a reviewed platform/operator administration scope exists.

## Permission policy requiring approval

Use atomic permissions rather than stretching `firms.edit`:

- keep `firms.view` for an already-authorized firm's ordinary profile;
- keep `firms.edit` for `name`, `short_name`, `default_language_id`, and `timezone` on an already-authorized firm;
- use `firms.settings.edit` for `base_currency_id`, subject to domain validation before Accounting initialization;
- add `firms.identity.edit` for `code`, `legal_form_id`, `country_id`, and `registration_number`;
- add `firms.create`, `firms.activate`, and `firms.disable` for their distinct commands.

Recommended defaults are `admin + manager` for `firms.create`, `firms.activate`, and `firms.identity.edit`; `firms.disable` defaults to `admin` only because it removes access platform-wide. These defaults are not ceilings. `accountant` should not create firms by default. `client_owner` and `client_staff` retain ordinary edits only for firms to which they have a current OFFICE grant. No command infers authority from Keycloak claims or role names in the request.

This permission recommendation requires a catalog migration and role-mapping review. It is not implemented by Phase 3A.1.

## Commands

Commands use explicit DTOs and reject unknown properties:

- `CreateFirm { id?, code, name, shortName?, legalFormId?, countryId, registrationNumber?, baseCurrencyId, defaultLanguageId?, timezone }`
- `UpdateFirmProfile { expectedRowVersion, name?, shortName?, defaultLanguageId?, timezone? }`
- `UpdateFirmIdentity { expectedRowVersion, code?, legalFormId?, countryId?, registrationNumber? }`
- `UpdateFirmSettings { expectedRowVersion, baseCurrencyId? }`
- `ActivateFirm { expectedRowVersion, reason }` uses application-scoped `firms.activate`; it may target an inactive catalog firm without granting firm-domain access.
- `DeactivateFirm { expectedRowVersion, reason }`

Create defaults to active but creates no `firm_applications`, user access, role assignment, override, or scope. OFFICE enablement is a separate, explicitly authorized command. A future guided UI may execute both reviewed commands, but a failed second command must remain visible and retryable rather than being hidden as implicit provisioning.

There is no application-level physical-delete command. Database DELETE is not granted to the writer.

## Concurrency and audit transaction

All updates use `UPDATE ... WHERE id = $id AND row_version = $expectedRowVersion`. The existing trigger increments `row_version` and `updated_at`. Zero affected rows is re-read safely to distinguish not-found from stale state; callers receive HTTP 404 or HTTP 409 `ROW_VERSION_CONFLICT` without overwriting data.

Authorization is re-evaluated inside the command transaction using the supplied actor UUID, exact `OFFICE + permission code`, firm UUID, active flags, and validity date. Browser identity/role headers are ignored. Create/list-all remain blocked because they lack an approved target-firm gate.

The firm mutation and one `audit_log` insert share one writer transaction. Audit uses:

- `firm_id` and `entity_id`: firm UUID;
- `user_id`: resolved platform actor UUID;
- `entity_type`: `firm`;
- `action`: explicit command name such as `firm.profile.updated`;
- `old_values` and `new_values`: allowlisted command fields only;
- `reason`: mandatory for activation-state changes;
- `source_type`: `shared-core-api`;
- request and correlation UUIDs from trusted request context.

Audit never contains tokens, credentials, arbitrary metadata, or secrets. Audit failure aborts the transaction. The table's lack of actor/entity foreign keys preserves history after lifecycle changes and needs no schema amendment.

## Proposed runtime credential

Use `shared_core_firm_writer`, supplied only to the Shared Core command module as `SHARED_CORE_FIRM_WRITER_DATABASE_URL`. Migration/owner credentials remain separate. The role is `NOLOGIN` in reviewed grant SQL until a separately managed LOGIN principal is approved, or can itself be a managed LOGIN role with an out-of-repository secret. It must be NOSUPERUSER, NOCREATEDB, NOCREATEROLE, NOBYPASSRLS, own nothing, and have no schema CREATE.

The transaction must re-check authorization, so the writer needs the same narrow authorization SELECT columns as the read resolver. Additional SELECT is limited to firm command fields and active reference IDs. Proposed grants:

```sql
GRANT CONNECT ON DATABASE shared_core TO shared_core_firm_writer;
GRANT USAGE ON SCHEMA public TO shared_core_firm_writer;

GRANT SELECT (id, is_active) ON public.users TO shared_core_firm_writer;
GRANT SELECT (id, code, is_active) ON public.applications TO shared_core_firm_writer;
GRANT SELECT (id, code, name, short_name, legal_form_id, country_id,
              registration_number, base_currency_id, default_language_id,
              timezone, is_active, row_version, created_at, updated_at)
  ON public.firms TO shared_core_firm_writer;
GRANT SELECT (firm_id, application_id, is_active, valid_from, valid_to)
  ON public.firm_applications TO shared_core_firm_writer;
GRANT SELECT (user_id, firm_id, application_id, is_active, valid_from, valid_to)
  ON public.user_firm_applications TO shared_core_firm_writer;
GRANT SELECT (id, user_id, firm_id, role_id, is_active, valid_from, valid_to)
  ON public.user_firm_roles TO shared_core_firm_writer;
GRANT SELECT (id, code, is_active) ON public.roles TO shared_core_firm_writer;
GRANT SELECT (role_id, permission_id, is_active)
  ON public.role_permissions TO shared_core_firm_writer;
GRANT SELECT (id, application_id, code, is_active, scope_type)
  ON public.permissions TO shared_core_firm_writer;
GRANT SELECT (id, user_id, application_id, role_id, is_active, valid_from, valid_to)
  ON public.user_application_roles TO shared_core_firm_writer;
GRANT SELECT (id, user_id, firm_id, permission_id, effect, valid_from, valid_to)
  ON public.user_permission_overrides TO shared_core_firm_writer;

GRANT SELECT (id, is_active) ON public.ref_countries TO shared_core_firm_writer;
GRANT SELECT (id, is_active) ON public.ref_currencies TO shared_core_firm_writer;
GRANT SELECT (id, is_active) ON public.ref_languages TO shared_core_firm_writer;
GRANT SELECT (id, is_active) ON public.ref_legal_forms TO shared_core_firm_writer;

GRANT INSERT (id, code, name, short_name, legal_form_id, country_id,
              registration_number, base_currency_id, default_language_id, timezone)
  ON public.firms TO shared_core_firm_writer;
GRANT UPDATE (code, name, short_name, legal_form_id, country_id,
              registration_number, base_currency_id, default_language_id,
              timezone, is_active)
  ON public.firms TO shared_core_firm_writer;
GRANT INSERT (firm_id, user_id, entity_type, entity_id, action, old_values,
              new_values, reason, source_type, request_id, correlation_id)
  ON public.audit_log TO shared_core_firm_writer;
```

No INSERT/UPDATE is granted on authorization tables or references. No DELETE, TRUNCATE, REFERENCES, TRIGGER, schema CREATE, outbox write, or unrelated table access is granted. Raw/parameterized audit INSERT avoids requiring audit SELECT merely for ORM `RETURNING` behavior.

## Read APIs and UX

`GET /me/firms` remains the user's accessible-firm selector. The administration catalog is separately guarded by application-scoped `firms.catalog.view`. Profile, identity, settings, and deactivation commands retain normal OFFICE firm access gates. `POST /firms/:firmId/activate` is the deliberate exception: it uses application-scoped `firms.activate` because the target is inactive, while still granting no ordinary access to that firm. Every existing-firm mutation requires `expectedRowVersion`.

Application-scoped `firms.catalog.view` guards `GET /firms` and `GET /firms/:id`; application-scoped `firms.create` guards `POST /firms`. These operations never derive catalog authority from access to one client firm and never provision firm/application/user access implicitly.

The Office Web flow keeps the ordinary firm selector separate from an Administration area: authorized catalog -> create wizard -> firm profile -> explicit edit -> explicit status action. Reference dropdowns call read-only Shared Core endpoints for active legal forms, countries, currencies, and languages; Office does not copy these catalogs. Creation, OFFICE enablement, and access assignment are visibly separate steps.

## Existing identity and reference constraints

Only `firms.code` is unique. `registration_number` is nullable and has no unique constraint or country-aware rule. Application validation may normalize and warn about a same-country duplicate, but must not reject or introduce uniqueness until business rules for foreign registrations, branches, and BULSTAT individuals are approved.

Reference rows must exist and be active at command time. Legal form and language are optional; country and base currency are required. The existing Bulgarian catalog includes AD, BRANCH, BULSTAT_INDIVIDUAL, DPK, DZZD, EAD, EOOD, ET, INDIVIDUAL, KD, KDA, NPO, OOD, and SD; no seed is required for the reviewed MVP set.

## Phase 3A.2 gate

Before implementation, approve:

1. the four new atomic permissions and their default mappings;
2. a model for platform/operator administration that can authorize create and catalog-wide list without a target firm;
3. the field-to-permission policy above;
4. explicit OFFICE enablement rather than automatic enablement;
5. the exact `shared_core_firm_writer` DDL/grants.

After approval, prepare the permission/scope migration and writer-role SQL, test the full command repository in disposable PostgreSQL, then use a separate live-execution gate before creating the role or applying a permission migration.
