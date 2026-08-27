\set ON_ERROR_STOP on

-- DEVELOPMENT ONLY. Execute explicitly with the Shared Core owner/admin credential:
-- psql ... -v keycloak_subject='OPAQUE_KEYCLOAK_SUBJECT' -f scripts/dev/bootstrap-first-platform-user.sql

BEGIN;

SELECT set_config('vplatform.dev_keycloak_subject', :'keycloak_subject', false);

DO $$
DECLARE
    subject_value text := current_setting('vplatform.dev_keycloak_subject');
BEGIN
    IF current_database() <> 'shared_core' THEN
        RAISE EXCEPTION 'Development fixture may run only against database shared_core';
    END IF;
    IF subject_value IS NULL OR btrim(subject_value) = '' OR length(subject_value) > 255 THEN
        RAISE EXCEPTION 'A valid opaque Keycloak subject is required';
    END IF;
    IF (SELECT count(*) FROM public.applications
        WHERE id = '150251b2-58e1-4981-b05c-d8a9538786cc' AND code = 'OFFICE' AND is_active) <> 1 THEN
        RAISE EXCEPTION 'Expected active OFFICE application identity is missing or inconsistent';
    END IF;
    IF (SELECT count(*) FROM public.roles
        WHERE id = 'f9cb0362-3cf2-4f55-814d-788c52016318' AND code = 'admin' AND is_active) <> 1 THEN
        RAISE EXCEPTION 'Expected active admin role identity is missing or inconsistent';
    END IF;
    IF (SELECT count(*) FROM public.role_permissions rp
        JOIN public.permissions p ON p.id = rp.permission_id
        WHERE rp.role_id = 'f9cb0362-3cf2-4f55-814d-788c52016318'
          AND p.application_id = '150251b2-58e1-4981-b05c-d8a9538786cc'
          AND rp.is_active AND p.is_active) <> 69 THEN
        RAISE EXCEPTION 'Expected 69 active OFFICE admin permissions';
    END IF;
    IF (SELECT count(*) FROM public.ref_countries
        WHERE id = '2a299ecf-1920-4789-b781-b969498acef3' AND iso2_code = 'BG' AND is_active) <> 1 THEN
        RAISE EXCEPTION 'Expected active BG reference identity is missing or inconsistent';
    END IF;
    IF (SELECT count(*) FROM public.ref_currencies
        WHERE id = 'd384e401-ade3-4611-b916-d7aba4d9e356' AND iso_code = 'EUR' AND is_active) <> 1 THEN
        RAISE EXCEPTION 'Expected active EUR reference identity is missing or inconsistent';
    END IF;

    IF EXISTS (SELECT 1 FROM public.users WHERE id = 'de000001-0000-4000-8000-000000000001'
        AND email <> 'dev-admin@vplatform.invalid')
       OR EXISTS (SELECT 1 FROM public.users WHERE email = 'dev-admin@vplatform.invalid'
        AND (id <> 'de000001-0000-4000-8000-000000000001'
             OR display_name IS DISTINCT FROM 'V Platform Dev Admin' OR NOT is_active)) THEN
        RAISE EXCEPTION 'Development user key conflicts with unexpected data';
    END IF;

    IF EXISTS (SELECT 1 FROM public.firms WHERE id = 'de000002-0000-4000-8000-000000000002'
        AND code <> 'DEV')
       OR EXISTS (SELECT 1 FROM public.firms WHERE code = 'DEV'
        AND (id <> 'de000002-0000-4000-8000-000000000002'
             OR name <> 'V Platform Development Firm' OR NOT is_active
             OR country_id <> '2a299ecf-1920-4789-b781-b969498acef3'
             OR base_currency_id <> 'd384e401-ade3-4611-b916-d7aba4d9e356')) THEN
        RAISE EXCEPTION 'Development firm key conflicts with unexpected data';
    END IF;

    IF EXISTS (SELECT 1 FROM public.user_external_identities
        WHERE id = 'de000003-0000-4000-8000-000000000003'
          AND (issuer <> 'http://localhost:8080/realms/vplatform' OR subject <> subject_value))
       OR EXISTS (SELECT 1 FROM public.user_external_identities
        WHERE issuer = 'http://localhost:8080/realms/vplatform' AND subject = subject_value
          AND (id <> 'de000003-0000-4000-8000-000000000003'
               OR user_id <> 'de000001-0000-4000-8000-000000000001'
               OR status <> 'active' OR link_provenance <> 'administrator')) THEN
        RAISE EXCEPTION 'Development external identity conflicts with unexpected data';
    END IF;
END $$;

INSERT INTO public.users (id, email, display_name, is_active, metadata)
SELECT 'de000001-0000-4000-8000-000000000001', 'dev-admin@vplatform.invalid',
       'V Platform Dev Admin', true, '{"fixture":"first-development-platform-user"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM public.users WHERE email = 'dev-admin@vplatform.invalid');

INSERT INTO public.firms
    (id, code, name, short_name, country_id, base_currency_id, timezone, is_active, source_system, metadata)
SELECT 'de000002-0000-4000-8000-000000000002', 'DEV', 'V Platform Development Firm',
       'V Platform Dev', '2a299ecf-1920-4789-b781-b969498acef3',
       'd384e401-ade3-4611-b916-d7aba4d9e356', 'Europe/Sofia', true,
       'vplatform-development-fixture', '{"fixture":"first-development-platform-user"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM public.firms WHERE code = 'DEV');

