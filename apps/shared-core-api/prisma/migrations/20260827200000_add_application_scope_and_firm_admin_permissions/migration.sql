BEGIN;

CREATE TEMPORARY TABLE expected_permission_scopes (
    permission_id uuid PRIMARY KEY,
    application_code varchar(50) NOT NULL,
    permission_code varchar(100) NOT NULL,
    scope_type varchar(20) NOT NULL
) ON COMMIT DROP;

INSERT INTO expected_permission_scopes VALUES
    ('e03cdcb8-960d-4fbe-bce8-4999994e35df', 'ACCOUNTING', 'documents.create', 'FIRM'),
    ('af0cdf3f-1078-4f3a-a860-cff46befbe3b', 'ACCOUNTING', 'documents.delete', 'FIRM'),
    ('2ccd8982-f41b-470e-b7b3-c34bc2c9016f', 'ACCOUNTING', 'documents.edit', 'FIRM'),
    ('1888d5f7-3584-4f5f-912d-6c7ad253071f', 'ACCOUNTING', 'documents.view', 'FIRM'),
    ('8a7d969a-ffa2-4284-8270-0b499ca54ef8', 'ACCOUNTING', 'import.execute', 'FIRM'),
    ('321f2fdd-67d4-453d-b30d-d0ba49ba2cd8', 'ACCOUNTING', 'journal.create', 'FIRM'),
    ('f6f83cb3-bb0e-40e6-af3e-9412c83e8463', 'ACCOUNTING', 'journal.delete_draft', 'FIRM'),
    ('4b3113ff-2faa-4751-8b30-f4af8c2fc9de', 'ACCOUNTING', 'journal.delete_posted', 'FIRM'),
    ('2d0d4cb3-07ef-4e8c-8347-75caafa8fb7f', 'ACCOUNTING', 'journal.edit_draft', 'FIRM'),
    ('d502c180-48af-49fb-a199-03a8a8e4adca', 'ACCOUNTING', 'journal.edit_posted', 'FIRM'),
    ('e6a011c4-90bb-42ce-9db8-73f39afdfc5d', 'ACCOUNTING', 'journal.post', 'FIRM'),
    ('b2ed2fd8-27b1-4660-a2fb-48e1c2c9452b', 'ACCOUNTING', 'journal.reverse', 'FIRM'),
    ('50a83d00-e8de-4730-a936-bd5e52e955d1', 'ACCOUNTING', 'period.close', 'FIRM'),
    ('086731d5-8305-40e2-9278-cf6d758ff0e9', 'ACCOUNTING', 'period.lock', 'FIRM'),
    ('3603a36b-8fff-40dd-95ee-fadf13e0d6de', 'ACCOUNTING', 'period.reopen', 'FIRM'),
    ('bcf1aae9-ef3a-4c84-a086-e9df1158cd18', 'ACCOUNTING', 'period.unlock', 'FIRM'),
    ('dabfb333-be22-4719-856e-5fbba6b454a7', 'ACCOUNTING', 'settlement.create', 'FIRM'),
    ('c364fd01-230c-4b67-8dfe-6cc369b8f98d', 'ACCOUNTING', 'settlement.delete', 'FIRM'),
    ('9e0005a0-6e65-4bef-8e92-9374cffd9ab0', 'ACCOUNTING', 'settlement.edit', 'FIRM'),
    ('ce279eb1-dd55-4650-870f-12b9b3bed28b', 'ACCOUNTING', 'vat.correct', 'FIRM'),
    ('b1f493f4-0e0b-4643-b2a3-d9a1288d6cde', 'ACCOUNTING', 'vat.finalize', 'FIRM'),
    ('31a001eb-2ec5-4043-ab42-03ab6f09b450', 'ACCOUNTING', 'vat.generate', 'FIRM'),
    ('3865add7-702c-45c6-8b5e-e56544347122', 'ACCOUNTING', 'vat.reopen', 'FIRM'),
    ('81196288-ba6e-5f15-96d3-068a00672c9b', 'OFFICE', 'access.manage', 'FIRM'),
    ('2a0bf1d6-2799-55c9-b119-86c350454407', 'OFFICE', 'access.view', 'FIRM'),
    ('86a59bee-ac70-5112-87fd-b826e014d9f3', 'OFFICE', 'accounting_proposal.edit', 'FIRM'),
    ('cb964fc8-3906-5ecd-a47a-2f0497deaf5e', 'OFFICE', 'accounting_proposal.view', 'FIRM'),
    ('23d80816-53d3-5c94-b485-4b449586e670', 'OFFICE', 'applications.manage', 'FIRM'),
    ('149a0275-cf93-5156-b01d-e7b7e80f1dc6', 'OFFICE', 'applications.view', 'FIRM'),
    ('3bf2017e-9c80-5f37-87ba-70a50b51c733', 'OFFICE', 'archive.download', 'FIRM'),
    ('44542aec-2b4d-5d4f-a62b-ee10ea34ef40', 'OFFICE', 'archive.metadata.edit', 'FIRM'),
    ('4ec49d85-a755-55d9-823c-3909ee42d5d4', 'OFFICE', 'archive.restore', 'FIRM'),
    ('094f7727-5ba8-5c95-b7e1-e4399a56044a', 'OFFICE', 'archive.search', 'FIRM'),
    ('800c8b50-8100-59a5-92a1-a28fdebf46a4', 'OFFICE', 'archive.view', 'FIRM'),
    ('ba6ec369-4ffe-54b3-92a5-d6325c48dc10', 'OFFICE', 'automations.manage', 'FIRM'),
    ('f53fbe8c-a8c2-52a8-96fe-6aea20629132', 'OFFICE', 'automations.retry', 'FIRM'),
    ('31e398bd-3444-5698-8148-c4eab1c509a3', 'OFFICE', 'automations.run_manual', 'FIRM'),
    ('a1ea7a4f-b04d-5d92-82b4-6ea69b449193', 'OFFICE', 'automations.view', 'FIRM'),
    ('fd634bb0-9b0f-514c-93eb-1ab7b4813209', 'OFFICE', 'documents.delete', 'FIRM'),
    ('3390fed7-1b73-5ac3-a6bd-e3b66be4b37f', 'OFFICE', 'documents.download', 'FIRM'),
    ('501f880e-d153-5c3a-a732-e789da5cc342', 'OFFICE', 'documents.edit', 'FIRM'),
    ('ca239860-5a48-5e5f-bfce-3b455c3027cf', 'OFFICE', 'documents.replace_file', 'FIRM'),
    ('fd151e39-4755-5cee-aa5a-1f4addc3186d', 'OFFICE', 'documents.upload', 'FIRM'),
    ('9c681667-67f5-5739-9730-89e3802c6d6e', 'OFFICE', 'documents.view', 'FIRM'),
    ('68b2b8f7-e6be-5480-9929-dc0bfc9de9ae', 'OFFICE', 'firms.edit', 'FIRM'),
    ('4cd7afa0-72bc-51e1-9e24-43e679cfe4c4', 'OFFICE', 'firms.settings.edit', 'FIRM'),
    ('ddaf0517-7518-5e4e-bae9-92df6c869e61', 'OFFICE', 'firms.settings.view', 'FIRM'),
    ('a7dfa16f-30ce-5301-8e01-74bdb33315c4', 'OFFICE', 'firms.view', 'FIRM'),
    ('5bb2b199-a0b6-591a-95e2-7b326deaa78b', 'OFFICE', 'intake.channels.manage', 'FIRM'),
    ('645b9ff0-cbce-507e-af0b-98ca406a1514', 'OFFICE', 'intake.channels.view', 'FIRM'),
    ('9736cfef-02be-5df0-9597-2f96158c2033', 'OFFICE', 'intake.reject', 'FIRM'),
    ('593fe4a3-c07d-5282-8612-bd641d23111e', 'OFFICE', 'intake.retry', 'FIRM'),
    ('d2b8a7a2-7c8b-5952-98b8-da42478c9683', 'OFFICE', 'intake.submit', 'FIRM'),
    ('ef89b2d5-fc64-5959-87f4-4c257d01caa8', 'OFFICE', 'intake.view', 'FIRM'),
    ('ba6cd54b-2179-5eae-98ff-aa7224990caf', 'OFFICE', 'integrations.manage', 'FIRM'),
    ('8b787f0b-0101-54ff-a849-7128b0372fc7', 'OFFICE', 'integrations.view', 'FIRM'),
    ('bc332c3b-d58f-5747-93b7-43f582724cf7', 'OFFICE', 'permissions.manage', 'FIRM'),
    ('544a8d1d-3a32-5f9f-b7d0-c08af6a11a4e', 'OFFICE', 'permissions.view', 'FIRM'),
    ('b6e18b3d-5388-5e98-a3c8-4309ab4dde57', 'OFFICE', 'processing.ai_proposal.edit', 'FIRM'),
    ('9836aa70-98cb-5a4e-b73b-2f8a390a7328', 'OFFICE', 'processing.ai_proposal.view', 'FIRM'),
    ('bfcc58f2-2e4e-58da-a7de-246443b8c527', 'OFFICE', 'processing.classification.edit', 'FIRM'),
    ('406547ed-c6e5-5b16-ada5-b595d5fcc420', 'OFFICE', 'processing.extraction.edit', 'FIRM'),
    ('d1364b4d-67f8-5cd3-8bd3-44cae3c91fed', 'OFFICE', 'processing.reprocess', 'FIRM'),
    ('93da0326-559d-5c40-ba1a-a43dddcc229d', 'OFFICE', 'processing.view', 'FIRM'),
    ('742bb0e8-2b74-53ad-9725-ec5bf3507f02', 'OFFICE', 'review.approve', 'FIRM'),
    ('029d44f8-94cb-5d94-8726-5810c89187c5', 'OFFICE', 'review.edit', 'FIRM'),
    ('dccfddf8-7634-568c-9559-40ad9ea42a25', 'OFFICE', 'review.reassign', 'FIRM'),
    ('5244b5ea-db10-5200-be2b-affde5bb87b3', 'OFFICE', 'review.request_client_action', 'FIRM'),
    ('a6e1908c-bfcb-54e2-a0ae-56cb190a92c1', 'OFFICE', 'review.return_internal', 'FIRM'),
    ('acf3546a-5544-5e2f-a4f3-f34f9dd870c3', 'OFFICE', 'review.start', 'FIRM'),
    ('0fb98d73-3a1a-5617-8a6c-5b11b6de1794', 'OFFICE', 'review.view', 'FIRM'),
    ('fe742e51-1932-595a-be76-5437bd373f8c', 'OFFICE', 'roles.manage', 'FIRM'),
    ('fa82bfa8-539a-5b90-bb6d-d2f3a21fd873', 'OFFICE', 'roles.view', 'FIRM'),
    ('e75ce885-c601-5468-a4ce-ac31885e96ad', 'OFFICE', 'routing.auto_send_policy.manage', 'FIRM'),
    ('7dd4a91e-a81f-5849-a082-c176c036c712', 'OFFICE', 'routing.for_posting', 'FIRM'),
    ('01528a4b-4373-529a-8396-f957d38f9153', 'OFFICE', 'routing.not_for_posting', 'FIRM'),
    ('90bac49d-0307-5244-950b-766dc6349545', 'OFFICE', 'routing.return', 'FIRM'),
    ('8607b368-113d-5323-bab7-11b7ec661ab3', 'OFFICE', 'routing.view', 'FIRM'),
    ('901187fd-fb34-5b49-b262-16192d695122', 'OFFICE', 'system.settings.manage', 'APPLICATION'),
    ('a176a3ba-65d4-546b-abd2-b3cfaa5c97c2', 'OFFICE', 'system.settings.view', 'APPLICATION'),
    ('5576f59f-38bf-5479-98cf-7a50cae218e8', 'OFFICE', 'tasks.assign', 'FIRM'),
    ('94d0fc41-00d4-5864-b929-3921d22108dc', 'OFFICE', 'tasks.complete', 'FIRM'),
    ('0dc138ee-3355-566c-9f76-325377b5bd3d', 'OFFICE', 'tasks.create', 'FIRM'),
    ('ab342265-119f-5737-98e3-07359dc1a416', 'OFFICE', 'tasks.deadline.edit', 'FIRM'),
    ('b372864d-efd1-5372-96e3-195b6e3f85ed', 'OFFICE', 'tasks.delete', 'FIRM'),
    ('fd200b46-17f4-5783-9310-feed83f58bdb', 'OFFICE', 'tasks.edit', 'FIRM'),
    ('71bd3edb-6040-50a4-9899-a0b0d1b06021', 'OFFICE', 'tasks.priority.edit', 'FIRM'),
    ('d4d69e4d-bd11-5ad2-b8e9-8d3c7ddfb6af', 'OFFICE', 'tasks.view', 'FIRM'),
    ('791d1ebf-97d5-51e9-bb91-d994ccd9e948', 'OFFICE', 'users.create', 'FIRM'),
    ('7bdf210b-7594-57c3-80dd-4df1e0b4e4a8', 'OFFICE', 'users.disable', 'FIRM'),
    ('a6e48d73-a975-5fca-ba14-eab9523f0cc5', 'OFFICE', 'users.edit', 'FIRM'),
    ('401899be-3d7a-57ea-8515-20d5956a300f', 'OFFICE', 'users.view', 'FIRM');

