\set ON_ERROR_STOP on

DO $$
DECLARE
    office_id constant uuid := '150251b2-58e1-4981-b05c-d8a9538786cc';
    target_permission_id constant uuid := '694951ee-27fc-522f-a5c3-f5f2ffe83546';
BEGIN
    IF (SELECT count(*) FROM public.permissions) <> 97
       OR (SELECT count(*) FROM public.permissions WHERE application_id = office_id) <> 74
       OR (SELECT count(*) FROM public.permissions WHERE scope_type = 'APPLICATION') <> 5
       OR (SELECT count(*) FROM public.permissions WHERE scope_type = 'FIRM') <> 92
       OR (SELECT count(*) FROM public.role_permissions) <> 306 THEN
        RAISE EXCEPTION 'Corrected scope or mapping totals differ';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.permissions
        WHERE id = target_permission_id
          AND application_id = office_id
          AND code = 'firms.activate'
          AND scope_type = 'APPLICATION'
          AND is_active
    ) OR NOT EXISTS (
        SELECT 1 FROM public.permissions
        WHERE application_id = office_id
          AND code = 'firms.disable'
          AND scope_type = 'FIRM'
          AND is_active
    ) THEN
        RAISE EXCEPTION 'Firm lifecycle permission scopes differ';
    END IF;

    IF (
        SELECT count(*)
        FROM public.role_permissions mapping
        JOIN public.roles role ON role.id = mapping.role_id
        WHERE mapping.permission_id = target_permission_id
          AND mapping.is_active
          AND role.code IN ('admin', 'manager')
    ) <> 2 OR (SELECT count(*) FROM public.role_permissions WHERE permission_id = target_permission_id) <> 2 THEN
        RAISE EXCEPTION 'firms.activate role mappings changed';
    END IF;
END
$$;

SELECT 'firms.activate application scope verified' AS result;
