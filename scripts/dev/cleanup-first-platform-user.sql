\set ON_ERROR_STOP on

-- REVIEWED DEVELOPMENT RETIREMENT ONLY. This is intentionally never run automatically.
-- Identity history and its owning platform user are retained for auditability.
BEGIN;

DO $$
BEGIN
    IF current_database() <> 'shared_core' THEN
        RAISE EXCEPTION 'Development cleanup may run only against database shared_core';
    END IF;
    IF EXISTS (SELECT 1 FROM public.users WHERE id = 'de000001-0000-4000-8000-000000000001'
        AND (email <> 'dev-admin@vplatform.invalid'
             OR metadata ->> 'fixture' <> 'first-development-platform-user'))
       OR EXISTS (SELECT 1 FROM public.firms WHERE id = 'de000002-0000-4000-8000-000000000002'
        AND (code <> 'DEV' OR metadata ->> 'fixture' <> 'first-development-platform-user')) THEN
        RAISE EXCEPTION 'Fixture identity conflict; cleanup refused';
    END IF;
END $$;

UPDATE public.user_firm_roles
SET is_active = false
WHERE id = 'de000006-0000-4000-8000-000000000006' AND is_active;

UPDATE public.user_firm_applications
SET is_active = false
WHERE id = 'de000005-0000-4000-8000-000000000005' AND is_active;

UPDATE public.firm_applications
SET is_active = false
WHERE id = 'de000004-0000-4000-8000-000000000004' AND is_active;

UPDATE public.user_external_identities
SET status = 'unlinked', status_changed_at = now(),
    status_change_reason = 'Development fixture retired by reviewed cleanup procedure'
WHERE id = 'de000003-0000-4000-8000-000000000003' AND status = 'active';

UPDATE public.firms
SET is_active = false
WHERE id = 'de000002-0000-4000-8000-000000000002' AND is_active;

UPDATE public.users
SET is_active = false
WHERE id = 'de000001-0000-4000-8000-000000000001' AND is_active;

COMMIT;
