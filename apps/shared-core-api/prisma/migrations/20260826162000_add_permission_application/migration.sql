BEGIN;

CREATE TEMPORARY TABLE reviewed_permission_application_mapping (
    permission_id uuid PRIMARY KEY,
    permission_code character varying(100) NOT NULL UNIQUE,
    application_id uuid NOT NULL,
    application_code character varying(50) NOT NULL
) ON COMMIT DROP;

INSERT INTO reviewed_permission_application_mapping (
    permission_id,
    permission_code,
    application_id,
    application_code
)
VALUES
    ('e03cdcb8-960d-4fbe-bce8-4999994e35df', 'documents.create',       '8211ee99-1de8-47ab-abc3-4065950a5827', 'ACCOUNTING'),
    ('af0cdf3f-1078-4f3a-a860-cff46befbe3b', 'documents.delete',       '8211ee99-1de8-47ab-abc3-4065950a5827', 'ACCOUNTING'),
    ('2ccd8982-f41b-470e-b7b3-c34bc2c9016f', 'documents.edit',         '8211ee99-1de8-47ab-abc3-4065950a5827', 'ACCOUNTING'),
    ('1888d5f7-3584-4f5f-912d-6c7ad253071f', 'documents.view',         '8211ee99-1de8-47ab-abc3-4065950a5827', 'ACCOUNTING'),
    ('8a7d969a-ffa2-4284-8270-0b499ca54ef8', 'import.execute',          '8211ee99-1de8-47ab-abc3-4065950a5827', 'ACCOUNTING'),
    ('321f2fdd-67d4-453d-b30d-d0ba49ba2cd8', 'journal.create',         '8211ee99-1de8-47ab-abc3-4065950a5827', 'ACCOUNTING'),
    ('f6f83cb3-bb0e-40e6-af3e-9412c83e8463', 'journal.delete_draft',   '8211ee99-1de8-47ab-abc3-4065950a5827', 'ACCOUNTING'),
    ('4b3113ff-2faa-4751-8b30-f4af8c2fc9de', 'journal.delete_posted',  '8211ee99-1de8-47ab-abc3-4065950a5827', 'ACCOUNTING'),
    ('2d0d4cb3-07ef-4e8c-8347-75caafa8fb7f', 'journal.edit_draft',     '8211ee99-1de8-47ab-abc3-4065950a5827', 'ACCOUNTING'),
    ('d502c180-48af-49fb-a199-03a8a8e4adca', 'journal.edit_posted',    '8211ee99-1de8-47ab-abc3-4065950a5827', 'ACCOUNTING'),
    ('e6a011c4-90bb-42ce-9db8-73f39afdfc5d', 'journal.post',           '8211ee99-1de8-47ab-abc3-4065950a5827', 'ACCOUNTING'),
    ('b2ed2fd8-27b1-4660-a2fb-48e1c2c9452b', 'journal.reverse',        '8211ee99-1de8-47ab-abc3-4065950a5827', 'ACCOUNTING'),
    ('50a83d00-e8de-4730-a936-bd5e52e955d1', 'period.close',           '8211ee99-1de8-47ab-abc3-4065950a5827', 'ACCOUNTING'),
    ('086731d5-8305-40e2-9278-cf6d758ff0e9', 'period.lock',            '8211ee99-1de8-47ab-abc3-4065950a5827', 'ACCOUNTING'),
    ('3603a36b-8fff-40dd-95ee-fadf13e0d6de', 'period.reopen',          '8211ee99-1de8-47ab-abc3-4065950a5827', 'ACCOUNTING'),
    ('bcf1aae9-ef3a-4c84-a086-e9df1158cd18', 'period.unlock',          '8211ee99-1de8-47ab-abc3-4065950a5827', 'ACCOUNTING'),
    ('dabfb333-be22-4719-856e-5fbba6b454a7', 'settlement.create',      '8211ee99-1de8-47ab-abc3-4065950a5827', 'ACCOUNTING'),
    ('c364fd01-230c-4b67-8dfe-6cc369b8f98d', 'settlement.delete',      '8211ee99-1de8-47ab-abc3-4065950a5827', 'ACCOUNTING'),
    ('9e0005a0-6e65-4bef-8e92-9374cffd9ab0', 'settlement.edit',        '8211ee99-1de8-47ab-abc3-4065950a5827', 'ACCOUNTING'),
    ('ce279eb1-dd55-4650-870f-12b9b3bed28b', 'vat.correct',            '8211ee99-1de8-47ab-abc3-4065950a5827', 'ACCOUNTING'),
    ('b1f493f4-0e0b-4643-b2a3-d9a1288d6cde', 'vat.finalize',           '8211ee99-1de8-47ab-abc3-4065950a5827', 'ACCOUNTING'),
    ('31a001eb-2ec5-4043-ab42-03ab6f09b450', 'vat.generate',           '8211ee99-1de8-47ab-abc3-4065950a5827', 'ACCOUNTING'),
    ('3865add7-702c-45c6-8b5e-e56544347122', 'vat.reopen',             '8211ee99-1de8-47ab-abc3-4065950a5827', 'ACCOUNTING');

DO $$
DECLARE
    actual_permission_count integer;
    reviewed_mapping_count integer;
BEGIN
    SELECT count(*) INTO actual_permission_count
    FROM public.permissions;

    SELECT count(*) INTO reviewed_mapping_count
    FROM reviewed_permission_application_mapping;

    IF actual_permission_count <> 23 OR reviewed_mapping_count <> 23 THEN
        RAISE EXCEPTION
            'Expected exactly 23 permissions and 23 reviewed mappings; found % permissions and % mappings',
            actual_permission_count,
            reviewed_mapping_count;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.applications
        WHERE id = '8211ee99-1de8-47ab-abc3-4065950a5827'
          AND code = 'ACCOUNTING'
          AND is_active = true
    ) THEN
        RAISE EXCEPTION 'Expected active ACCOUNTING application UUID/code pair was not found';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM reviewed_permission_application_mapping
        WHERE application_id <> '8211ee99-1de8-47ab-abc3-4065950a5827'
           OR application_code <> 'ACCOUNTING'
    ) THEN
        RAISE EXCEPTION 'Every reviewed permission must map to the expected ACCOUNTING application';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM reviewed_permission_application_mapping mapping
        LEFT JOIN public.permissions permission
          ON permission.id = mapping.permission_id
         AND permission.code = mapping.permission_code
        WHERE permission.id IS NULL
    ) THEN
        RAISE EXCEPTION 'A reviewed permission UUID/code pair is missing or changed';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.permissions permission
        LEFT JOIN reviewed_permission_application_mapping mapping
          ON mapping.permission_id = permission.id
         AND mapping.permission_code = permission.code
        WHERE mapping.permission_id IS NULL
    ) THEN
        RAISE EXCEPTION 'An unexpected permission or changed UUID/code pair exists';
    END IF;
END;
$$;

ALTER TABLE public.permissions
    ADD COLUMN application_id uuid;

UPDATE public.permissions permission
SET application_id = mapping.application_id
FROM reviewed_permission_application_mapping mapping
WHERE permission.id = mapping.permission_id
  AND permission.code = mapping.permission_code;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM public.permissions
        WHERE application_id IS NULL
    ) THEN
        RAISE EXCEPTION 'One or more permissions remain without application ownership';
    END IF;
END;
$$;

ALTER TABLE public.permissions
    ALTER COLUMN application_id SET NOT NULL;

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_application_id_fkey
    FOREIGN KEY (application_id)
    REFERENCES public.applications(id);

CREATE INDEX idx_permissions_application_active
    ON public.permissions (application_id, is_active);

COMMIT;
