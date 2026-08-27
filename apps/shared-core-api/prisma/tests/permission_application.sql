\set ON_ERROR_STOP on

DO $$
BEGIN
    IF (SELECT count(*) FROM public.permissions) <> 23 THEN
        RAISE EXCEPTION 'expected 23 migrated permissions';
    END IF;

    IF (SELECT count(*) FROM public.permissions permission
        JOIN public.applications application ON application.id = permission.application_id
        WHERE application.code = 'ACCOUNTING') <> 23 THEN
        RAISE EXCEPTION 'not every permission maps to ACCOUNTING';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'permissions'
          AND column_name = 'application_id'
          AND is_nullable <> 'NO'
    ) OR NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'permissions'
          AND column_name = 'application_id'
    ) THEN
        RAISE EXCEPTION 'permissions.application_id is missing or nullable';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.permissions'::regclass
          AND conname = 'permissions_application_id_fkey'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION 'permissions application foreign key is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = 'public'
          AND tablename = 'permissions'
          AND indexname = 'idx_permissions_application_active'
    ) THEN
        RAISE EXCEPTION 'permissions application/active index is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.permissions'::regclass
          AND conname = 'permissions_code_key'
          AND contype = 'u'
    ) THEN
        RAISE EXCEPTION 'global permission code uniqueness was not preserved';
    END IF;
END;
$$;

BEGIN;

DO $$
BEGIN
    BEGIN
        INSERT INTO public.permissions (code, name, application_id)
        VALUES (
            'invalid.application',
            'Invalid application',
            'ffffffff-ffff-4fff-8fff-ffffffffffff'
        );
        RAISE EXCEPTION 'unknown application foreign key was accepted';
    EXCEPTION WHEN foreign_key_violation THEN
        NULL;
    END;

    BEGIN
        INSERT INTO public.permissions (code, name, application_id)
        SELECT code, 'Duplicate code', application_id
        FROM public.permissions
        LIMIT 1;
        RAISE EXCEPTION 'duplicate permission code was accepted';
    EXCEPTION WHEN unique_violation THEN
        NULL;
    END;
END;
$$;

ROLLBACK;
