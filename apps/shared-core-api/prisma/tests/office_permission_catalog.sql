\set ON_ERROR_STOP on

DO $$
DECLARE
    office_id constant uuid := '150251b2-58e1-4981-b05c-d8a9538786cc';
    accounting_id constant uuid := '8211ee99-1de8-47ab-abc3-4065950a5827';
BEGIN
    IF (SELECT count(*) FROM public.permissions WHERE application_id = accounting_id) <> 23 THEN
        RAISE EXCEPTION 'Accounting permission catalog changed';
    END IF;

    IF (SELECT count(*) FROM public.permissions WHERE application_id = office_id) <> 69 THEN
        RAISE EXCEPTION 'Expected 69 Office permissions';
    END IF;

    IF (SELECT count(*) FROM public.role_permissions) <> 297 THEN
        RAISE EXCEPTION 'Expected 297 Office role-permission mappings';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.role_permissions mapping
        JOIN public.permissions permission ON permission.id = mapping.permission_id
        WHERE permission.application_id <> office_id
    ) THEN
        RAISE EXCEPTION 'Default role mapping references a non-Office permission';
    END IF;

    IF EXISTS (
        SELECT expected.role_code, expected.expected_count, count(mapping.id) AS actual_count
        FROM (VALUES
            ('admin', 69),
            ('manager', 68),
            ('accountant', 54),
            ('payroll', 47),
            ('client_owner', 33),
            ('client_staff', 17),
            ('upload_only', 9)
        ) AS expected(role_code, expected_count)
        JOIN public.roles role ON role.code = expected.role_code
        LEFT JOIN public.role_permissions mapping ON mapping.role_id = role.id
        GROUP BY expected.role_code, expected.expected_count
        HAVING count(mapping.id) <> expected.expected_count
    ) THEN
        RAISE EXCEPTION 'Per-role Office mapping count differs from reviewed matrix';
    END IF;

    IF (SELECT count(*) FROM public.permissions WHERE code = 'documents.view') <> 2
       OR NOT EXISTS (
           SELECT 1 FROM public.permissions
           WHERE application_id = office_id AND code = 'documents.view'
       )
       OR NOT EXISTS (
           SELECT 1 FROM public.permissions
           WHERE application_id = accounting_id AND code = 'documents.view'
       ) THEN
        RAISE EXCEPTION 'Cross-application documents.view coexistence failed';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.permissions'::regclass
          AND conname = 'permissions_application_id_code_key'
          AND contype = 'u'
    ) OR EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.permissions'::regclass
          AND conname = 'permissions_code_key'
    ) THEN
        RAISE EXCEPTION 'Permission uniqueness transition is incomplete';
    END IF;

    IF (SELECT count(*) FROM public.firm_applications) <> 0
       OR (SELECT count(*) FROM public.user_firm_applications) <> 0
       OR (SELECT count(*) FROM public.user_firm_roles) <> 0
       OR (SELECT count(*) FROM public.user_permission_overrides) <> 0
       OR (SELECT count(*) FROM public.permission_resource_scopes) <> 0 THEN
        RAISE EXCEPTION 'Authorization access assignments were created';
    END IF;
END;
$$;

BEGIN;

DO $$
BEGIN
    BEGIN
        INSERT INTO public.permissions (application_id, code, name)
        VALUES (
            '150251b2-58e1-4981-b05c-d8a9538786cc',
            'documents.view',
            'Duplicate Office documents.view'
        );
        RAISE EXCEPTION 'Duplicate Office permission code was accepted';
    EXCEPTION WHEN unique_violation THEN
        NULL;
    END;

    BEGIN
        INSERT INTO public.permissions (application_id, code, name)
        VALUES (
            '8211ee99-1de8-47ab-abc3-4065950a5827',
            'documents.view',
            'Duplicate Accounting documents.view'
        );
        RAISE EXCEPTION 'Duplicate Accounting permission code was accepted';
    EXCEPTION WHEN unique_violation THEN
        NULL;
    END;
END;
$$;

ROLLBACK;
