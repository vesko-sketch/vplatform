\set ON_ERROR_STOP on

BEGIN;

INSERT INTO public.ref_countries (id, iso2_code, name_bg)
VALUES ('fa310001-0000-4000-8000-000000000001', 'X1', 'Disposable country');
INSERT INTO public.ref_currencies (id, iso_code, name)
VALUES ('fa310002-0000-4000-8000-000000000002', 'XTS', 'Disposable currency');
INSERT INTO public.ref_languages (id, iso_code, name_bg)
VALUES ('fa310003-0000-4000-8000-000000000003', 'x1', 'Disposable language');
INSERT INTO public.ref_legal_forms (id, code, short_name)
VALUES ('fa310004-0000-4000-8000-000000000004', 'DISPOSABLE_FORM', 'Disposable');

DO $$
DECLARE
    country_uuid uuid;
    currency_uuid uuid;
    language_uuid uuid;
    legal_form_uuid uuid;
    firm_uuid constant uuid := 'fa300001-0000-4000-8000-000000000001';
    actor_uuid constant uuid := 'fa300002-0000-4000-8000-000000000002';
    affected integer;
    before_name text;
BEGIN
    SELECT id INTO STRICT country_uuid FROM public.ref_countries WHERE iso2_code = 'X1' AND is_active;
    SELECT id INTO STRICT currency_uuid FROM public.ref_currencies WHERE iso_code = 'XTS' AND is_active;
    SELECT id INTO STRICT language_uuid FROM public.ref_languages WHERE iso_code = 'x1' AND is_active;
    SELECT id INTO STRICT legal_form_uuid FROM public.ref_legal_forms WHERE code = 'DISPOSABLE_FORM' AND is_active;

    INSERT INTO public.firms (
        id, code, name, short_name, legal_form_id, country_id,
        registration_number, base_currency_id, default_language_id, timezone
    ) VALUES (
        firm_uuid, 'PHASE3A1', 'Phase 3A.1 Disposable Firm', 'Disposable',
        legal_form_uuid, country_uuid, 'DISPOSABLE-ONLY', currency_uuid,
        language_uuid, 'Europe/Sofia'
    );

    INSERT INTO public.audit_log (
        firm_id, user_id, entity_type, entity_id, action,
        old_values, new_values, reason, source_type, request_id, correlation_id
    ) VALUES (
        firm_uuid, actor_uuid, 'firm', firm_uuid, 'firm.created', NULL,
        jsonb_build_object('code', 'PHASE3A1', 'name', 'Phase 3A.1 Disposable Firm'),
        NULL, 'shared-core-api',
        'fa300003-0000-4000-8000-000000000003',
        'fa300004-0000-4000-8000-000000000004'
    );

    IF NOT EXISTS (SELECT 1 FROM public.audit_log WHERE entity_id = firm_uuid AND action = 'firm.created') THEN
        RAISE EXCEPTION 'create audit was not persisted';
    END IF;

    BEGIN
        INSERT INTO public.firms (id, code, name, country_id, base_currency_id)
        VALUES ('fa300001-0000-4000-8000-000000000009', 'PHASE3A1', 'Duplicate', country_uuid, currency_uuid);
        RAISE EXCEPTION 'duplicate firm code unexpectedly succeeded';
    EXCEPTION WHEN unique_violation THEN
        NULL;
    END;

    BEGIN
        INSERT INTO public.firms (id, code, name, country_id, base_currency_id)
        VALUES (
            'fa300001-0000-4000-8000-000000000008', 'PHASE3A1_BAD_FK', 'Bad FK',
            'fa399999-0000-4000-8000-000000000099', currency_uuid
        );
        RAISE EXCEPTION 'invalid reference unexpectedly succeeded';
    EXCEPTION WHEN foreign_key_violation THEN
        NULL;
    END;

    UPDATE public.firms
       SET name = 'Phase 3A.1 Updated Firm'
     WHERE id = firm_uuid AND row_version = 1;
    GET DIAGNOSTICS affected = ROW_COUNT;
    IF affected <> 1 OR (SELECT row_version FROM public.firms WHERE id = firm_uuid) <> 2 THEN
        RAISE EXCEPTION 'optimistic update or row_version trigger failed';
    END IF;

    UPDATE public.firms SET name = 'Stale overwrite' WHERE id = firm_uuid AND row_version = 1;
    GET DIAGNOSTICS affected = ROW_COUNT;
    IF affected <> 0 THEN
        RAISE EXCEPTION 'stale row_version update unexpectedly succeeded';
    END IF;

    UPDATE public.firms
       SET code = 'PHASE3A1_IDENTITY', registration_number = 'DISPOSABLE-IDENTITY'
     WHERE id = firm_uuid AND row_version = 2;
    GET DIAGNOSTICS affected = ROW_COUNT;
    IF affected <> 1 OR (SELECT row_version FROM public.firms WHERE id = firm_uuid) <> 3 THEN
        RAISE EXCEPTION 'identity update failed';
    END IF;

    UPDATE public.firms SET base_currency_id = currency_uuid
     WHERE id = firm_uuid AND row_version = 3;
    GET DIAGNOSTICS affected = ROW_COUNT;
    IF affected <> 1 OR (SELECT row_version FROM public.firms WHERE id = firm_uuid) <> 4 THEN
        RAISE EXCEPTION 'settings update failed';
    END IF;

    UPDATE public.firms SET is_active = false WHERE id = firm_uuid AND row_version = 4;
    GET DIAGNOSTICS affected = ROW_COUNT;
    IF affected <> 1 OR (SELECT is_active FROM public.firms WHERE id = firm_uuid) THEN
        RAISE EXCEPTION 'soft deactivation failed';
    END IF;

    UPDATE public.firms SET is_active = true WHERE id = firm_uuid AND row_version = 5;
    GET DIAGNOSTICS affected = ROW_COUNT;
    IF affected <> 1 OR NOT (SELECT is_active FROM public.firms WHERE id = firm_uuid) THEN
        RAISE EXCEPTION 'activation failed';
    END IF;

    SELECT name INTO before_name FROM public.firms WHERE id = firm_uuid;
    BEGIN
        UPDATE public.firms SET name = 'Must Roll Back' WHERE id = firm_uuid;
        INSERT INTO public.audit_log (firm_id, entity_type, entity_id, action)
        VALUES (firm_uuid, NULL, firm_uuid, 'invalid.audit');
    EXCEPTION WHEN not_null_violation THEN
        NULL;
    END;
    IF (SELECT name FROM public.firms WHERE id = firm_uuid) IS DISTINCT FROM before_name THEN
        RAISE EXCEPTION 'audit failure did not roll back its firm mutation';
    END IF;
END
$$;

ROLLBACK;

SELECT 'firm command disposable behavior verified' AS result;
