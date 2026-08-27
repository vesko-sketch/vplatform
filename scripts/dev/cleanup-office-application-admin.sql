\set ON_ERROR_STOP on

BEGIN;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM public.user_application_roles
        WHERE id = 'de000007-0000-4000-8000-000000000007'
          AND (
              user_id <> 'de000001-0000-4000-8000-000000000001'
              OR application_id <> '150251b2-58e1-4981-b05c-d8a9538786cc'
              OR role_id <> 'f9cb0362-3cf2-4f55-814d-788c52016318'
          )
    ) THEN
        RAISE EXCEPTION 'Development application-role fixture identity differs';
    END IF;
END
$$;

UPDATE public.user_application_roles
   SET is_active = false
 WHERE id = 'de000007-0000-4000-8000-000000000007'
   AND user_id = 'de000001-0000-4000-8000-000000000001'
   AND application_id = '150251b2-58e1-4981-b05c-d8a9538786cc'
   AND role_id = 'f9cb0362-3cf2-4f55-814d-788c52016318'
   AND is_active;

COMMIT;
