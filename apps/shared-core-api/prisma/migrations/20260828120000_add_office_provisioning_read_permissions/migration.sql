BEGIN;

DO $$
BEGIN
    IF (SELECT count(*) FROM public.permissions) <> 103
       OR (SELECT md5(string_agg(id::text || '|' || application_id::text || '|' || code || '|' || scope_type || '|' || is_active::text, E'\n' ORDER BY id)) FROM public.permissions)
          <> '616265c03cd0431b8fa31f4e055f8872' THEN
        RAISE EXCEPTION 'Reviewed permission catalog drift detected';
    END IF;
    IF (SELECT count(*) FROM public.role_permissions) <> 318
       OR (SELECT md5(string_agg(id::text || '|' || role_id::text || '|' || permission_id::text || '|' || is_active::text, E'\n' ORDER BY id)) FROM public.role_permissions)
          <> '47446d4455e5d6e5e25539b3b612802f' THEN
        RAISE EXCEPTION 'Reviewed role-permission catalog drift detected';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.applications
        WHERE id = '150251b2-58e1-4981-b05c-d8a9538786cc'
          AND code = 'OFFICE' AND is_active
    ) OR NOT EXISTS (
        SELECT 1 FROM public.applications
        WHERE id = '8211ee99-1de8-47ab-abc3-4065950a5827'
          AND code = 'ACCOUNTING' AND is_active
    ) THEN
        RAISE EXCEPTION 'Reviewed active OFFICE/ACCOUNTING applications not found';
    END IF;
    IF (SELECT count(*) FROM public.roles) <> 7
       OR EXISTS (
           SELECT 1
           FROM (VALUES
               ('f9cb0362-3cf2-4f55-814d-788c52016318'::uuid, 'admin'),
               ('af343e28-e831-4075-b057-602e68f248f6'::uuid, 'manager'),
               ('b13f6113-20e7-4f35-9711-5e4c9a7e4738'::uuid, 'accountant'),
               ('396b6188-e76d-4d82-bb34-02810a285d1b'::uuid, 'payroll'),
               ('a920c985-595b-476c-8221-5815bf17c4fe'::uuid, 'client_owner'),
               ('9ae73810-5674-4fee-8cd3-728558bcf532'::uuid, 'client_staff'),
               ('0ce20ca9-ecc0-444c-9174-e5fb53e920d8'::uuid, 'upload_only')
           ) expected(id, code)
           LEFT JOIN public.roles role
             ON role.id = expected.id AND role.code = expected.code AND role.is_active
           WHERE role.id IS NULL
       ) THEN
        RAISE EXCEPTION 'Reviewed role catalog drift detected';
    END IF;
END
$$;

CREATE TEMPORARY TABLE new_office_provisioning_read_permissions (
    id uuid PRIMARY KEY,
    code varchar(100) UNIQUE NOT NULL
) ON COMMIT DROP;

INSERT INTO new_office_provisioning_read_permissions VALUES
    ('3e52d1da-5d14-5c38-aa52-2d00c1b26dac', 'firms.applications.view'),
    ('097da268-1d6b-5d50-a882-a8be32d18431', 'firms.access.view'),
    ('fca66f80-4d47-5adc-b3d7-b5a85e44b473', 'firms.roles.view');

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM new_office_provisioning_read_permissions expected
        JOIN public.permissions permission
          ON permission.id = expected.id
          OR (permission.application_id = '150251b2-58e1-4981-b05c-d8a9538786cc' AND permission.code = expected.code)
    ) THEN
        RAISE EXCEPTION 'Office provisioning-read permission UUID or code collision';
    END IF;
END
$$;

INSERT INTO public.permissions (id, application_id, code, name, scope_type)
SELECT id, '150251b2-58e1-4981-b05c-d8a9538786cc', code, code, 'APPLICATION'
FROM new_office_provisioning_read_permissions;

CREATE TEMPORARY TABLE new_office_provisioning_read_role_permissions (
    id uuid PRIMARY KEY,
    role_code varchar(50) NOT NULL,
    permission_code varchar(100) NOT NULL,
    UNIQUE (role_code, permission_code)
) ON COMMIT DROP;

INSERT INTO new_office_provisioning_read_role_permissions VALUES
    ('f323cbfc-8bcb-53ed-97c1-01cc497806ce', 'admin', 'firms.applications.view'),
    ('f6e9cf7d-732d-5538-b610-976a2b2513ea', 'manager', 'firms.applications.view'),
    ('2c936730-83a0-5031-a7b0-d797c36de3f9', 'admin', 'firms.access.view'),
    ('21728ea1-8aac-56fc-bfbe-d44ae626f311', 'manager', 'firms.access.view'),
    ('3c656bbd-ca7e-548c-94c5-2fa93762e0f5', 'admin', 'firms.roles.view'),
    ('a6e89e64-2ffc-5e69-82c7-8f00b76422ee', 'manager', 'firms.roles.view');

INSERT INTO public.role_permissions (id, role_id, permission_id)
SELECT mapping.id, role.id, permission.id
FROM new_office_provisioning_read_role_permissions mapping
JOIN public.roles role ON role.code = mapping.role_code AND role.is_active
JOIN public.permissions permission
  ON permission.application_id = '150251b2-58e1-4981-b05c-d8a9538786cc'
 AND permission.code = mapping.permission_code;

DO $$
BEGIN
    IF (SELECT count(*) FROM public.permissions) <> 106
       OR (SELECT count(*) FROM public.permissions WHERE application_id = '150251b2-58e1-4981-b05c-d8a9538786cc') <> 83
       OR (SELECT count(*) FROM public.permissions WHERE application_id = '8211ee99-1de8-47ab-abc3-4065950a5827') <> 23
       OR (SELECT count(*) FROM public.permissions WHERE scope_type = 'APPLICATION') <> 14
       OR (SELECT count(*) FROM public.permissions WHERE scope_type = 'FIRM') <> 92
       OR (SELECT count(*) FROM public.role_permissions) <> 324
       OR (SELECT count(*) FROM public.role_permissions WHERE id IN (SELECT id FROM new_office_provisioning_read_role_permissions)) <> 6 THEN
        RAISE EXCEPTION 'Post-migration provisioning-read catalog verification failed';
    END IF;
    IF EXISTS (
        SELECT 1 FROM new_office_provisioning_read_permissions expected
        LEFT JOIN public.permissions permission
          ON permission.id = expected.id
         AND permission.application_id = '150251b2-58e1-4981-b05c-d8a9538786cc'
         AND permission.code = expected.code
         AND permission.scope_type = 'APPLICATION'
         AND permission.is_active
        WHERE permission.id IS NULL
    ) THEN
        RAISE EXCEPTION 'Incomplete Office provisioning-read permission catalog';
    END IF;
END
$$;

COMMIT;