DO $$
DECLARE
    office_id constant uuid := '150251b2-58e1-4981-b05c-d8a9538786cc';
    accounting_id constant uuid := '8211ee99-1de8-47ab-abc3-4065950a5827';
BEGIN
    IF (SELECT count(*) FROM expected_permission_scopes) <> 92
       OR (SELECT count(*) FROM public.permissions) <> 92 THEN
        RAISE EXCEPTION 'Expected exactly 92 reviewed permissions';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.applications WHERE id = office_id AND code = 'OFFICE' AND is_active)
       OR NOT EXISTS (SELECT 1 FROM public.applications WHERE id = accounting_id AND code = 'ACCOUNTING' AND is_active)
       OR (SELECT count(*) FROM public.applications WHERE code IN ('OFFICE', 'ACCOUNTING')) <> 2 THEN
        RAISE EXCEPTION 'Reviewed OFFICE/ACCOUNTING application state differs';
    END IF;
    IF EXISTS (
        SELECT 1
        FROM expected_permission_scopes expected
        FULL JOIN public.permissions permission ON permission.id = expected.permission_id
        LEFT JOIN public.applications application ON application.id = permission.application_id
        WHERE expected.permission_id IS NULL OR permission.id IS NULL
           OR permission.code <> expected.permission_code
           OR application.code <> expected.application_code
    ) THEN
        RAISE EXCEPTION 'Permission UUID/code/application mapping drift detected';
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
           LEFT JOIN public.roles role ON role.id = expected.id AND role.code = expected.code AND role.is_active
           WHERE role.id IS NULL
       ) THEN
        RAISE EXCEPTION 'Reviewed role catalog drift detected';
    END IF;
    IF (SELECT count(*) FROM public.role_permissions) <> 297
       OR (SELECT md5(string_agg(id::text || '|' || role_id::text || '|' || permission_id::text || '|' || is_active::text, E'\n' ORDER BY id)) FROM public.role_permissions)
          <> '65515ce9e1982ca72f9d7c630bbf0381' THEN
        RAISE EXCEPTION 'Reviewed role-permission mapping drift detected';
    END IF;
    IF to_regclass('public.user_application_roles') IS NOT NULL THEN
        RAISE EXCEPTION 'user_application_roles already exists unexpectedly';
    END IF;
