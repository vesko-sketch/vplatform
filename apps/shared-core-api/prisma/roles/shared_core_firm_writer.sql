\set ON_ERROR_STOP on

-- REVIEW ONLY in Phase 3A.2. A live phase must first verify that this role is absent.
-- Supply the LOGIN password through approved secret management; never append it here.
CREATE ROLE shared_core_firm_writer
    LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;

GRANT CONNECT ON DATABASE shared_core TO shared_core_firm_writer;
GRANT USAGE ON SCHEMA public TO shared_core_firm_writer;

GRANT SELECT (id, is_active) ON public.users TO shared_core_firm_writer;
GRANT SELECT (id, code, is_active) ON public.applications TO shared_core_firm_writer;
GRANT SELECT (
    id, code, name, short_name, legal_form_id, country_id,
    registration_number, base_currency_id, default_language_id,
    timezone, is_active, row_version, created_at, updated_at
) ON public.firms TO shared_core_firm_writer;
GRANT SELECT (firm_id, application_id, is_active, valid_from, valid_to)
    ON public.firm_applications TO shared_core_firm_writer;
GRANT SELECT (user_id, firm_id, application_id, is_active, valid_from, valid_to)
    ON public.user_firm_applications TO shared_core_firm_writer;
GRANT SELECT (id, user_id, firm_id, role_id, is_active, valid_from, valid_to)
    ON public.user_firm_roles TO shared_core_firm_writer;
GRANT SELECT (id, user_id, application_id, role_id, is_active, valid_from, valid_to)
    ON public.user_application_roles TO shared_core_firm_writer;
GRANT SELECT (id, code, is_active) ON public.roles TO shared_core_firm_writer;
GRANT SELECT (role_id, permission_id, is_active)
    ON public.role_permissions TO shared_core_firm_writer;
GRANT SELECT (id, application_id, code, is_active, scope_type)
    ON public.permissions TO shared_core_firm_writer;
GRANT SELECT (id, user_id, firm_id, permission_id, effect, valid_from, valid_to)
    ON public.user_permission_overrides TO shared_core_firm_writer;

GRANT SELECT (id, is_active) ON public.ref_countries TO shared_core_firm_writer;
GRANT SELECT (id, is_active) ON public.ref_currencies TO shared_core_firm_writer;
GRANT SELECT (id, is_active) ON public.ref_languages TO shared_core_firm_writer;
GRANT SELECT (id, is_active) ON public.ref_legal_forms TO shared_core_firm_writer;

GRANT INSERT (
    id, code, name, short_name, legal_form_id, country_id,
    registration_number, base_currency_id, default_language_id, timezone
) ON public.firms TO shared_core_firm_writer;
GRANT UPDATE (
    code, name, short_name, legal_form_id, country_id,
    registration_number, base_currency_id, default_language_id,
    timezone, is_active
) ON public.firms TO shared_core_firm_writer;
GRANT INSERT (
    firm_id, user_id, entity_type, entity_id, action, old_values,
    new_values, reason, source_type, request_id, correlation_id
) ON public.audit_log TO shared_core_firm_writer;

REVOKE CREATE ON SCHEMA public FROM shared_core_firm_writer;
