BEGIN;

DO $$
DECLARE
    office_id constant uuid := '150251b2-58e1-4981-b05c-d8a9538786cc';
    target_permission_id constant uuid := '694951ee-27fc-522f-a5c3-f5f2ffe83546';
    affected integer;
BEGIN
    IF (SELECT count(*) FROM public.permissions) <> 97
       OR (SELECT count(*) FROM public.permissions WHERE application_id = office_id) <> 74
       OR (SELECT count(*) FROM public.permissions WHERE scope_type = 'APPLICATION') <> 4
       OR (SELECT count(*) FROM public.permissions WHERE scope_type = 'FIRM') <> 93
       OR (SELECT count(*) FROM public.role_permissions) <> 306 THEN
        RAISE EXCEPTION 'Reviewed permission or role mapping totals differ';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.applications
        WHERE id = office_id AND code = 'OFFICE' AND is_active
    ) OR (SELECT count(*) FROM public.applications WHERE code = 'OFFICE') <> 1 THEN
        RAISE EXCEPTION 'Reviewed OFFICE application state differs';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.permissions
        WHERE id = target_permission_id
          AND application_id = office_id
          AND code = 'firms.activate'
          AND scope_type = 'FIRM'
          AND is_active
    ) THEN
        RAISE EXCEPTION 'Reviewed firms.activate permission state differs';
    END IF;

    IF (
        SELECT count(*)
        FROM public.role_permissions mapping
        JOIN public.roles role ON role.id = mapping.role_id
        WHERE mapping.permission_id = target_permission_id
          AND mapping.is_active
          AND role.is_active
          AND (
              (mapping.id = '3665b757-9342-5f81-abf0-9ad7284f306d' AND role.id = 'f9cb0362-3cf2-4f55-814d-788c52016318' AND role.code = 'admin')
              OR
              (mapping.id = '6fff5e5c-66b8-5746-83db-a64d6287cc24' AND role.id = 'af343e28-e831-4075-b057-602e68f248f6' AND role.code = 'manager')
          )
    ) <> 2 OR (
        SELECT count(*) FROM public.role_permissions WHERE permission_id = target_permission_id
    ) <> 2 THEN
        RAISE EXCEPTION 'Reviewed firms.activate role mappings differ';
    END IF;

    UPDATE public.permissions
       SET scope_type = 'APPLICATION'
     WHERE id = target_permission_id
       AND application_id = office_id
       AND code = 'firms.activate'
       AND scope_type = 'FIRM'
       AND is_active;
    GET DIAGNOSTICS affected = ROW_COUNT;

    IF affected <> 1
       OR (SELECT count(*) FROM public.permissions) <> 97
       OR (SELECT count(*) FROM public.permissions WHERE scope_type = 'APPLICATION') <> 5
       OR (SELECT count(*) FROM public.permissions WHERE scope_type = 'FIRM') <> 92
       OR (SELECT count(*) FROM public.role_permissions) <> 306 THEN
        RAISE EXCEPTION 'firms.activate scope correction verification failed';
    END IF;
END
$$;

COMMIT;