INSERT INTO public.user_external_identities
    (id, user_id, issuer, subject, status, link_provenance, metadata)
SELECT 'de000003-0000-4000-8000-000000000003',
       'de000001-0000-4000-8000-000000000001',
       'http://localhost:8080/realms/vplatform', current_setting('vplatform.dev_keycloak_subject'),
       'active', 'administrator', '{"fixture":"first-development-platform-user"}'::jsonb
WHERE NOT EXISTS (
    SELECT 1 FROM public.user_external_identities
    WHERE issuer = 'http://localhost:8080/realms/vplatform'
      AND subject = current_setting('vplatform.dev_keycloak_subject')
);

INSERT INTO public.firm_applications
    (id, firm_id, application_id, valid_from, valid_to, is_active, metadata)
SELECT 'de000004-0000-4000-8000-000000000004',
       'de000002-0000-4000-8000-000000000002',
       '150251b2-58e1-4981-b05c-d8a9538786cc', NULL, NULL, true,
       '{"fixture":"first-development-platform-user"}'::jsonb
WHERE NOT EXISTS (
    SELECT 1 FROM public.firm_applications
    WHERE firm_id = 'de000002-0000-4000-8000-000000000002'
      AND application_id = '150251b2-58e1-4981-b05c-d8a9538786cc'
);

INSERT INTO public.user_firm_applications
    (id, user_id, firm_id, application_id, valid_from, valid_to, is_active, metadata)
SELECT 'de000005-0000-4000-8000-000000000005',
       'de000001-0000-4000-8000-000000000001',
       'de000002-0000-4000-8000-000000000002',
       '150251b2-58e1-4981-b05c-d8a9538786cc', NULL, NULL, true,
       '{"fixture":"first-development-platform-user"}'::jsonb
WHERE NOT EXISTS (
    SELECT 1 FROM public.user_firm_applications
    WHERE user_id = 'de000001-0000-4000-8000-000000000001'
      AND firm_id = 'de000002-0000-4000-8000-000000000002'
      AND application_id = '150251b2-58e1-4981-b05c-d8a9538786cc'
);

INSERT INTO public.user_firm_roles
    (id, user_id, firm_id, role_id, valid_from, valid_to, is_active, metadata)
SELECT 'de000006-0000-4000-8000-000000000006',
       'de000001-0000-4000-8000-000000000001',
       'de000002-0000-4000-8000-000000000002',
       'f9cb0362-3cf2-4f55-814d-788c52016318', NULL, NULL, true,
       '{"fixture":"first-development-platform-user"}'::jsonb
WHERE NOT EXISTS (
    SELECT 1 FROM public.user_firm_roles
    WHERE user_id = 'de000001-0000-4000-8000-000000000001'
      AND firm_id = 'de000002-0000-4000-8000-000000000002'
      AND role_id = 'f9cb0362-3cf2-4f55-814d-788c52016318'
);

DO $$
DECLARE
    subject_value text := current_setting('vplatform.dev_keycloak_subject');
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = 'de000001-0000-4000-8000-000000000001'
        AND email = 'dev-admin@vplatform.invalid' AND display_name = 'V Platform Dev Admin' AND is_active)
       OR NOT EXISTS (SELECT 1 FROM public.firms WHERE id = 'de000002-0000-4000-8000-000000000002'
        AND code = 'DEV' AND name = 'V Platform Development Firm' AND is_active)
       OR NOT EXISTS (SELECT 1 FROM public.user_external_identities
        WHERE id = 'de000003-0000-4000-8000-000000000003'
          AND user_id = 'de000001-0000-4000-8000-000000000001'
          AND issuer = 'http://localhost:8080/realms/vplatform' AND subject = subject_value
          AND status = 'active' AND link_provenance = 'administrator')
       OR NOT EXISTS (SELECT 1 FROM public.firm_applications
        WHERE id = 'de000004-0000-4000-8000-000000000004'
          AND firm_id = 'de000002-0000-4000-8000-000000000002'
          AND application_id = '150251b2-58e1-4981-b05c-d8a9538786cc'
          AND is_active AND valid_from IS NULL AND valid_to IS NULL)
       OR NOT EXISTS (SELECT 1 FROM public.user_firm_applications
        WHERE id = 'de000005-0000-4000-8000-000000000005'
          AND user_id = 'de000001-0000-4000-8000-000000000001'
          AND firm_id = 'de000002-0000-4000-8000-000000000002'
          AND application_id = '150251b2-58e1-4981-b05c-d8a9538786cc'
          AND is_active AND valid_from IS NULL AND valid_to IS NULL)
       OR NOT EXISTS (SELECT 1 FROM public.user_firm_roles
        WHERE id = 'de000006-0000-4000-8000-000000000006'
          AND user_id = 'de000001-0000-4000-8000-000000000001'
          AND firm_id = 'de000002-0000-4000-8000-000000000002'
          AND role_id = 'f9cb0362-3cf2-4f55-814d-788c52016318'
          AND is_active AND valid_from IS NULL AND valid_to IS NULL) THEN
        RAISE EXCEPTION 'Development fixture postcondition failed';
    END IF;
END $$;

COMMIT;
