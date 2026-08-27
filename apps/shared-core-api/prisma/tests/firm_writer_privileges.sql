\set ON_ERROR_STOP on

DROP ROLE IF EXISTS phase3a1_firm_writer_test;
CREATE ROLE phase3a1_firm_writer_test NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
GRANT USAGE ON SCHEMA public TO phase3a1_firm_writer_test;

GRANT SELECT (id, is_active) ON public.users TO phase3a1_firm_writer_test;
GRANT SELECT (id, code, is_active) ON public.applications TO phase3a1_firm_writer_test;
GRANT SELECT (
    id, code, name, short_name, legal_form_id, country_id,
    registration_number, base_currency_id, default_language_id,
    timezone, is_active, row_version, created_at, updated_at
) ON public.firms TO phase3a1_firm_writer_test;
GRANT SELECT (firm_id, application_id, is_active, valid_from, valid_to)
    ON public.firm_applications TO phase3a1_firm_writer_test;
GRANT SELECT (user_id, firm_id, application_id, is_active, valid_from, valid_to)
    ON public.user_firm_applications TO phase3a1_firm_writer_test;
GRANT SELECT (id, user_id, firm_id, role_id, is_active, valid_from, valid_to)
    ON public.user_firm_roles TO phase3a1_firm_writer_test;
GRANT SELECT (id, code, is_active) ON public.roles TO phase3a1_firm_writer_test;
GRANT SELECT (role_id, permission_id, is_active)
    ON public.role_permissions TO phase3a1_firm_writer_test;
GRANT SELECT (id, application_id, code, is_active, scope_type)
    ON public.permissions TO phase3a1_firm_writer_test;
GRANT SELECT (id, user_id, application_id, role_id, is_active, valid_from, valid_to)
    ON public.user_application_roles TO phase3a1_firm_writer_test;
GRANT SELECT (id, user_id, firm_id, permission_id, effect, valid_from, valid_to)
    ON public.user_permission_overrides TO phase3a1_firm_writer_test;
GRANT SELECT (id, is_active) ON public.ref_countries TO phase3a1_firm_writer_test;
GRANT SELECT (id, is_active) ON public.ref_currencies TO phase3a1_firm_writer_test;
GRANT SELECT (id, is_active) ON public.ref_languages TO phase3a1_firm_writer_test;
GRANT SELECT (id, is_active) ON public.ref_legal_forms TO phase3a1_firm_writer_test;

GRANT INSERT (
    id, code, name, short_name, legal_form_id, country_id,
    registration_number, base_currency_id, default_language_id, timezone
) ON public.firms TO phase3a1_firm_writer_test;
GRANT UPDATE (
    code, name, short_name, legal_form_id, country_id,
    registration_number, base_currency_id, default_language_id,
    timezone, is_active
) ON public.firms TO phase3a1_firm_writer_test;
GRANT INSERT (
    firm_id, user_id, entity_type, entity_id, action, old_values,
    new_values, reason, source_type, request_id, correlation_id
) ON public.audit_log TO phase3a1_firm_writer_test;

DO $$
DECLARE
    role_row record;
BEGIN
    SELECT * INTO STRICT role_row FROM pg_roles WHERE rolname = 'phase3a1_firm_writer_test';
    IF role_row.rolsuper OR role_row.rolcreaterole OR role_row.rolcreatedb OR role_row.rolbypassrls THEN
        RAISE EXCEPTION 'writer role has a forbidden role attribute';
    END IF;
    IF has_schema_privilege('phase3a1_firm_writer_test', 'public', 'CREATE') THEN
        RAISE EXCEPTION 'writer role has schema CREATE';
    END IF;
    IF has_table_privilege('phase3a1_firm_writer_test', 'public.firms', 'DELETE')
       OR has_table_privilege('phase3a1_firm_writer_test', 'public.firms', 'TRUNCATE')
       OR has_table_privilege('phase3a1_firm_writer_test', 'public.audit_log', 'UPDATE')
       OR has_table_privilege('phase3a1_firm_writer_test', 'public.audit_log', 'DELETE') THEN
        RAISE EXCEPTION 'writer role has a forbidden mutation privilege';
    END IF;
    IF NOT has_column_privilege('phase3a1_firm_writer_test', 'public.firms', 'name', 'UPDATE')
       OR NOT has_column_privilege('phase3a1_firm_writer_test', 'public.audit_log', 'action', 'INSERT') THEN
        RAISE EXCEPTION 'writer role is missing a required column privilege';
    END IF;
    IF has_column_privilege('phase3a1_firm_writer_test', 'public.firms', 'metadata', 'UPDATE')
       OR has_column_privilege('phase3a1_firm_writer_test', 'public.firms', 'source_system', 'INSERT') THEN
        RAISE EXCEPTION 'writer role can mutate an unapproved firm column';
    END IF;
END
$$;

BEGIN;
INSERT INTO public.ref_countries (id, iso2_code, name_bg)
VALUES ('fa330001-0000-4000-8000-000000000001', 'X2', 'Writer test country');
INSERT INTO public.ref_currencies (id, iso_code, name)
VALUES ('fa330002-0000-4000-8000-000000000002', 'XTW', 'Writer test currency');

SET LOCAL ROLE phase3a1_firm_writer_test;
INSERT INTO public.firms (id, code, name, country_id, base_currency_id)
VALUES (
    'fa330003-0000-4000-8000-000000000003', 'PHASE3A2_WRITER', 'Writer Test Firm',
    'fa330001-0000-4000-8000-000000000001', 'fa330002-0000-4000-8000-000000000002'
);
UPDATE public.firms SET name = 'Writer Test Firm Updated'
WHERE id = 'fa330003-0000-4000-8000-000000000003' AND row_version = 1;
INSERT INTO public.audit_log (firm_id, entity_type, entity_id, action, new_values, source_type)
VALUES (
    'fa330003-0000-4000-8000-000000000003', 'firm',
    'fa330003-0000-4000-8000-000000000003', 'firm.created',
    '{"code":"PHASE3A2_WRITER"}', 'shared-core-api'
);

DO $$
BEGIN
    BEGIN
        DELETE FROM public.firms WHERE id = 'fa330003-0000-4000-8000-000000000003';
        RAISE EXCEPTION 'DELETE unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        UPDATE public.firms SET metadata = '{"forbidden":true}'
        WHERE id = 'fa330003-0000-4000-8000-000000000003';
        RAISE EXCEPTION 'metadata update unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        UPDATE public.ref_countries SET name_bg = 'Forbidden'
        WHERE id = 'fa330001-0000-4000-8000-000000000001';
        RAISE EXCEPTION 'reference update unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        INSERT INTO public.roles (code, name) VALUES ('forbidden', 'Forbidden');
        RAISE EXCEPTION 'role insert unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        INSERT INTO public.user_application_roles (user_id, application_id, role_id)
        VALUES (
            'fa330009-0000-4000-8000-000000000009',
            '150251b2-58e1-4981-b05c-d8a9538786cc',
            'f9cb0362-3cf2-4f55-814d-788c52016318'
        );
        RAISE EXCEPTION 'authorization assignment insert unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    BEGIN
        CREATE TABLE public.forbidden_writer_table (id integer);
        RAISE EXCEPTION 'schema CREATE unexpectedly succeeded';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
END
$$;
RESET ROLE;
ROLLBACK;

DROP OWNED BY phase3a1_firm_writer_test;
DROP ROLE phase3a1_firm_writer_test;

SELECT 'firm writer disposable privileges verified' AS result;
