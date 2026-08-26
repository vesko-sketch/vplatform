\set ON_ERROR_STOP on

BEGIN;

INSERT INTO public.users (id, email, display_name)
VALUES
    ('00000000-0000-4000-8000-000000000001', 'identity-one@example.test', 'Identity One'),
    ('00000000-0000-4000-8000-000000000002', 'identity-two@example.test', 'Identity Two');

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'user_external_identities_user_id_fkey'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION 'user_id foreign key is missing';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.user_external_identities'::regclass
          AND contype = 'f'
          AND pg_get_constraintdef(oid) LIKE '%linked_by%'
    ) THEN
        RAISE EXCEPTION 'historical actor UUIDs must not have foreign keys';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.user_external_identities'::regclass
          AND tgname = 'trg_user_external_identities_set_updated_at'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION 'row_version trigger is missing';
    END IF;
END;
$$;

INSERT INTO public.user_external_identities (
    id,
    user_id,
    issuer,
    subject,
    link_provenance,
    linked_by
)
VALUES
    (
        '10000000-0000-4000-8000-000000000001',
        '00000000-0000-4000-8000-000000000001',
        'https://identity-one.example.test/realms/vplatform',
        'subject-1',
        'administrator',
        'ffffffff-ffff-4fff-8fff-ffffffffffff'
    ),
    (
        '10000000-0000-4000-8000-000000000002',
        '00000000-0000-4000-8000-000000000001',
        'https://identity-two.example.test/realms/vplatform',
        'subject-1',
        'invitation',
        NULL
    );

DO $$
BEGIN
    BEGIN
        INSERT INTO public.user_external_identities (
            user_id, issuer, subject, link_provenance
        ) VALUES (
            '00000000-0000-4000-8000-000000000002',
            'https://identity-one.example.test/realms/vplatform',
            'subject-1',
            'administrator'
        );
        RAISE EXCEPTION 'duplicate issuer/subject was accepted';
    EXCEPTION WHEN unique_violation THEN
        NULL;
    END;

    BEGIN
        INSERT INTO public.user_external_identities (
            user_id, issuer, subject, status, link_provenance
        ) VALUES (
            '00000000-0000-4000-8000-000000000002',
            'https://identity.example.test/realms/vplatform',
            'invalid-status',
            'unknown',
            'administrator'
        );
        RAISE EXCEPTION 'invalid status was accepted';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;

    BEGIN
        INSERT INTO public.user_external_identities (
            user_id, issuer, subject, status, link_provenance
        ) VALUES (
            '00000000-0000-4000-8000-000000000002',
            'https://identity.example.test/realms/vplatform',
            'disabled-without-reason',
            'disabled',
            'administrator'
        );
        RAISE EXCEPTION 'disabled identity without reason was accepted';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;

    BEGIN
        INSERT INTO public.user_external_identities (
            user_id, issuer, subject, link_provenance
        ) VALUES (
            'ffffffff-ffff-4fff-8fff-ffffffffffff',
            'https://identity.example.test/realms/vplatform',
            'unknown-user',
            'administrator'
        );
        RAISE EXCEPTION 'unknown user_id was accepted';
    EXCEPTION WHEN foreign_key_violation THEN
        NULL;
    END;
END;
$$;

UPDATE public.user_external_identities
SET
    status = 'disabled',
    status_changed_by = 'ffffffff-ffff-4fff-8fff-ffffffffffff',
    status_changed_at = clock_timestamp(),
    status_change_reason = 'disposable lifecycle test'
WHERE id = '10000000-0000-4000-8000-000000000001'
  AND row_version = 1;

DO $$
DECLARE
    affected_rows integer;
    current_version bigint;
BEGIN
    SELECT row_version
    INTO current_version
    FROM public.user_external_identities
    WHERE id = '10000000-0000-4000-8000-000000000001';

    IF current_version <> 2 THEN
        RAISE EXCEPTION 'row_version trigger did not increment: %', current_version;
    END IF;

    UPDATE public.user_external_identities
    SET status_change_reason = 'stale update must not apply'
    WHERE id = '10000000-0000-4000-8000-000000000001'
      AND row_version = 1;

    GET DIAGNOSTICS affected_rows = ROW_COUNT;
    IF affected_rows <> 0 THEN
        RAISE EXCEPTION 'stale optimistic update was accepted';
    END IF;
END;
$$;

UPDATE public.user_external_identities
SET
    status = 'unlinked',
    status_changed_at = clock_timestamp(),
    status_change_reason = 'disposable unlink test'
WHERE id = '10000000-0000-4000-8000-000000000001'
  AND row_version = 2;

INSERT INTO public.audit_log (
    user_id,
    entity_type,
    entity_id,
    action,
    old_values,
    new_values,
    reason,
    source_type,
    request_id,
    correlation_id
)
VALUES (
    'ffffffff-ffff-4fff-8fff-ffffffffffff',
    'user_external_identity',
    '10000000-0000-4000-8000-000000000001',
    'unlinked',
    '{"status":"disabled"}'::jsonb,
    '{"status":"unlinked"}'::jsonb,
    'disposable unlink test',
    'shared-core-api',
    '20000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001'
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM public.audit_log
        WHERE entity_type = 'user_external_identity'
          AND entity_id = '10000000-0000-4000-8000-000000000001'
          AND action = 'unlinked'
          AND reason = 'disposable unlink test'
    ) THEN
        RAISE EXCEPTION 'identity lifecycle audit record was not persisted';
    END IF;
END;
$$;

DO $$
BEGIN
    BEGIN
        INSERT INTO public.user_external_identities (
            user_id, issuer, subject, link_provenance
        ) VALUES (
            '00000000-0000-4000-8000-000000000002',
            'https://identity-one.example.test/realms/vplatform',
            'subject-1',
            'recovery'
        );
        RAISE EXCEPTION 'historical unlinked tuple was reassigned';
    EXCEPTION WHEN unique_violation THEN
        NULL;
    END;
END;
$$;

ROLLBACK;
