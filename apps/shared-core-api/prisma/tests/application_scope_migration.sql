\set ON_ERROR_STOP on

DO $$
DECLARE
    office_id constant uuid := '150251b2-58e1-4981-b05c-d8a9538786cc';
    accounting_id constant uuid := '8211ee99-1de8-47ab-abc3-4065950a5827';
BEGIN
    IF (SELECT count(*) FROM public.permissions) <> 97
       OR (SELECT count(*) FROM public.permissions WHERE application_id = office_id) <> 74
       OR (SELECT count(*) FROM public.permissions WHERE application_id = accounting_id) <> 23
       OR (SELECT count(*) FROM public.permissions WHERE scope_type = 'APPLICATION') <> 4
       OR (SELECT count(*) FROM public.permissions WHERE scope_type = 'FIRM') <> 93 THEN
        RAISE EXCEPTION 'Permission totals or scope totals differ';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.permissions
        WHERE application_id = accounting_id AND scope_type <> 'FIRM'
    ) THEN
        RAISE EXCEPTION 'An Accounting permission changed from FIRM scope';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.permissions'::regclass
          AND conname = 'permissions_scope_type_check'
          AND contype = 'c'
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.user_application_roles'::regclass
          AND conname = 'user_application_roles_user_application_role_key'
          AND contype = 'u'
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgrelid = 'public.user_application_roles'::regclass
          AND tgname = 'trg_user_application_roles_set_updated_at'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION 'Application-scope constraints or trigger are incomplete';
    END IF;

    IF (SELECT count(*) FROM public.role_permissions) <> 306
       OR EXISTS (
           SELECT expected.code, expected.expected_count, count(mapping.id)
           FROM (VALUES
               ('admin', 74),
               ('manager', 72),
               ('accountant', 54),
               ('payroll', 47),
               ('client_owner', 33),
               ('client_staff', 17),
               ('upload_only', 9)
           ) expected(code, expected_count)
           JOIN public.roles role ON role.code = expected.code
           LEFT JOIN public.role_permissions mapping ON mapping.role_id = role.id
           GROUP BY expected.code, expected.expected_count
           HAVING count(mapping.id) <> expected.expected_count
       ) THEN
        RAISE EXCEPTION 'Role-permission totals differ';
    END IF;

    IF (SELECT count(*) FROM public.user_application_roles) <> 0
       OR (SELECT count(*) FROM public.firm_applications) <> 0
       OR (SELECT count(*) FROM public.user_firm_applications) <> 0
       OR (SELECT count(*) FROM public.user_firm_roles) <> 0
       OR (SELECT count(*) FROM public.user_permission_overrides) <> 0
       OR (SELECT count(*) FROM public.permission_resource_scopes) <> 0 THEN
        RAISE EXCEPTION 'Migration created an authorization assignment';
    END IF;
END
$$;

DO $$
BEGIN
    BEGIN
        INSERT INTO public.user_application_roles (
            id, user_id, application_id, role_id, valid_from, valid_to
        ) VALUES (
            'fa320001-0000-4000-8000-000000000001',
            'fa320002-0000-4000-8000-000000000002',
            '150251b2-58e1-4981-b05c-d8a9538786cc',
            'f9cb0362-3cf2-4f55-814d-788c52016318',
            DATE '2026-08-28', DATE '2026-08-27'
        );
        RAISE EXCEPTION 'Invalid validity range unexpectedly succeeded';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;
END
$$;

SELECT 'application scope migration verified' AS result;
