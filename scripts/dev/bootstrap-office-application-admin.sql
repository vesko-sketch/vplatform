\set ON_ERROR_STOP on

BEGIN;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = 'de000001-0000-4000-8000-000000000001'
          AND email = 'dev-admin@vplatform.invalid'
          AND display_name = 'V Platform Dev Admin'
          AND is_active
    ) THEN
        RAISE EXCEPTION 'Expected development platform user differs';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.applications
        WHERE id = '150251b2-58e1-4981-b05c-d8a9538786cc'
          AND code = 'OFFICE'
          AND is_active
    ) THEN
        RAISE EXCEPTION 'Expected OFFICE application differs';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.roles
        WHERE id = 'f9cb0362-3cf2-4f55-814d-788c52016318'
          AND code = 'admin'
          AND is_active
    ) THEN
        RAISE EXCEPTION 'Expected admin role differs';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.user_application_roles
        WHERE id = 'de000007-0000-4000-8000-000000000007'
          AND (
              user_id <> 'de000001-0000-4000-8000-000000000001'
              OR application_id <> '150251b2-58e1-4981-b05c-d8a9538786cc'
              OR role_id <> 'f9cb0362-3cf2-4f55-814d-788c52016318'
          )
    ) OR EXISTS (
        SELECT 1 FROM public.user_application_roles
        WHERE user_id = 'de000001-0000-4000-8000-000000000001'
          AND application_id = '150251b2-58e1-4981-b05c-d8a9538786cc'
          AND role_id = 'f9cb0362-3cf2-4f55-814d-788c52016318'
          AND id <> 'de000007-0000-4000-8000-000000000007'
    ) THEN
        RAISE EXCEPTION 'Development application-role fixture conflicts with existing data';
    END IF;
END
$$;

INSERT INTO public.user_application_roles (
    id, user_id, application_id, role_id, valid_from, valid_to, is_active
) VALUES (
    'de000007-0000-4000-8000-000000000007',
    'de000001-0000-4000-8000-000000000001',
    '150251b2-58e1-4981-b05c-d8a9538786cc',
    'f9cb0362-3cf2-4f55-814d-788c52016318',
    NULL, NULL, true
)
ON CONFLICT DO NOTHING;

DO $$
BEGIN
    IF (SELECT count(*) FROM public.user_application_roles) <> 1
       OR NOT EXISTS (
           SELECT 1 FROM public.user_application_roles
           WHERE id = 'de000007-0000-4000-8000-000000000007'
             AND user_id = 'de000001-0000-4000-8000-000000000001'
             AND application_id = '150251b2-58e1-4981-b05c-d8a9538786cc'
             AND role_id = 'f9cb0362-3cf2-4f55-814d-788c52016318'
             AND valid_from IS NULL
             AND valid_to IS NULL
             AND is_active
    ) THEN
        RAISE EXCEPTION 'Development application-role fixture verification failed';
    END IF;
END
$$;

COMMIT;
