\set ON_ERROR_STOP on

-- REVIEW ONLY in Phase 3A.5. Do not apply live without a separately approved execution phase.
-- Supply the LOGIN password through approved secret management; never append it here.
CREATE ROLE shared_core_access_writer
    LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;

GRANT CONNECT ON DATABASE shared_core TO shared_core_access_writer;
GRANT USAGE ON SCHEMA public TO shared_core_access_writer;

GRANT SELECT (id, is_active) ON public.users TO shared_core_access_writer;
GRANT SELECT (id, code, is_active) ON public.applications TO shared_core_access_writer;
GRANT SELECT (id, is_active) ON public.firms TO shared_core_access_writer;
GRANT SELECT (id, user_id, application_id, role_id, is_active, valid_from, valid_to)
    ON public.user_application_roles TO shared_core_access_writer;
GRANT SELECT (id, code, is_active) ON public.roles TO shared_core_access_writer;
GRANT SELECT (role_id, permission_id, is_active)
    ON public.role_permissions TO shared_core_access_writer;
GRANT SELECT (id, application_id, code, is_active, scope_type)
    ON public.permissions TO shared_core_access_writer;

GRANT SELECT (id, firm_id, application_id, valid_from, valid_to, is_active, row_version)
    ON public.firm_applications TO shared_core_access_writer;
GRANT SELECT (id, user_id, firm_id, application_id, valid_from, valid_to, is_active, row_version)
    ON public.user_firm_applications TO shared_core_access_writer;
GRANT SELECT (id, user_id, firm_id, role_id, valid_from, valid_to, is_active, row_version)
    ON public.user_firm_roles TO shared_core_access_writer;

GRANT INSERT (id, firm_id, application_id, valid_from, valid_to)
    ON public.firm_applications TO shared_core_access_writer;
GRANT UPDATE (valid_from, valid_to, is_active)
    ON public.firm_applications TO shared_core_access_writer;
GRANT INSERT (id, user_id, firm_id, application_id, valid_from, valid_to)
    ON public.user_firm_applications TO shared_core_access_writer;
GRANT UPDATE (valid_from, valid_to, is_active)
    ON public.user_firm_applications TO shared_core_access_writer;
GRANT INSERT (id, user_id, firm_id, role_id, valid_from, valid_to)
    ON public.user_firm_roles TO shared_core_access_writer;
GRANT UPDATE (valid_from, valid_to, is_active)
    ON public.user_firm_roles TO shared_core_access_writer;

GRANT INSERT (
    firm_id, user_id, entity_type, entity_id, action, old_values,
    new_values, reason, source_type, request_id, correlation_id
) ON public.audit_log TO shared_core_access_writer;

REVOKE CREATE ON SCHEMA public FROM shared_core_access_writer;
