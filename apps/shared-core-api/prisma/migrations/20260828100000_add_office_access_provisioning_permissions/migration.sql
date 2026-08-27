BEGIN;

DO $$
BEGIN
    IF (SELECT count(*) FROM public.permissions) <> 97
       OR (SELECT md5(string_agg(id::text || '|' || application_id::text || '|' || code || '|' || scope_type || '|' || is_active::text, E'\n' ORDER BY id)) FROM public.permissions)
          <> 'f236b13260a6b36a8bd08cbba5f6db62' THEN
        RAISE EXCEPTION 'Reviewed permission catalog drift detected';
    END IF;
    IF (SELECT count(*) FROM public.role_permissions) <> 306
       OR (SELECT md5(string_agg(id::text || '|' || role_id::text || '|' || permission_id::text || '|' || is_active::text, E'\n' ORDER BY id)) FROM public.role_permissions)
          <> '9b2f9964acbc416ebd8b6533d41ba401' THEN
        RAISE EXCEPTION 'Reviewed role-permission catalog drift detected';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.applications
        WHERE id = '150251b2-58e1-4981-b05c-d8a9538786cc'
          AND code = 'OFFICE' AND is_active
    ) THEN
        RAISE EXCEPTION 'Reviewed active OFFICE application not found';
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

CREATE TEMPORARY TABLE new_office_access_permissions (
    id uuid PRIMARY KEY,
    code varchar(100) UNIQUE NOT NULL
) ON COMMIT DROP;

INSERT INTO new_office_access_permissions VALUES
    ('0346bc6e-a6c5-5a98-a066-a1e3371d5bfb', 'firms.applications.enable'),
    ('6982e5bc-5195-5163-b0f9-5cfb594a595e', 'firms.applications.disable'),
    ('73d5c806-a3ce-5221-9c0c-330913a61331', 'firms.access.grant'),
    ('dd6e60c1-f44f-5fc6-8009-393b402998cd', 'firms.access.revoke'),
    ('6e7c0c91-ca21-5af0-bfb1-4978c8ca9ddf', 'firms.roles.assign'),
    ('f95099f7-69b2-55e2-896d-d446bd3b8259', 'firms.roles.remove');

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM new_office_access_permissions expected
        JOIN public.permissions permission
          ON permission.id = expected.id
          OR (permission.application_id = '150251b2-58e1-4981-b05c-d8a9538786cc' AND permission.code = expected.code)
    ) THEN
        RAISE EXCEPTION 'Office access-provisioning permission UUID or code collision';
    END IF;
END
$$;

INSERT INTO public.permissions (id, application_id, code, name, scope_type)
SELECT id, '150251b2-58e1-4981-b05c-d8a9538786cc', code, code, 'APPLICATION'
FROM new_office_access_permissions;

CREATE TEMPORARY TABLE new_office_access_role_permissions (
    id uuid PRIMARY KEY,
    role_code varchar(50) NOT NULL,
    permission_code varchar(100) NOT NULL,
    UNIQUE (role_code, permission_code)
) ON COMMIT DROP;

INSERT INTO new_office_access_role_permissions VALUES
    ('6d01fa1c-aecc-520f-8545-5b2ff45cbdf8', 'admin', 'firms.applications.enable'),
    ('79d9ad6e-7cf6-584d-adc8-ca79d0504bdc', 'manager', 'firms.applications.enable'),
    ('3b9feaf7-c5a0-5198-950c-330d2ca85762', 'admin', 'firms.applications.disable'),
    ('4c335c78-363e-54a4-b13c-02378c5be185', 'manager', 'firms.applications.disable'),
    ('b19b3f00-200a-5783-8377-47964c48c989', 'admin', 'firms.access.grant'),
    ('d716a196-b753-5929-83be-237e6edf9d48', 'manager', 'firms.access.grant'),
    ('ca6e0a78-bc62-57cf-9668-bbb1529b1863', 'admin', 'firms.access.revoke'),
    ('a2c90b8a-0f4d-5d26-bd01-aab530a82e47', 'manager', 'firms.access.revoke'),
    ('6567bfb0-708a-5e25-8d86-523b8c19a9b1', 'admin', 'firms.roles.assign'),
    ('9d9cc43f-1696-516e-8653-0bd76a7e1d83', 'manager', 'firms.roles.assign'),
    ('11385f1c-58c3-5b61-911e-e37d6eb5a206', 'admin', 'firms.roles.remove'),
    ('9b2592fa-0c9a-52e2-b24a-562a981d1e42', 'manager', 'firms.roles.remove');

INSERT INTO public.role_permissions (id, role_id, permission_id)
SELECT mapping.id, role.id, permission.id
FROM new_office_access_role_permissions mapping
JOIN public.roles role ON role.code = mapping.role_code AND role.is_active
JOIN public.permissions permission
  ON permission.application_id = '150251b2-58e1-4981-b05c-d8a9538786cc'
 AND permission.code = mapping.permission_code;

DO $$
BEGIN
    IF (SELECT count(*) FROM public.permissions) <> 103
       OR (SELECT count(*) FROM public.permissions WHERE application_id = '150251b2-58e1-4981-b05c-d8a9538786cc') <> 80
       OR (SELECT count(*) FROM public.permissions WHERE scope_type = 'APPLICATION') <> 11
       OR (SELECT count(*) FROM public.permissions WHERE scope_type = 'FIRM') <> 92
       OR (SELECT count(*) FROM public.role_permissions) <> 318
       OR (SELECT count(*) FROM public.role_permissions WHERE id IN (SELECT id FROM new_office_access_role_permissions)) <> 12 THEN
        RAISE EXCEPTION 'Post-migration access-provisioning catalog verification failed';
    END IF;
    IF EXISTS (
        SELECT 1 FROM new_office_access_permissions expected
        LEFT JOIN public.permissions permission
          ON permission.id = expected.id
         AND permission.application_id = '150251b2-58e1-4981-b05c-d8a9538786cc'
         AND permission.code = expected.code
         AND permission.scope_type = 'APPLICATION'
         AND permission.is_active
        WHERE permission.id IS NULL
    ) THEN
        RAISE EXCEPTION 'Incomplete Office access-provisioning permission catalog';
    END IF;
END
$$;

COMMIT;