END
$$;

ALTER TABLE public.permissions ADD COLUMN scope_type varchar(20);

UPDATE public.permissions permission
SET scope_type = expected.scope_type
FROM expected_permission_scopes expected
WHERE permission.id = expected.permission_id;

ALTER TABLE public.permissions
    ALTER COLUMN scope_type SET NOT NULL,
    ADD CONSTRAINT permissions_scope_type_check CHECK (scope_type IN ('APPLICATION', 'FIRM'));

CREATE INDEX idx_permissions_application_scope_active
    ON public.permissions (application_id, scope_type, is_active);

CREATE TABLE public.user_application_roles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    application_id uuid NOT NULL,
    role_id uuid NOT NULL,
    valid_from date,
    valid_to date,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT user_application_roles_pkey PRIMARY KEY (id),
    CONSTRAINT user_application_roles_user_application_role_key UNIQUE (user_id, application_id, role_id),
    CONSTRAINT user_application_roles_dates_check CHECK (valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from),
    CONSTRAINT user_application_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
    CONSTRAINT user_application_roles_application_id_fkey FOREIGN KEY (application_id) REFERENCES public.applications(id),
    CONSTRAINT user_application_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id)
);

CREATE INDEX idx_user_application_roles_user_application_active
    ON public.user_application_roles (user_id, application_id, is_active);
