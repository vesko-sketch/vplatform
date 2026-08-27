# Application-scoped authorization

Status: Phase 3A.2 review and disposable verification. Nothing in this document authorizes live migration, grants, assignments, or firm writes.

## Scope model

Shared Core authorization has complementary scopes:

- `APPLICATION`: authority within an application without a target firm;
- `FIRM`: authority after explicit active/current firm and user application gates;
- resource/domain policy: deferred to the owning application and never implied by either base scope.

Permission scope is stored explicitly in `permissions.scope_type`; code prefixes are never interpreted. The database permits only `APPLICATION` and `FIRM`. A future resource model requires a reviewed migration rather than activating a speculative enum value.

`user_application_roles` assigns one existing global role to a user for one application, with active state and inclusive Europe/Sofia business-date validity. It grants no firm access and creates no `user_firm_roles`. Application roles and firm roles are resolved independently.

## Reviewed existing permission classification

All 23 Accounting permissions are `FIRM` scope. Sixty-seven existing Office permissions are `FIRM` scope. `system.settings.view` and `system.settings.manage` are `APPLICATION` scope because platform-wide Office configuration has no coherent target firm.

The administration codes requiring explicit interpretation remain `FIRM`:

- `roles.view/manage`: view/manage role assignments in an authorized firm; they do not mutate the global role catalog;
- `permissions.view/manage`: view/manage firm assignments and overrides; they do not create software-controlled permission codes;
- `applications.view/manage`: view/manage application enablement/access for an authorized firm; they do not mutate the global application catalog.

This preserves the least-authority meaning already established for firm administration. Any future global catalog editor requires new APPLICATION-scoped permissions rather than reinterpreting these codes.

Five new Office permissions are added. `firms.create`, `firms.catalog.view`, and `firms.activate` are APPLICATION scoped; `firms.disable` and `firms.identity.edit` are FIRM scoped. Reactivation is application administration because an inactive firm cannot pass the normal firm gate. It does not grant ordinary access to the reactivated firm.

## Resolution

`canAtApplicationScope(user, application, permission, evaluatedAt)` requires an active user, active exact application, application-qualified active permission with `scope_type=APPLICATION`, a current active `user_application_roles` row, an active global role, and an active matching `role_permissions` row. It does not read firm access, firm roles, firm groups, or overrides.

Firm resolution retains all existing gates and additionally requires `scope_type=FIRM`. Each resolver rejects the other scope with `permission_wrong_scope`. An application admin therefore cannot read arbitrary firm documents, while a firm admin cannot create firms.

Current `user_permission_overrides` cannot safely serve application scope. A null `firm_id` currently means a global override applied only after a firm/application gate; reusing it would change established semantics. Application overrides are deferred and application decisions are role-derived only.

## Firm administration reads and writes

`GET /firms` requires APPLICATION `OFFICE + firms.catalog.view`. Catalog visibility is sufficient for the safe catalog projection and `GET /firms/:id` master profile because requiring `firms.view` would make catalog administration unusable before firm access exists. Responses remain allowlisted and exclude metadata/internals. Ordinary `/me/firms` and application business access remain unchanged.

Creation requires APPLICATION `firms.create`. It creates only the firm master. OFFICE enablement, creator access, and role assignments remain explicit later commands.

Existing-firm commands retain the approved field split:

- profile (`firms.edit`): name, short name, default language, timezone;
- identity (`firms.identity.edit`): code, legal form, country, registration number;
- settings (`firms.settings.edit`): base currency;
- activate (`firms.activate`) and deactivate (`firms.disable`): active state only.

All updates require `expectedRowVersion`; state changes require audit context and deactivation requires a reason. Physical delete is unavailable.

## Authorization/write transaction

For the security-sensitive command path, use approach B: repeat the narrow required authorization check inside the writer transaction using the same shared resolver query components. Approach A (read-only decision followed by a separate writer transaction) leaves a window where access can be revoked after authorization but before mutation. B requires more SELECT columns on the writer role but no additional write power and closes that TOCTOU window.

The resolver algorithm must not be independently copied. Repositories should accept a transaction-scoped database adapter so the same evaluated-date and scope logic runs through the writer transaction. Mutation and immutable `audit_log` INSERT then commit together; audit failure rolls back the mutation.

The read-only reference endpoints require future `shared_core_api` SELECT on only:

- `ref_countries(id, iso2_code, name_bg, name_en, is_active)`;
- `ref_currencies(id, iso_code, name, decimal_places, is_active)`;
- `ref_languages(id, iso_code, name_bg, name_en, is_active)`;
- `ref_legal_forms(id, code, short_name, full_name, is_active)`.

Those live grants are not part of Phase 3A.2.