CREATE INDEX idx_user_application_roles_role
    ON public.user_application_roles (role_id);
CREATE TRIGGER trg_user_application_roles_set_updated_at
    BEFORE UPDATE ON public.user_application_roles
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();

CREATE TEMPORARY TABLE new_office_permissions (
    id uuid PRIMARY KEY,
    code varchar(100) UNIQUE NOT NULL,
    scope_type varchar(20) NOT NULL
) ON COMMIT DROP;

INSERT INTO new_office_permissions VALUES
    ('605b2ef0-9e98-5c88-8b24-7e0c3b530829', 'firms.create', 'APPLICATION'),
    ('4368fead-a1cb-5223-bb90-e2d126844283', 'firms.catalog.view', 'APPLICATION'),
    ('694951ee-27fc-522f-a5c3-f5f2ffe83546', 'firms.activate', 'FIRM'),
    ('05828ad6-e419-5281-b4b2-986ab735c53d', 'firms.disable', 'FIRM'),
    ('87941717-4172-5d36-b69c-62e65a18486c', 'firms.identity.edit', 'FIRM');

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM new_office_permissions expected
        JOIN public.permissions permission
          ON permission.id = expected.id OR
             (permission.application_id = '150251b2-58e1-4981-b05c-d8a9538786cc' AND permission.code = expected.code)
    ) THEN
        RAISE EXCEPTION 'New Office permission UUID or code collision';
    END IF;
END
$$;

INSERT INTO public.permissions (id, application_id, code, name, scope_type)
SELECT id, '150251b2-58e1-4981-b05c-d8a9538786cc', code, code, scope_type
FROM new_office_permissions;

CREATE TEMPORARY TABLE new_office_role_permissions (
    id uuid PRIMARY KEY,
    role_code varchar(50) NOT NULL,
    permission_code varchar(100) NOT NULL
) ON COMMIT DROP;

INSERT INTO new_office_role_permissions VALUES
    ('353ac3f1-db94-56c6-8b4a-8182d5cc973c', 'admin', 'firms.create'),
    ('be84b838-589a-5628-83fe-edc6965eec64', 'manager', 'firms.create'),
    ('d84df150-0670-59ad-a5a5-46f8f84e6138', 'admin', 'firms.catalog.view'),
    ('2e4d5f14-f853-5143-88af-9ae895cb07ff', 'manager', 'firms.catalog.view'),
    ('3665b757-9342-5f81-abf0-9ad7284f306d', 'admin', 'firms.activate'),
    ('6fff5e5c-66b8-5746-83db-a64d6287cc24', 'manager', 'firms.activate'),
    ('50a0a328-92f5-5f6b-bcb4-28868d4b2e61', 'admin', 'firms.disable'),
    ('22bf93cd-4c9c-56b5-b0da-0f9482bc1a5b', 'admin', 'firms.identity.edit'),
    ('03d9a338-24a0-5251-866f-dc48d7ad9e7b', 'manager', 'firms.identity.edit');

INSERT INTO public.role_permissions (id, role_id, permission_id)
SELECT mapping.id, role.id, permission.id
FROM new_office_role_permissions mapping
JOIN public.roles role ON role.code = mapping.role_code AND role.is_active
JOIN public.permissions permission
  ON permission.application_id = '150251b2-58e1-4981-b05c-d8a9538786cc'
 AND permission.code = mapping.permission_code;

DO $$
BEGIN
    IF (SELECT count(*) FROM public.permissions) <> 97
       OR (SELECT count(*) FROM public.permissions WHERE application_id = '150251b2-58e1-4981-b05c-d8a9538786cc') <> 74
       OR (SELECT count(*) FROM public.permissions WHERE application_id = '8211ee99-1de8-47ab-abc3-4065950a5827') <> 23
       OR (SELECT count(*) FROM public.permissions WHERE scope_type IS NULL) <> 0
       OR (SELECT count(*) FROM public.role_permissions) <> 306
       OR (SELECT count(*) FROM public.role_permissions WHERE id IN (SELECT id FROM new_office_role_permissions)) <> 9 THEN
        RAISE EXCEPTION 'Post-migration catalog or role mapping verification failed';
    END IF;
    IF (SELECT count(*) FROM public.user_application_roles) <> 0 THEN
        RAISE EXCEPTION 'Migration created an application role assignment';
    END IF;
END
$$;

COMMIT;
