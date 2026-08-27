BEGIN;

CREATE TEMPORARY TABLE expected_accounting_permissions (
    permission_id uuid PRIMARY KEY,
    permission_code character varying(100) NOT NULL UNIQUE
) ON COMMIT DROP;

INSERT INTO expected_accounting_permissions (permission_id, permission_code)
VALUES
    ('e03cdcb8-960d-4fbe-bce8-4999994e35df', 'documents.create'),
    ('af0cdf3f-1078-4f3a-a860-cff46befbe3b', 'documents.delete'),
    ('2ccd8982-f41b-470e-b7b3-c34bc2c9016f', 'documents.edit'),
    ('1888d5f7-3584-4f5f-912d-6c7ad253071f', 'documents.view'),
    ('8a7d969a-ffa2-4284-8270-0b499ca54ef8', 'import.execute'),
    ('321f2fdd-67d4-453d-b30d-d0ba49ba2cd8', 'journal.create'),
    ('f6f83cb3-bb0e-40e6-af3e-9412c83e8463', 'journal.delete_draft'),
    ('4b3113ff-2faa-4751-8b30-f4af8c2fc9de', 'journal.delete_posted'),
    ('2d0d4cb3-07ef-4e8c-8347-75caafa8fb7f', 'journal.edit_draft'),
    ('d502c180-48af-49fb-a199-03a8a8e4adca', 'journal.edit_posted'),
    ('e6a011c4-90bb-42ce-9db8-73f39afdfc5d', 'journal.post'),
    ('b2ed2fd8-27b1-4660-a2fb-48e1c2c9452b', 'journal.reverse'),
    ('50a83d00-e8de-4730-a936-bd5e52e955d1', 'period.close'),
    ('086731d5-8305-40e2-9278-cf6d758ff0e9', 'period.lock'),
    ('3603a36b-8fff-40dd-95ee-fadf13e0d6de', 'period.reopen'),
    ('bcf1aae9-ef3a-4c84-a086-e9df1158cd18', 'period.unlock'),
    ('dabfb333-be22-4719-856e-5fbba6b454a7', 'settlement.create'),
    ('c364fd01-230c-4b67-8dfe-6cc369b8f98d', 'settlement.delete'),
    ('9e0005a0-6e65-4bef-8e92-9374cffd9ab0', 'settlement.edit'),
    ('ce279eb1-dd55-4650-870f-12b9b3bed28b', 'vat.correct'),
    ('b1f493f4-0e0b-4643-b2a3-d9a1288d6cde', 'vat.finalize'),
    ('31a001eb-2ec5-4043-ab42-03ab6f09b450', 'vat.generate'),
    ('3865add7-702c-45c6-8b5e-e56544347122', 'vat.reopen');

CREATE TEMPORARY TABLE expected_roles (
    role_id uuid PRIMARY KEY,
    role_code character varying(50) NOT NULL UNIQUE
) ON COMMIT DROP;

INSERT INTO expected_roles (role_id, role_code)
VALUES
    ('b13f6113-20e7-4f35-9711-5e4c9a7e4738', 'accountant'),
    ('f9cb0362-3cf2-4f55-814d-788c52016318', 'admin'),
    ('a920c985-595b-476c-8221-5815bf17c4fe', 'client_owner'),
    ('9ae73810-5674-4fee-8cd3-728558bcf532', 'client_staff'),
    ('af343e28-e831-4075-b057-602e68f248f6', 'manager'),
    ('396b6188-e76d-4d82-bb34-02810a285d1b', 'payroll'),
    ('0ce20ca9-ecc0-444c-9174-e5fb53e920d8', 'upload_only');

CREATE TEMPORARY TABLE reviewed_office_permissions (
    permission_id uuid PRIMARY KEY,
    permission_code character varying(100) NOT NULL UNIQUE,
    permission_name character varying(255) NOT NULL
) ON COMMIT DROP;

INSERT INTO reviewed_office_permissions (permission_id, permission_code, permission_name)
VALUES
    ('a7dfa16f-30ce-5301-8e01-74bdb33315c4', 'firms.view', 'firms.view'),
    ('68b2b8f7-e6be-5480-9929-dc0bfc9de9ae', 'firms.edit', 'firms.edit'),
    ('ddaf0517-7518-5e4e-bae9-92df6c869e61', 'firms.settings.view', 'firms.settings.view'),
    ('4cd7afa0-72bc-51e1-9e24-43e679cfe4c4', 'firms.settings.edit', 'firms.settings.edit'),
    ('d4d69e4d-bd11-5ad2-b8e9-8d3c7ddfb6af', 'tasks.view', 'tasks.view'),
    ('0dc138ee-3355-566c-9f76-325377b5bd3d', 'tasks.create', 'tasks.create'),
    ('fd200b46-17f4-5783-9310-feed83f58bdb', 'tasks.edit', 'tasks.edit'),
    ('5576f59f-38bf-5479-98cf-7a50cae218e8', 'tasks.assign', 'tasks.assign'),
    ('94d0fc41-00d4-5864-b929-3921d22108dc', 'tasks.complete', 'tasks.complete'),
    ('b372864d-efd1-5372-96e3-195b6e3f85ed', 'tasks.delete', 'tasks.delete'),
    ('71bd3edb-6040-50a4-9899-a0b0d1b06021', 'tasks.priority.edit', 'tasks.priority.edit'),
    ('ab342265-119f-5737-98e3-07359dc1a416', 'tasks.deadline.edit', 'tasks.deadline.edit'),
    ('9c681667-67f5-5739-9730-89e3802c6d6e', 'documents.view', 'documents.view'),
    ('fd151e39-4755-5cee-aa5a-1f4addc3186d', 'documents.upload', 'documents.upload'),
    ('3390fed7-1b73-5ac3-a6bd-e3b66be4b37f', 'documents.download', 'documents.download'),
    ('501f880e-d153-5c3a-a732-e789da5cc342', 'documents.edit', 'documents.edit'),
    ('ca239860-5a48-5e5f-bfce-3b455c3027cf', 'documents.replace_file', 'documents.replace_file'),
    ('fd634bb0-9b0f-514c-93eb-1ab7b4813209', 'documents.delete', 'documents.delete'),
    ('ef89b2d5-fc64-5959-87f4-4c257d01caa8', 'intake.view', 'intake.view'),
    ('d2b8a7a2-7c8b-5952-98b8-da42478c9683', 'intake.submit', 'intake.submit'),
    ('593fe4a3-c07d-5282-8612-bd641d23111e', 'intake.retry', 'intake.retry'),
    ('9736cfef-02be-5df0-9597-2f96158c2033', 'intake.reject', 'intake.reject'),
    ('645b9ff0-cbce-507e-af0b-98ca406a1514', 'intake.channels.view', 'intake.channels.view'),
    ('5bb2b199-a0b6-591a-95e2-7b326deaa78b', 'intake.channels.manage', 'intake.channels.manage'),
    ('93da0326-559d-5c40-ba1a-a43dddcc229d', 'processing.view', 'processing.view'),
    ('406547ed-c6e5-5b16-ada5-b595d5fcc420', 'processing.extraction.edit', 'processing.extraction.edit'),
    ('bfcc58f2-2e4e-58da-a7de-246443b8c527', 'processing.classification.edit', 'processing.classification.edit'),
    ('d1364b4d-67f8-5cd3-8bd3-44cae3c91fed', 'processing.reprocess', 'processing.reprocess'),
    ('9836aa70-98cb-5a4e-b73b-2f8a390a7328', 'processing.ai_proposal.view', 'processing.ai_proposal.view'),
    ('b6e18b3d-5388-5e98-a3c8-4309ab4dde57', 'processing.ai_proposal.edit', 'processing.ai_proposal.edit'),
    ('0fb98d73-3a1a-5617-8a6c-5b11b6de1794', 'review.view', 'review.view'),
    ('acf3546a-5544-5e2f-a4f3-f34f9dd870c3', 'review.start', 'review.start'),
    ('029d44f8-94cb-5d94-8726-5810c89187c5', 'review.edit', 'review.edit'),
    ('742bb0e8-2b74-53ad-9725-ec5bf3507f02', 'review.approve', 'review.approve'),
    ('a6e1908c-bfcb-54e2-a0ae-56cb190a92c1', 'review.return_internal', 'review.return_internal'),
    ('5244b5ea-db10-5200-be2b-affde5bb87b3', 'review.request_client_action', 'review.request_client_action'),
    ('dccfddf8-7634-568c-9559-40ad9ea42a25', 'review.reassign', 'review.reassign'),
    ('cb964fc8-3906-5ecd-a47a-2f0497deaf5e', 'accounting_proposal.view', 'accounting_proposal.view'),
    ('86a59bee-ac70-5112-87fd-b826e014d9f3', 'accounting_proposal.edit', 'accounting_proposal.edit'),
    ('8607b368-113d-5323-bab7-11b7ec661ab3', 'routing.view', 'routing.view'),
    ('7dd4a91e-a81f-5849-a082-c176c036c712', 'routing.for_posting', 'routing.for_posting'),
    ('01528a4b-4373-529a-8396-f957d38f9153', 'routing.not_for_posting', 'routing.not_for_posting'),
    ('90bac49d-0307-5244-950b-766dc6349545', 'routing.return', 'routing.return'),
    ('e75ce885-c601-5468-a4ce-ac31885e96ad', 'routing.auto_send_policy.manage', 'routing.auto_send_policy.manage'),
    ('800c8b50-8100-59a5-92a1-a28fdebf46a4', 'archive.view', 'archive.view'),
    ('3bf2017e-9c80-5f37-87ba-70a50b51c733', 'archive.download', 'archive.download'),
    ('094f7727-5ba8-5c95-b7e1-e4399a56044a', 'archive.search', 'archive.search'),
    ('44542aec-2b4d-5d4f-a62b-ee10ea34ef40', 'archive.metadata.edit', 'archive.metadata.edit'),
    ('4ec49d85-a755-55d9-823c-3909ee42d5d4', 'archive.restore', 'archive.restore'),
    ('8b787f0b-0101-54ff-a849-7128b0372fc7', 'integrations.view', 'integrations.view'),
    ('ba6cd54b-2179-5eae-98ff-aa7224990caf', 'integrations.manage', 'integrations.manage'),
    ('a1ea7a4f-b04d-5d92-82b4-6ea69b449193', 'automations.view', 'automations.view'),
    ('ba6ec369-4ffe-54b3-92a5-d6325c48dc10', 'automations.manage', 'automations.manage'),
    ('31e398bd-3444-5698-8148-c4eab1c509a3', 'automations.run_manual', 'automations.run_manual'),
    ('f53fbe8c-a8c2-52a8-96fe-6aea20629132', 'automations.retry', 'automations.retry'),
    ('401899be-3d7a-57ea-8515-20d5956a300f', 'users.view', 'users.view'),
    ('791d1ebf-97d5-51e9-bb91-d994ccd9e948', 'users.create', 'users.create'),
    ('a6e48d73-a975-5fca-ba14-eab9523f0cc5', 'users.edit', 'users.edit'),
    ('7bdf210b-7594-57c3-80dd-4df1e0b4e4a8', 'users.disable', 'users.disable'),
    ('2a0bf1d6-2799-55c9-b119-86c350454407', 'access.view', 'access.view'),
    ('81196288-ba6e-5f15-96d3-068a00672c9b', 'access.manage', 'access.manage'),
    ('fa82bfa8-539a-5b90-bb6d-d2f3a21fd873', 'roles.view', 'roles.view'),
    ('fe742e51-1932-595a-be76-5437bd373f8c', 'roles.manage', 'roles.manage'),
    ('544a8d1d-3a32-5f9f-b7d0-c08af6a11a4e', 'permissions.view', 'permissions.view'),
    ('bc332c3b-d58f-5747-93b7-43f582724cf7', 'permissions.manage', 'permissions.manage'),
    ('149a0275-cf93-5156-b01d-e7b7e80f1dc6', 'applications.view', 'applications.view'),
    ('23d80816-53d3-5c94-b485-4b449586e670', 'applications.manage', 'applications.manage'),
    ('a176a3ba-65d4-546b-abd2-b3cfaa5c97c2', 'system.settings.view', 'system.settings.view'),
    ('901187fd-fb34-5b49-b262-16192d695122', 'system.settings.manage', 'system.settings.manage');

CREATE TEMPORARY TABLE reviewed_office_role_permissions (
    role_permission_id uuid PRIMARY KEY,
    role_id uuid NOT NULL,
    permission_id uuid NOT NULL,
    role_code character varying(50) NOT NULL,
    permission_code character varying(100) NOT NULL,
    UNIQUE (role_id, permission_id)
) ON COMMIT DROP;

INSERT INTO reviewed_office_role_permissions (
    role_permission_id,
    role_id,
    permission_id,
    role_code,
    permission_code
)
VALUES
    ('dc3cdb1a-4170-5701-9992-c805137899a9', 'f9cb0362-3cf2-4f55-814d-788c52016318', 'a7dfa16f-30ce-5301-8e01-74bdb33315c4', 'admin', 'firms.view'),
    ('9b183dd6-ae3f-5498-84d1-e7ed79cf580e', 'af343e28-e831-4075-b057-602e68f248f6', 'a7dfa16f-30ce-5301-8e01-74bdb33315c4', 'manager', 'firms.view'),
    ('88afbb01-c4cf-5336-b97d-366619d77c41', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', 'a7dfa16f-30ce-5301-8e01-74bdb33315c4', 'accountant', 'firms.view'),
    ('8fd27b9e-8d75-58b9-a313-bc1124219ab6', '396b6188-e76d-4d82-bb34-02810a285d1b', 'a7dfa16f-30ce-5301-8e01-74bdb33315c4', 'payroll', 'firms.view'),
    ('959e05e9-5e48-522b-b762-374ab67d6e6b', 'a920c985-595b-476c-8221-5815bf17c4fe', 'a7dfa16f-30ce-5301-8e01-74bdb33315c4', 'client_owner', 'firms.view'),
    ('f08bb55d-6d6e-5ada-bfb8-295867d99126', '9ae73810-5674-4fee-8cd3-728558bcf532', 'a7dfa16f-30ce-5301-8e01-74bdb33315c4', 'client_staff', 'firms.view'),
    ('70e50813-f7b0-56ac-ab56-db9c5ea5645d', 'f9cb0362-3cf2-4f55-814d-788c52016318', '68b2b8f7-e6be-5480-9929-dc0bfc9de9ae', 'admin', 'firms.edit'),
    ('ce5bb59b-83cc-514d-a0cd-fe16db1df9f8', 'af343e28-e831-4075-b057-602e68f248f6', '68b2b8f7-e6be-5480-9929-dc0bfc9de9ae', 'manager', 'firms.edit'),
    ('d88c14fd-3ac4-5b7a-b958-7585c2463b75', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '68b2b8f7-e6be-5480-9929-dc0bfc9de9ae', 'accountant', 'firms.edit'),
    ('6ee38735-b399-5abf-96db-bd30e787a256', '396b6188-e76d-4d82-bb34-02810a285d1b', '68b2b8f7-e6be-5480-9929-dc0bfc9de9ae', 'payroll', 'firms.edit'),
    ('80cea06a-3fd6-57f0-9bfd-cc4bdd632e04', 'a920c985-595b-476c-8221-5815bf17c4fe', '68b2b8f7-e6be-5480-9929-dc0bfc9de9ae', 'client_owner', 'firms.edit'),
    ('ec75e096-f778-506c-a359-9337acd831d0', '9ae73810-5674-4fee-8cd3-728558bcf532', '68b2b8f7-e6be-5480-9929-dc0bfc9de9ae', 'client_staff', 'firms.edit'),
    ('1f8093c6-cf15-5a38-b8de-e7e4b22b595e', 'f9cb0362-3cf2-4f55-814d-788c52016318', 'ddaf0517-7518-5e4e-bae9-92df6c869e61', 'admin', 'firms.settings.view'),
    ('7fd998e0-eb81-5705-809c-d0391f3f2b60', 'af343e28-e831-4075-b057-602e68f248f6', 'ddaf0517-7518-5e4e-bae9-92df6c869e61', 'manager', 'firms.settings.view'),
    ('2666278e-55d0-5822-8489-348a101ed33d', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', 'ddaf0517-7518-5e4e-bae9-92df6c869e61', 'accountant', 'firms.settings.view'),
    ('78e59079-df60-5945-8e02-a0077068afa6', '396b6188-e76d-4d82-bb34-02810a285d1b', 'ddaf0517-7518-5e4e-bae9-92df6c869e61', 'payroll', 'firms.settings.view'),
    ('71840fc9-bdc1-53f8-9885-7e841404cb42', 'a920c985-595b-476c-8221-5815bf17c4fe', 'ddaf0517-7518-5e4e-bae9-92df6c869e61', 'client_owner', 'firms.settings.view'),
    ('17764a25-a12b-54b7-92e3-ce57ac34287a', 'f9cb0362-3cf2-4f55-814d-788c52016318', '4cd7afa0-72bc-51e1-9e24-43e679cfe4c4', 'admin', 'firms.settings.edit'),
    ('9943aa34-5645-5145-b152-3f72e07e6833', 'af343e28-e831-4075-b057-602e68f248f6', '4cd7afa0-72bc-51e1-9e24-43e679cfe4c4', 'manager', 'firms.settings.edit'),
    ('4c36e793-d770-557d-835a-741709ba96af', 'f9cb0362-3cf2-4f55-814d-788c52016318', 'd4d69e4d-bd11-5ad2-b8e9-8d3c7ddfb6af', 'admin', 'tasks.view'),
    ('06186b02-cac7-5930-a55d-becdb6fa9e87', 'af343e28-e831-4075-b057-602e68f248f6', 'd4d69e4d-bd11-5ad2-b8e9-8d3c7ddfb6af', 'manager', 'tasks.view'),
    ('00eb26f0-d746-5ab4-b219-116647463ee9', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', 'd4d69e4d-bd11-5ad2-b8e9-8d3c7ddfb6af', 'accountant', 'tasks.view'),
    ('fb26bb0c-9607-5e68-937c-045607b93f37', '396b6188-e76d-4d82-bb34-02810a285d1b', 'd4d69e4d-bd11-5ad2-b8e9-8d3c7ddfb6af', 'payroll', 'tasks.view'),
    ('1fd13b19-e174-59bf-a6b0-3d513c773c01', 'a920c985-595b-476c-8221-5815bf17c4fe', 'd4d69e4d-bd11-5ad2-b8e9-8d3c7ddfb6af', 'client_owner', 'tasks.view'),
    ('aba28138-2911-503a-8d49-d413b3d86b49', '9ae73810-5674-4fee-8cd3-728558bcf532', 'd4d69e4d-bd11-5ad2-b8e9-8d3c7ddfb6af', 'client_staff', 'tasks.view'),
    ('a089aeb2-c36b-57c1-a974-738ea10c7cc8', 'f9cb0362-3cf2-4f55-814d-788c52016318', '0dc138ee-3355-566c-9f76-325377b5bd3d', 'admin', 'tasks.create'),
    ('abf4a3d3-5fac-5910-a5a5-eeca27c05267', 'af343e28-e831-4075-b057-602e68f248f6', '0dc138ee-3355-566c-9f76-325377b5bd3d', 'manager', 'tasks.create'),
    ('8c6cb4f1-55d7-59ee-9bb0-389156e3ed31', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '0dc138ee-3355-566c-9f76-325377b5bd3d', 'accountant', 'tasks.create'),
    ('3256e648-c763-5ec1-a491-78ba14ddf9b5', '396b6188-e76d-4d82-bb34-02810a285d1b', '0dc138ee-3355-566c-9f76-325377b5bd3d', 'payroll', 'tasks.create'),
    ('10a32329-8c7a-5b8d-93e4-d9e8c5c115b4', 'a920c985-595b-476c-8221-5815bf17c4fe', '0dc138ee-3355-566c-9f76-325377b5bd3d', 'client_owner', 'tasks.create'),
    ('47647cfd-2154-5867-9f9d-df853f400f1c', '9ae73810-5674-4fee-8cd3-728558bcf532', '0dc138ee-3355-566c-9f76-325377b5bd3d', 'client_staff', 'tasks.create'),
    ('107d1e3f-b0e4-581b-bc1d-bac0b09f992c', 'f9cb0362-3cf2-4f55-814d-788c52016318', 'fd200b46-17f4-5783-9310-feed83f58bdb', 'admin', 'tasks.edit'),
    ('bd1efa27-07b3-52fa-90a1-23b9e417a29d', 'af343e28-e831-4075-b057-602e68f248f6', 'fd200b46-17f4-5783-9310-feed83f58bdb', 'manager', 'tasks.edit'),
    ('da781247-1139-5d8f-ae95-ac79d111190c', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', 'fd200b46-17f4-5783-9310-feed83f58bdb', 'accountant', 'tasks.edit'),
    ('e3945cc2-c82d-551d-bd65-b7abceff5bb3', '396b6188-e76d-4d82-bb34-02810a285d1b', 'fd200b46-17f4-5783-9310-feed83f58bdb', 'payroll', 'tasks.edit'),
    ('eece078a-f7a5-5b5f-99de-c32bde3386bb', 'a920c985-595b-476c-8221-5815bf17c4fe', 'fd200b46-17f4-5783-9310-feed83f58bdb', 'client_owner', 'tasks.edit'),
    ('6df425eb-b2a9-5b24-9ce8-8c197832999b', '9ae73810-5674-4fee-8cd3-728558bcf532', 'fd200b46-17f4-5783-9310-feed83f58bdb', 'client_staff', 'tasks.edit'),
    ('612757e7-a620-5731-8e68-eafebf95637c', 'f9cb0362-3cf2-4f55-814d-788c52016318', '5576f59f-38bf-5479-98cf-7a50cae218e8', 'admin', 'tasks.assign'),
    ('ef40b083-c011-5a11-8bcd-ed9bc2c26d1e', 'af343e28-e831-4075-b057-602e68f248f6', '5576f59f-38bf-5479-98cf-7a50cae218e8', 'manager', 'tasks.assign'),
    ('3c431618-1612-544a-8ad1-8f4c1c18ed9b', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '5576f59f-38bf-5479-98cf-7a50cae218e8', 'accountant', 'tasks.assign'),
    ('cd0fde08-30d6-51df-8bdb-60ccaa47ae20', '396b6188-e76d-4d82-bb34-02810a285d1b', '5576f59f-38bf-5479-98cf-7a50cae218e8', 'payroll', 'tasks.assign'),
    ('2812b1c8-60a6-587b-8d7f-3a4f77c5ee6e', 'a920c985-595b-476c-8221-5815bf17c4fe', '5576f59f-38bf-5479-98cf-7a50cae218e8', 'client_owner', 'tasks.assign'),
    ('7732fd81-d2c7-535f-897a-eec0cc64f8d8', 'f9cb0362-3cf2-4f55-814d-788c52016318', '94d0fc41-00d4-5864-b929-3921d22108dc', 'admin', 'tasks.complete'),
    ('56350cd3-c87c-5ce0-a7ff-a11a33d43546', 'af343e28-e831-4075-b057-602e68f248f6', '94d0fc41-00d4-5864-b929-3921d22108dc', 'manager', 'tasks.complete'),
    ('b18c8dba-5c7d-53d0-8716-27f87f3d8950', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '94d0fc41-00d4-5864-b929-3921d22108dc', 'accountant', 'tasks.complete'),
    ('6b5cb176-7cd1-50be-bde5-2ba75b8a37ab', '396b6188-e76d-4d82-bb34-02810a285d1b', '94d0fc41-00d4-5864-b929-3921d22108dc', 'payroll', 'tasks.complete'),
    ('e2ab44f9-3228-55a8-b550-aff9f1ac46e6', 'a920c985-595b-476c-8221-5815bf17c4fe', '94d0fc41-00d4-5864-b929-3921d22108dc', 'client_owner', 'tasks.complete'),
    ('a30f9f74-f0f3-57a2-8d6c-2f5be4e7b7fd', '9ae73810-5674-4fee-8cd3-728558bcf532', '94d0fc41-00d4-5864-b929-3921d22108dc', 'client_staff', 'tasks.complete'),
    ('28dc8bf1-fffa-5618-a939-7e33140e7014', 'f9cb0362-3cf2-4f55-814d-788c52016318', 'b372864d-efd1-5372-96e3-195b6e3f85ed', 'admin', 'tasks.delete'),
    ('3ce81252-632a-52a1-85ac-aa6e43d134d1', 'af343e28-e831-4075-b057-602e68f248f6', 'b372864d-efd1-5372-96e3-195b6e3f85ed', 'manager', 'tasks.delete'),
    ('efcc5974-fa7b-52c9-ac56-b1c26bb7960e', 'f9cb0362-3cf2-4f55-814d-788c52016318', '71bd3edb-6040-50a4-9899-a0b0d1b06021', 'admin', 'tasks.priority.edit'),
    ('79eb54b3-cf5e-5f38-9d77-7c125a5a150f', 'af343e28-e831-4075-b057-602e68f248f6', '71bd3edb-6040-50a4-9899-a0b0d1b06021', 'manager', 'tasks.priority.edit'),
    ('4c429d47-9535-593d-9747-5e2bacd37f60', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '71bd3edb-6040-50a4-9899-a0b0d1b06021', 'accountant', 'tasks.priority.edit'),
    ('a668b836-2874-5f03-9a3d-3951000c6de0', '396b6188-e76d-4d82-bb34-02810a285d1b', '71bd3edb-6040-50a4-9899-a0b0d1b06021', 'payroll', 'tasks.priority.edit'),
    ('c24960ab-7c47-504a-809d-8c77420a3ed0', 'a920c985-595b-476c-8221-5815bf17c4fe', '71bd3edb-6040-50a4-9899-a0b0d1b06021', 'client_owner', 'tasks.priority.edit'),
    ('18b45a3d-053e-566e-8f34-1c30446caa2e', 'f9cb0362-3cf2-4f55-814d-788c52016318', 'ab342265-119f-5737-98e3-07359dc1a416', 'admin', 'tasks.deadline.edit'),
    ('96c11bd7-4964-57c4-b4c2-460280059c2e', 'af343e28-e831-4075-b057-602e68f248f6', 'ab342265-119f-5737-98e3-07359dc1a416', 'manager', 'tasks.deadline.edit'),
    ('035e128e-7c2e-5600-8066-02ceea94ae64', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', 'ab342265-119f-5737-98e3-07359dc1a416', 'accountant', 'tasks.deadline.edit'),
    ('130241f7-1a79-5d53-b2a5-55c8ef75901e', '396b6188-e76d-4d82-bb34-02810a285d1b', 'ab342265-119f-5737-98e3-07359dc1a416', 'payroll', 'tasks.deadline.edit'),
    ('b74e7d18-d8c2-5562-ab6c-87b62dc3b608', 'a920c985-595b-476c-8221-5815bf17c4fe', 'ab342265-119f-5737-98e3-07359dc1a416', 'client_owner', 'tasks.deadline.edit'),
    ('de6318a5-f0ab-58b2-9f95-f6c80080ed1f', 'f9cb0362-3cf2-4f55-814d-788c52016318', '9c681667-67f5-5739-9730-89e3802c6d6e', 'admin', 'documents.view'),
    ('ecccb788-b6fa-5aa9-8e85-07baeaa9a751', 'af343e28-e831-4075-b057-602e68f248f6', '9c681667-67f5-5739-9730-89e3802c6d6e', 'manager', 'documents.view'),
    ('80902e82-5b3a-5455-86b6-3aa98fa04e8a', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '9c681667-67f5-5739-9730-89e3802c6d6e', 'accountant', 'documents.view'),
    ('f67b298d-78e6-5d0b-baf7-049ca5417fac', '396b6188-e76d-4d82-bb34-02810a285d1b', '9c681667-67f5-5739-9730-89e3802c6d6e', 'payroll', 'documents.view'),
    ('e7d75a67-08e4-555a-99cf-0a3a70573bdd', 'a920c985-595b-476c-8221-5815bf17c4fe', '9c681667-67f5-5739-9730-89e3802c6d6e', 'client_owner', 'documents.view'),
    ('abb85b63-e7ff-5315-a25d-c18a33b6a83a', '9ae73810-5674-4fee-8cd3-728558bcf532', '9c681667-67f5-5739-9730-89e3802c6d6e', 'client_staff', 'documents.view'),
    ('b9f0a256-025a-59cb-96d1-067b084154d3', '0ce20ca9-ecc0-444c-9174-e5fb53e920d8', '9c681667-67f5-5739-9730-89e3802c6d6e', 'upload_only', 'documents.view'),
    ('42d09717-007a-54ea-b549-ab762d81ebac', 'f9cb0362-3cf2-4f55-814d-788c52016318', 'fd151e39-4755-5cee-aa5a-1f4addc3186d', 'admin', 'documents.upload'),
    ('13be7db1-03ab-5083-9eae-fc3c82b521ac', 'af343e28-e831-4075-b057-602e68f248f6', 'fd151e39-4755-5cee-aa5a-1f4addc3186d', 'manager', 'documents.upload'),
    ('f702464c-e3c4-5f8b-adea-1e574b4ac3a8', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', 'fd151e39-4755-5cee-aa5a-1f4addc3186d', 'accountant', 'documents.upload'),
    ('21e7a85f-ab65-5c6b-97d5-026406418df4', '396b6188-e76d-4d82-bb34-02810a285d1b', 'fd151e39-4755-5cee-aa5a-1f4addc3186d', 'payroll', 'documents.upload'),
    ('0482b8c4-26c6-57e5-9f5e-a2e772c94785', 'a920c985-595b-476c-8221-5815bf17c4fe', 'fd151e39-4755-5cee-aa5a-1f4addc3186d', 'client_owner', 'documents.upload'),
    ('74877e74-2f93-5a83-a4c1-11b184651ad4', '9ae73810-5674-4fee-8cd3-728558bcf532', 'fd151e39-4755-5cee-aa5a-1f4addc3186d', 'client_staff', 'documents.upload'),
    ('9bcc651c-cd22-5511-a0a5-3798aab7bd40', '0ce20ca9-ecc0-444c-9174-e5fb53e920d8', 'fd151e39-4755-5cee-aa5a-1f4addc3186d', 'upload_only', 'documents.upload'),
    ('b5f6ee8a-e50a-598c-9f24-9e1af68deefa', 'f9cb0362-3cf2-4f55-814d-788c52016318', '3390fed7-1b73-5ac3-a6bd-e3b66be4b37f', 'admin', 'documents.download'),
    ('c0b80100-2805-52fe-bd18-41ced4333212', 'af343e28-e831-4075-b057-602e68f248f6', '3390fed7-1b73-5ac3-a6bd-e3b66be4b37f', 'manager', 'documents.download'),
    ('d577c893-cc92-57be-a30c-896fdb674378', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '3390fed7-1b73-5ac3-a6bd-e3b66be4b37f', 'accountant', 'documents.download'),
    ('729b79a8-29e4-5ff2-a11c-3e2db77ae984', '396b6188-e76d-4d82-bb34-02810a285d1b', '3390fed7-1b73-5ac3-a6bd-e3b66be4b37f', 'payroll', 'documents.download'),
    ('3ef15d21-0e79-5f4a-b0ad-11d7366a0f86', 'a920c985-595b-476c-8221-5815bf17c4fe', '3390fed7-1b73-5ac3-a6bd-e3b66be4b37f', 'client_owner', 'documents.download'),
    ('15c1cbe1-ad6a-5343-aa00-2abc7e2531e3', '9ae73810-5674-4fee-8cd3-728558bcf532', '3390fed7-1b73-5ac3-a6bd-e3b66be4b37f', 'client_staff', 'documents.download'),
    ('b454799e-6701-51f2-b526-cba0b02a5a0d', '0ce20ca9-ecc0-444c-9174-e5fb53e920d8', '3390fed7-1b73-5ac3-a6bd-e3b66be4b37f', 'upload_only', 'documents.download'),
    ('5c160a5b-f42c-5f35-b291-75af09dc8221', 'f9cb0362-3cf2-4f55-814d-788c52016318', '501f880e-d153-5c3a-a732-e789da5cc342', 'admin', 'documents.edit'),
    ('2d40a3c3-551c-5ee3-8ca6-012b9bb98e22', 'af343e28-e831-4075-b057-602e68f248f6', '501f880e-d153-5c3a-a732-e789da5cc342', 'manager', 'documents.edit'),
    ('62b4e9c7-7be9-5a64-a4b0-e3bc2b07eb06', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '501f880e-d153-5c3a-a732-e789da5cc342', 'accountant', 'documents.edit'),
    ('de6b97b6-c1ca-53f0-b394-739a81ca053e', '396b6188-e76d-4d82-bb34-02810a285d1b', '501f880e-d153-5c3a-a732-e789da5cc342', 'payroll', 'documents.edit'),
    ('82f3fe2b-c8f0-57ab-b55a-b2e9b6a15f90', 'a920c985-595b-476c-8221-5815bf17c4fe', '501f880e-d153-5c3a-a732-e789da5cc342', 'client_owner', 'documents.edit'),
    ('79217772-63a5-53d3-bdd6-1c4876271981', '9ae73810-5674-4fee-8cd3-728558bcf532', '501f880e-d153-5c3a-a732-e789da5cc342', 'client_staff', 'documents.edit'),
    ('a0232b41-4f6e-57bf-ada0-3c14bc7059d0', '0ce20ca9-ecc0-444c-9174-e5fb53e920d8', '501f880e-d153-5c3a-a732-e789da5cc342', 'upload_only', 'documents.edit'),
    ('7b98c671-766f-5469-ad97-cbb073f7e017', 'f9cb0362-3cf2-4f55-814d-788c52016318', 'ca239860-5a48-5e5f-bfce-3b455c3027cf', 'admin', 'documents.replace_file'),
    ('944fdaca-feaa-55e3-bff0-47908999b2a9', 'af343e28-e831-4075-b057-602e68f248f6', 'ca239860-5a48-5e5f-bfce-3b455c3027cf', 'manager', 'documents.replace_file'),
    ('5add99f7-7f3d-591c-b2ee-21a9f8da2f3c', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', 'ca239860-5a48-5e5f-bfce-3b455c3027cf', 'accountant', 'documents.replace_file'),
    ('7179d061-4bb5-5a12-9d3f-040d291ebda1', '396b6188-e76d-4d82-bb34-02810a285d1b', 'ca239860-5a48-5e5f-bfce-3b455c3027cf', 'payroll', 'documents.replace_file'),
    ('b296ecd7-d5ff-5349-b3c2-15f73650f2b3', 'a920c985-595b-476c-8221-5815bf17c4fe', 'ca239860-5a48-5e5f-bfce-3b455c3027cf', 'client_owner', 'documents.replace_file'),
    ('eb7e4366-d1c0-5fec-8f14-61450a1a3501', '9ae73810-5674-4fee-8cd3-728558bcf532', 'ca239860-5a48-5e5f-bfce-3b455c3027cf', 'client_staff', 'documents.replace_file'),
    ('06973854-0129-589e-9275-ff50f7164529', '0ce20ca9-ecc0-444c-9174-e5fb53e920d8', 'ca239860-5a48-5e5f-bfce-3b455c3027cf', 'upload_only', 'documents.replace_file'),
    ('8858cfe8-cd92-5317-9d88-2ceefd693c26', 'f9cb0362-3cf2-4f55-814d-788c52016318', 'fd634bb0-9b0f-514c-93eb-1ab7b4813209', 'admin', 'documents.delete'),
    ('155354e6-25d3-519c-8030-0b1e9b7442b4', 'af343e28-e831-4075-b057-602e68f248f6', 'fd634bb0-9b0f-514c-93eb-1ab7b4813209', 'manager', 'documents.delete'),
    ('1a734793-4dd4-523d-9b82-dcea19ba67cd', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', 'fd634bb0-9b0f-514c-93eb-1ab7b4813209', 'accountant', 'documents.delete'),
    ('4dcdae1d-a16b-5f06-984d-8276285cc903', '396b6188-e76d-4d82-bb34-02810a285d1b', 'fd634bb0-9b0f-514c-93eb-1ab7b4813209', 'payroll', 'documents.delete'),
    ('774e2f10-54f4-5a6b-a5bb-0613124835d4', 'a920c985-595b-476c-8221-5815bf17c4fe', 'fd634bb0-9b0f-514c-93eb-1ab7b4813209', 'client_owner', 'documents.delete'),
    ('3e4b248f-1a57-596b-91b2-04b0803eb41e', '9ae73810-5674-4fee-8cd3-728558bcf532', 'fd634bb0-9b0f-514c-93eb-1ab7b4813209', 'client_staff', 'documents.delete'),
    ('d6f9ec36-53ca-5759-9026-557ff43a2bbe', '0ce20ca9-ecc0-444c-9174-e5fb53e920d8', 'fd634bb0-9b0f-514c-93eb-1ab7b4813209', 'upload_only', 'documents.delete'),
    ('edd2fc67-ce08-5a73-92a6-3e923942f4e0', 'f9cb0362-3cf2-4f55-814d-788c52016318', 'ef89b2d5-fc64-5959-87f4-4c257d01caa8', 'admin', 'intake.view'),
    ('ff4e623b-f7ce-5b38-87e7-2d88c99f056c', 'af343e28-e831-4075-b057-602e68f248f6', 'ef89b2d5-fc64-5959-87f4-4c257d01caa8', 'manager', 'intake.view'),
    ('47743cfc-f63f-5d21-96a7-66447d795895', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', 'ef89b2d5-fc64-5959-87f4-4c257d01caa8', 'accountant', 'intake.view'),
    ('2acc250d-83a1-516f-bc21-d0e76134efd3', '396b6188-e76d-4d82-bb34-02810a285d1b', 'ef89b2d5-fc64-5959-87f4-4c257d01caa8', 'payroll', 'intake.view'),
    ('110f7043-8288-5c5a-be4a-551242ac074d', 'a920c985-595b-476c-8221-5815bf17c4fe', 'ef89b2d5-fc64-5959-87f4-4c257d01caa8', 'client_owner', 'intake.view'),
    ('6e66888b-bd66-5b8e-bfb3-73d9b9ebd3cd', '9ae73810-5674-4fee-8cd3-728558bcf532', 'ef89b2d5-fc64-5959-87f4-4c257d01caa8', 'client_staff', 'intake.view'),
    ('8e2a81e3-4d9a-542e-bcbe-9b92d580eb78', 'f9cb0362-3cf2-4f55-814d-788c52016318', 'd2b8a7a2-7c8b-5952-98b8-da42478c9683', 'admin', 'intake.submit'),
    ('67d669ae-a749-5992-bfff-27ec465d5bc3', 'af343e28-e831-4075-b057-602e68f248f6', 'd2b8a7a2-7c8b-5952-98b8-da42478c9683', 'manager', 'intake.submit'),
    ('c5ea69e5-da74-5327-b1f6-14a071ebd14e', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', 'd2b8a7a2-7c8b-5952-98b8-da42478c9683', 'accountant', 'intake.submit'),
    ('3331c9bc-8e6e-5d17-90af-02933b197961', '396b6188-e76d-4d82-bb34-02810a285d1b', 'd2b8a7a2-7c8b-5952-98b8-da42478c9683', 'payroll', 'intake.submit'),
    ('5588fc45-5b36-5cb7-95d8-d696b7747a58', 'a920c985-595b-476c-8221-5815bf17c4fe', 'd2b8a7a2-7c8b-5952-98b8-da42478c9683', 'client_owner', 'intake.submit'),
    ('331a2914-6c00-5af9-8059-07323ee3da60', '9ae73810-5674-4fee-8cd3-728558bcf532', 'd2b8a7a2-7c8b-5952-98b8-da42478c9683', 'client_staff', 'intake.submit'),
    ('e7caf8eb-4ca0-5f8c-8375-bd2c303c6236', 'f9cb0362-3cf2-4f55-814d-788c52016318', '593fe4a3-c07d-5282-8612-bd641d23111e', 'admin', 'intake.retry'),
    ('59c5bf93-ef94-575b-8a8d-299562f6eb3d', 'af343e28-e831-4075-b057-602e68f248f6', '593fe4a3-c07d-5282-8612-bd641d23111e', 'manager', 'intake.retry'),
    ('b4ac37da-4b1d-5435-9e4a-f0410f69ca30', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '593fe4a3-c07d-5282-8612-bd641d23111e', 'accountant', 'intake.retry'),
    ('514dcfd9-17ec-557c-89fe-96a90fe70a5b', '396b6188-e76d-4d82-bb34-02810a285d1b', '593fe4a3-c07d-5282-8612-bd641d23111e', 'payroll', 'intake.retry'),
    ('1d777461-4608-5f25-a7b7-0f4104ee8c58', 'f9cb0362-3cf2-4f55-814d-788c52016318', '9736cfef-02be-5df0-9597-2f96158c2033', 'admin', 'intake.reject'),
    ('883b0f0f-4d94-508b-a619-50cdc9ac9d13', 'af343e28-e831-4075-b057-602e68f248f6', '9736cfef-02be-5df0-9597-2f96158c2033', 'manager', 'intake.reject'),
    ('0d822bc4-8da7-5c54-b76e-faccf8990660', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '9736cfef-02be-5df0-9597-2f96158c2033', 'accountant', 'intake.reject'),
    ('3f7d60db-5404-5bbb-ab2c-8f9335052688', '396b6188-e76d-4d82-bb34-02810a285d1b', '9736cfef-02be-5df0-9597-2f96158c2033', 'payroll', 'intake.reject'),
    ('50cbe94b-226c-5eef-8c64-3e59ef3ff9dd', 'f9cb0362-3cf2-4f55-814d-788c52016318', '645b9ff0-cbce-507e-af0b-98ca406a1514', 'admin', 'intake.channels.view'),
    ('7d7c40bf-9835-52b3-b45b-e720db94b491', 'af343e28-e831-4075-b057-602e68f248f6', '645b9ff0-cbce-507e-af0b-98ca406a1514', 'manager', 'intake.channels.view'),
    ('ab47cab2-43c3-5497-bea9-735606bc5045', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '645b9ff0-cbce-507e-af0b-98ca406a1514', 'accountant', 'intake.channels.view'),
    ('9f77c116-18fb-588b-99bd-a8764c564278', '396b6188-e76d-4d82-bb34-02810a285d1b', '645b9ff0-cbce-507e-af0b-98ca406a1514', 'payroll', 'intake.channels.view'),
    ('161305c6-1949-56df-99b5-3fc95419eef8', 'a920c985-595b-476c-8221-5815bf17c4fe', '645b9ff0-cbce-507e-af0b-98ca406a1514', 'client_owner', 'intake.channels.view'),
    ('8be2bc1c-2951-5804-8c35-cb22785d5f38', 'f9cb0362-3cf2-4f55-814d-788c52016318', '5bb2b199-a0b6-591a-95e2-7b326deaa78b', 'admin', 'intake.channels.manage'),
    ('ebeb7984-c058-5758-a1b8-1a78bbdc394d', 'af343e28-e831-4075-b057-602e68f248f6', '5bb2b199-a0b6-591a-95e2-7b326deaa78b', 'manager', 'intake.channels.manage'),
    ('ce99d9e9-a71a-53a0-9f3b-e353acfae393', 'f9cb0362-3cf2-4f55-814d-788c52016318', '93da0326-559d-5c40-ba1a-a43dddcc229d', 'admin', 'processing.view'),
    ('b4406693-b1c3-5efc-ad00-d7b68ba22506', 'af343e28-e831-4075-b057-602e68f248f6', '93da0326-559d-5c40-ba1a-a43dddcc229d', 'manager', 'processing.view'),
    ('26b24988-a5d9-5619-913e-fc00d0c769d4', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '93da0326-559d-5c40-ba1a-a43dddcc229d', 'accountant', 'processing.view'),
    ('de55ddc5-4140-571a-bd1f-bb65405dbcd2', '396b6188-e76d-4d82-bb34-02810a285d1b', '93da0326-559d-5c40-ba1a-a43dddcc229d', 'payroll', 'processing.view'),
    ('4faf39a6-6eeb-57a6-a250-36247159c3df', 'a920c985-595b-476c-8221-5815bf17c4fe', '93da0326-559d-5c40-ba1a-a43dddcc229d', 'client_owner', 'processing.view'),
    ('7cfe5fe5-7ef8-5f70-bbbf-cc4f15a596dd', 'f9cb0362-3cf2-4f55-814d-788c52016318', '406547ed-c6e5-5b16-ada5-b595d5fcc420', 'admin', 'processing.extraction.edit'),
    ('330e0660-21dc-5d56-8204-46cd4d027f9a', 'af343e28-e831-4075-b057-602e68f248f6', '406547ed-c6e5-5b16-ada5-b595d5fcc420', 'manager', 'processing.extraction.edit'),
    ('df3f08d3-c2fc-5d81-86f4-778023a28ba4', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '406547ed-c6e5-5b16-ada5-b595d5fcc420', 'accountant', 'processing.extraction.edit'),
    ('40f09d93-1934-5668-acfb-a9d016353a03', '396b6188-e76d-4d82-bb34-02810a285d1b', '406547ed-c6e5-5b16-ada5-b595d5fcc420', 'payroll', 'processing.extraction.edit'),
    ('07d359a2-0f90-5944-8153-76ef1a79c998', 'f9cb0362-3cf2-4f55-814d-788c52016318', 'bfcc58f2-2e4e-58da-a7de-246443b8c527', 'admin', 'processing.classification.edit'),
    ('1618da1a-206d-566f-bc50-4327b49e1583', 'af343e28-e831-4075-b057-602e68f248f6', 'bfcc58f2-2e4e-58da-a7de-246443b8c527', 'manager', 'processing.classification.edit'),
    ('785d4829-68f8-5c56-a8c1-cd3230e3e4bb', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', 'bfcc58f2-2e4e-58da-a7de-246443b8c527', 'accountant', 'processing.classification.edit'),
    ('ed0b5bf3-9d69-5940-bb78-722fd8c86876', '396b6188-e76d-4d82-bb34-02810a285d1b', 'bfcc58f2-2e4e-58da-a7de-246443b8c527', 'payroll', 'processing.classification.edit'),
    ('7a706eaa-ec03-595b-aedb-7baeeb8c6bea', 'f9cb0362-3cf2-4f55-814d-788c52016318', 'd1364b4d-67f8-5cd3-8bd3-44cae3c91fed', 'admin', 'processing.reprocess'),
    ('989075ce-e05e-5793-a58c-786474fc17a3', 'af343e28-e831-4075-b057-602e68f248f6', 'd1364b4d-67f8-5cd3-8bd3-44cae3c91fed', 'manager', 'processing.reprocess'),
    ('f41c39d1-280d-5627-8a2d-2f5f4444e4b3', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', 'd1364b4d-67f8-5cd3-8bd3-44cae3c91fed', 'accountant', 'processing.reprocess'),
    ('dde3dd9c-1c37-5861-a9b7-d658e989e72e', '396b6188-e76d-4d82-bb34-02810a285d1b', 'd1364b4d-67f8-5cd3-8bd3-44cae3c91fed', 'payroll', 'processing.reprocess'),
    ('759c0c04-15a0-5e2c-943d-50b1d5d2220a', 'f9cb0362-3cf2-4f55-814d-788c52016318', '9836aa70-98cb-5a4e-b73b-2f8a390a7328', 'admin', 'processing.ai_proposal.view'),
    ('cbaee6fe-2493-5b91-802e-bfd46b39c1c8', 'af343e28-e831-4075-b057-602e68f248f6', '9836aa70-98cb-5a4e-b73b-2f8a390a7328', 'manager', 'processing.ai_proposal.view'),
    ('f47f135c-67bd-5ae5-a9fe-5a194161553b', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '9836aa70-98cb-5a4e-b73b-2f8a390a7328', 'accountant', 'processing.ai_proposal.view'),
    ('fcbc9312-1d47-54c2-b947-617a83284382', '396b6188-e76d-4d82-bb34-02810a285d1b', '9836aa70-98cb-5a4e-b73b-2f8a390a7328', 'payroll', 'processing.ai_proposal.view'),
    ('a99881f8-dd41-51f8-b338-6501897e15ca', 'f9cb0362-3cf2-4f55-814d-788c52016318', 'b6e18b3d-5388-5e98-a3c8-4309ab4dde57', 'admin', 'processing.ai_proposal.edit'),
    ('d16db979-c4a8-534a-9e16-5092ea34c281', 'af343e28-e831-4075-b057-602e68f248f6', 'b6e18b3d-5388-5e98-a3c8-4309ab4dde57', 'manager', 'processing.ai_proposal.edit'),
    ('a041f17e-d5d9-57ed-9a3a-9a429164c430', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', 'b6e18b3d-5388-5e98-a3c8-4309ab4dde57', 'accountant', 'processing.ai_proposal.edit'),
    ('a0651d5c-b073-5862-9966-b9bebc87663b', '396b6188-e76d-4d82-bb34-02810a285d1b', 'b6e18b3d-5388-5e98-a3c8-4309ab4dde57', 'payroll', 'processing.ai_proposal.edit'),
    ('936c6bfb-ad64-5b67-aa31-58a0f95a0d19', 'f9cb0362-3cf2-4f55-814d-788c52016318', '0fb98d73-3a1a-5617-8a6c-5b11b6de1794', 'admin', 'review.view'),
    ('0b1501e4-3fe3-504f-aa6a-b9a56b243879', 'af343e28-e831-4075-b057-602e68f248f6', '0fb98d73-3a1a-5617-8a6c-5b11b6de1794', 'manager', 'review.view'),
    ('30aad4ad-82b0-5663-b296-47d7080ab841', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '0fb98d73-3a1a-5617-8a6c-5b11b6de1794', 'accountant', 'review.view'),
    ('a7b73eab-51a7-5876-b7f3-a310aa668398', '396b6188-e76d-4d82-bb34-02810a285d1b', '0fb98d73-3a1a-5617-8a6c-5b11b6de1794', 'payroll', 'review.view'),
    ('b6bc096d-5059-5182-92f6-9f33c24f40be', 'f9cb0362-3cf2-4f55-814d-788c52016318', 'acf3546a-5544-5e2f-a4f3-f34f9dd870c3', 'admin', 'review.start'),
    ('974587bb-dc6b-5df5-a389-2b2752ad18b0', 'af343e28-e831-4075-b057-602e68f248f6', 'acf3546a-5544-5e2f-a4f3-f34f9dd870c3', 'manager', 'review.start'),
    ('d84de626-3394-5c79-93ae-19551be43c2e', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', 'acf3546a-5544-5e2f-a4f3-f34f9dd870c3', 'accountant', 'review.start'),
    ('88d69356-72c3-5a7b-ae92-53cd31b38bad', '396b6188-e76d-4d82-bb34-02810a285d1b', 'acf3546a-5544-5e2f-a4f3-f34f9dd870c3', 'payroll', 'review.start'),
    ('8ff7484d-26da-5151-b9d9-583c08ce8b3b', 'f9cb0362-3cf2-4f55-814d-788c52016318', '029d44f8-94cb-5d94-8726-5810c89187c5', 'admin', 'review.edit'),
    ('95ab49bf-aece-5d6f-9613-7c94c9e847bc', 'af343e28-e831-4075-b057-602e68f248f6', '029d44f8-94cb-5d94-8726-5810c89187c5', 'manager', 'review.edit'),
    ('4fdbb8b1-e6eb-5b5c-af7a-abb0dba39088', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '029d44f8-94cb-5d94-8726-5810c89187c5', 'accountant', 'review.edit'),
    ('25e93bdb-01ca-5b63-bbbf-2ffc027976d3', '396b6188-e76d-4d82-bb34-02810a285d1b', '029d44f8-94cb-5d94-8726-5810c89187c5', 'payroll', 'review.edit'),
    ('d7ff8354-a609-5bf7-8752-5fbb9ec45047', 'f9cb0362-3cf2-4f55-814d-788c52016318', '742bb0e8-2b74-53ad-9725-ec5bf3507f02', 'admin', 'review.approve'),
    ('c4fd6e24-5980-5d98-8961-89ff61a4c7e1', 'af343e28-e831-4075-b057-602e68f248f6', '742bb0e8-2b74-53ad-9725-ec5bf3507f02', 'manager', 'review.approve'),
    ('8bfe600c-7452-5151-bdc9-d244728b4480', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '742bb0e8-2b74-53ad-9725-ec5bf3507f02', 'accountant', 'review.approve'),
    ('81236d49-e89b-567c-b5c5-66092dfad75b', '396b6188-e76d-4d82-bb34-02810a285d1b', '742bb0e8-2b74-53ad-9725-ec5bf3507f02', 'payroll', 'review.approve'),
    ('f942672e-5154-59ac-8ab6-f23ed47cb878', 'f9cb0362-3cf2-4f55-814d-788c52016318', 'a6e1908c-bfcb-54e2-a0ae-56cb190a92c1', 'admin', 'review.return_internal'),
    ('656a821b-e0fe-5382-a2d8-160b83627456', 'af343e28-e831-4075-b057-602e68f248f6', 'a6e1908c-bfcb-54e2-a0ae-56cb190a92c1', 'manager', 'review.return_internal'),
    ('4e8cb325-f4b5-53b1-8273-4f30ab64aad7', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', 'a6e1908c-bfcb-54e2-a0ae-56cb190a92c1', 'accountant', 'review.return_internal'),
    ('8b1d18d3-1b8a-5c15-8b1d-64ebc01e817b', '396b6188-e76d-4d82-bb34-02810a285d1b', 'a6e1908c-bfcb-54e2-a0ae-56cb190a92c1', 'payroll', 'review.return_internal'),
    ('c9344b47-ba75-51c3-9434-2c00be522211', 'f9cb0362-3cf2-4f55-814d-788c52016318', '5244b5ea-db10-5200-be2b-affde5bb87b3', 'admin', 'review.request_client_action'),
    ('16780201-0147-5dd2-ae80-9838fae89258', 'af343e28-e831-4075-b057-602e68f248f6', '5244b5ea-db10-5200-be2b-affde5bb87b3', 'manager', 'review.request_client_action'),
    ('27bd043b-5420-55c1-91c9-a44294a68ffa', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '5244b5ea-db10-5200-be2b-affde5bb87b3', 'accountant', 'review.request_client_action'),
    ('e901a08c-92bc-59a1-9700-5d7f3a3e9cf3', '396b6188-e76d-4d82-bb34-02810a285d1b', '5244b5ea-db10-5200-be2b-affde5bb87b3', 'payroll', 'review.request_client_action'),
    ('56ab3b0b-e815-5927-ab85-1f6bb2fad589', 'f9cb0362-3cf2-4f55-814d-788c52016318', 'dccfddf8-7634-568c-9559-40ad9ea42a25', 'admin', 'review.reassign'),
    ('e80b8c31-a78b-5b68-b8df-5e9566ba0fa6', 'af343e28-e831-4075-b057-602e68f248f6', 'dccfddf8-7634-568c-9559-40ad9ea42a25', 'manager', 'review.reassign'),
    ('128366c8-aabc-5b7c-aed6-d1802ae4c78f', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', 'dccfddf8-7634-568c-9559-40ad9ea42a25', 'accountant', 'review.reassign'),
    ('17cb381e-4164-58c1-b5a5-8c4f206cbe33', '396b6188-e76d-4d82-bb34-02810a285d1b', 'dccfddf8-7634-568c-9559-40ad9ea42a25', 'payroll', 'review.reassign'),
    ('2c0d63cb-596c-5d80-9385-9f776be053c3', 'f9cb0362-3cf2-4f55-814d-788c52016318', 'cb964fc8-3906-5ecd-a47a-2f0497deaf5e', 'admin', 'accounting_proposal.view'),
    ('28cb25c7-c4ed-5c77-a0f5-b3bd8a0c78fc', 'af343e28-e831-4075-b057-602e68f248f6', 'cb964fc8-3906-5ecd-a47a-2f0497deaf5e', 'manager', 'accounting_proposal.view'),
    ('877f87bc-736f-59f7-8817-464c76c7be0a', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', 'cb964fc8-3906-5ecd-a47a-2f0497deaf5e', 'accountant', 'accounting_proposal.view'),
    ('708d9fec-f59e-5fba-aab9-a29a79f353bb', 'f9cb0362-3cf2-4f55-814d-788c52016318', '86a59bee-ac70-5112-87fd-b826e014d9f3', 'admin', 'accounting_proposal.edit'),
    ('c29c27e7-2022-593e-af26-a1a365843ad9', 'af343e28-e831-4075-b057-602e68f248f6', '86a59bee-ac70-5112-87fd-b826e014d9f3', 'manager', 'accounting_proposal.edit'),
    ('679d3815-e5e7-555c-b24a-1a802abde49d', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '86a59bee-ac70-5112-87fd-b826e014d9f3', 'accountant', 'accounting_proposal.edit'),
    ('047a2811-61a9-55e9-aefd-8e616e6141e9', 'f9cb0362-3cf2-4f55-814d-788c52016318', '8607b368-113d-5323-bab7-11b7ec661ab3', 'admin', 'routing.view'),
    ('4860b6a8-62e4-51bc-8bda-7be1abdce047', 'af343e28-e831-4075-b057-602e68f248f6', '8607b368-113d-5323-bab7-11b7ec661ab3', 'manager', 'routing.view'),
    ('20ef5b89-f549-56a6-a568-10e458611025', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '8607b368-113d-5323-bab7-11b7ec661ab3', 'accountant', 'routing.view'),
    ('db8d1618-f40a-59eb-a3b5-5bbd01d9436c', '396b6188-e76d-4d82-bb34-02810a285d1b', '8607b368-113d-5323-bab7-11b7ec661ab3', 'payroll', 'routing.view'),
    ('d4adf000-73e1-5b5c-aae6-b89699573797', 'a920c985-595b-476c-8221-5815bf17c4fe', '8607b368-113d-5323-bab7-11b7ec661ab3', 'client_owner', 'routing.view'),
    ('bc59963f-1ac8-525c-9ef0-cd7869fbf2b7', 'f9cb0362-3cf2-4f55-814d-788c52016318', '7dd4a91e-a81f-5849-a082-c176c036c712', 'admin', 'routing.for_posting'),
    ('0aca4213-6b62-5edc-b178-d8f22f6912d2', 'af343e28-e831-4075-b057-602e68f248f6', '7dd4a91e-a81f-5849-a082-c176c036c712', 'manager', 'routing.for_posting'),
    ('ff0ca90e-5e3d-546c-b742-a74a86f76fd3', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '7dd4a91e-a81f-5849-a082-c176c036c712', 'accountant', 'routing.for_posting'),
    ('56ee0cff-8f6e-52c2-af89-0819b60bc863', 'f9cb0362-3cf2-4f55-814d-788c52016318', '01528a4b-4373-529a-8396-f957d38f9153', 'admin', 'routing.not_for_posting'),
    ('326fdcda-eab7-53f2-b176-4333a80aabc1', 'af343e28-e831-4075-b057-602e68f248f6', '01528a4b-4373-529a-8396-f957d38f9153', 'manager', 'routing.not_for_posting'),
    ('4a0dead8-7d2c-58f4-b1ff-6b57f6956f34', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '01528a4b-4373-529a-8396-f957d38f9153', 'accountant', 'routing.not_for_posting'),
    ('81404400-9ca2-56b4-a055-b9a7fcf7a285', '396b6188-e76d-4d82-bb34-02810a285d1b', '01528a4b-4373-529a-8396-f957d38f9153', 'payroll', 'routing.not_for_posting'),
    ('a28d2e74-3737-5bb0-b229-97a912e18383', 'f9cb0362-3cf2-4f55-814d-788c52016318', '90bac49d-0307-5244-950b-766dc6349545', 'admin', 'routing.return'),
    ('78513a55-e9d7-50f9-8ca4-13106e31a401', 'af343e28-e831-4075-b057-602e68f248f6', '90bac49d-0307-5244-950b-766dc6349545', 'manager', 'routing.return'),
    ('8be3da52-65e7-5b10-aa5e-3ccbeb52a7c3', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '90bac49d-0307-5244-950b-766dc6349545', 'accountant', 'routing.return'),
    ('d0deeb79-0a2d-5d87-808f-934b8aaedf9d', '396b6188-e76d-4d82-bb34-02810a285d1b', '90bac49d-0307-5244-950b-766dc6349545', 'payroll', 'routing.return'),
    ('c06e8d90-291d-5fe0-b68a-de352d3e0db6', 'f9cb0362-3cf2-4f55-814d-788c52016318', 'e75ce885-c601-5468-a4ce-ac31885e96ad', 'admin', 'routing.auto_send_policy.manage'),
    ('5ffcb389-99f9-5acd-b3b4-53cfad96133f', 'af343e28-e831-4075-b057-602e68f248f6', 'e75ce885-c601-5468-a4ce-ac31885e96ad', 'manager', 'routing.auto_send_policy.manage'),
    ('0067d1ef-e124-5a25-918d-95c0b14f0cc7', 'f9cb0362-3cf2-4f55-814d-788c52016318', '800c8b50-8100-59a5-92a1-a28fdebf46a4', 'admin', 'archive.view'),
    ('0e96fbea-2301-5ba9-805e-1a0f216fbab6', 'af343e28-e831-4075-b057-602e68f248f6', '800c8b50-8100-59a5-92a1-a28fdebf46a4', 'manager', 'archive.view'),
    ('1e2c403b-ee32-53c2-bb85-dc4a8eb28fef', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '800c8b50-8100-59a5-92a1-a28fdebf46a4', 'accountant', 'archive.view'),
    ('d4fcbf0e-90d7-5d4c-95b1-8a1c7b92e5c1', '396b6188-e76d-4d82-bb34-02810a285d1b', '800c8b50-8100-59a5-92a1-a28fdebf46a4', 'payroll', 'archive.view'),
    ('49691537-c133-594d-83c4-16cabe34d3d5', 'a920c985-595b-476c-8221-5815bf17c4fe', '800c8b50-8100-59a5-92a1-a28fdebf46a4', 'client_owner', 'archive.view'),
    ('10eee55d-4e7d-5f69-bb7c-c0b1d2520d29', '9ae73810-5674-4fee-8cd3-728558bcf532', '800c8b50-8100-59a5-92a1-a28fdebf46a4', 'client_staff', 'archive.view'),
    ('23f2ac9f-f196-5f67-9c20-4f442ff32915', '0ce20ca9-ecc0-444c-9174-e5fb53e920d8', '800c8b50-8100-59a5-92a1-a28fdebf46a4', 'upload_only', 'archive.view'),
    ('6f008408-5f7a-5317-8075-b524b1c7acbb', 'f9cb0362-3cf2-4f55-814d-788c52016318', '3bf2017e-9c80-5f37-87ba-70a50b51c733', 'admin', 'archive.download'),
    ('c4ebd84a-c8df-5c98-9091-e4e4cb3ef415', 'af343e28-e831-4075-b057-602e68f248f6', '3bf2017e-9c80-5f37-87ba-70a50b51c733', 'manager', 'archive.download'),
    ('005b1871-f68a-5127-bbbc-b082f99127b7', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '3bf2017e-9c80-5f37-87ba-70a50b51c733', 'accountant', 'archive.download'),
    ('0e536b83-1c9d-523b-83a8-c166cb171fcd', '396b6188-e76d-4d82-bb34-02810a285d1b', '3bf2017e-9c80-5f37-87ba-70a50b51c733', 'payroll', 'archive.download'),
    ('b2192897-a29f-5357-b9b7-32621e1b7340', 'a920c985-595b-476c-8221-5815bf17c4fe', '3bf2017e-9c80-5f37-87ba-70a50b51c733', 'client_owner', 'archive.download'),
    ('535a9de7-9e25-5186-b538-ba7bcdfea77f', '9ae73810-5674-4fee-8cd3-728558bcf532', '3bf2017e-9c80-5f37-87ba-70a50b51c733', 'client_staff', 'archive.download'),
    ('9ef480bc-6d9b-539f-8f21-9f4585127e68', '0ce20ca9-ecc0-444c-9174-e5fb53e920d8', '3bf2017e-9c80-5f37-87ba-70a50b51c733', 'upload_only', 'archive.download'),
    ('f14444c6-3876-5396-a471-663e256b208c', 'f9cb0362-3cf2-4f55-814d-788c52016318', '094f7727-5ba8-5c95-b7e1-e4399a56044a', 'admin', 'archive.search'),
    ('46baa141-dfa9-53fb-88ca-164a88e92b1f', 'af343e28-e831-4075-b057-602e68f248f6', '094f7727-5ba8-5c95-b7e1-e4399a56044a', 'manager', 'archive.search'),
    ('8b223e5c-54c4-57ac-88d9-bf709c0b2728', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '094f7727-5ba8-5c95-b7e1-e4399a56044a', 'accountant', 'archive.search'),
    ('ca966362-15a6-5f4a-86fb-d848ebeca89d', '396b6188-e76d-4d82-bb34-02810a285d1b', '094f7727-5ba8-5c95-b7e1-e4399a56044a', 'payroll', 'archive.search'),
    ('5111d340-3182-526a-a599-9e966e0656d5', 'a920c985-595b-476c-8221-5815bf17c4fe', '094f7727-5ba8-5c95-b7e1-e4399a56044a', 'client_owner', 'archive.search'),
    ('a1e354bd-dcd7-551e-9e94-00dd5a37f332', '9ae73810-5674-4fee-8cd3-728558bcf532', '094f7727-5ba8-5c95-b7e1-e4399a56044a', 'client_staff', 'archive.search'),
    ('6c4c8b91-4aec-532c-b81e-0e20e84654eb', '0ce20ca9-ecc0-444c-9174-e5fb53e920d8', '094f7727-5ba8-5c95-b7e1-e4399a56044a', 'upload_only', 'archive.search'),
    ('d7639d96-2f36-5d54-9e4f-3572f16db257', 'f9cb0362-3cf2-4f55-814d-788c52016318', '44542aec-2b4d-5d4f-a62b-ee10ea34ef40', 'admin', 'archive.metadata.edit'),
    ('b53f1723-6a24-5f82-8087-719e8fb1f74d', 'af343e28-e831-4075-b057-602e68f248f6', '44542aec-2b4d-5d4f-a62b-ee10ea34ef40', 'manager', 'archive.metadata.edit'),
    ('726dca42-803b-5b2c-aab2-70ff0c5402ae', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '44542aec-2b4d-5d4f-a62b-ee10ea34ef40', 'accountant', 'archive.metadata.edit'),
    ('8700a888-0d91-55a7-9835-68c0777b96ba', '396b6188-e76d-4d82-bb34-02810a285d1b', '44542aec-2b4d-5d4f-a62b-ee10ea34ef40', 'payroll', 'archive.metadata.edit'),
    ('44775e1d-5016-528c-80f9-e00707f29020', 'f9cb0362-3cf2-4f55-814d-788c52016318', '4ec49d85-a755-55d9-823c-3909ee42d5d4', 'admin', 'archive.restore'),
    ('26be4457-c727-581f-9c94-cb7f9434ed58', 'af343e28-e831-4075-b057-602e68f248f6', '4ec49d85-a755-55d9-823c-3909ee42d5d4', 'manager', 'archive.restore'),
    ('f1a84ba3-e613-5bcb-8bed-31dd054081b3', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '4ec49d85-a755-55d9-823c-3909ee42d5d4', 'accountant', 'archive.restore'),
    ('b4bd772e-49b5-54c4-8f05-07baff5636e6', 'f9cb0362-3cf2-4f55-814d-788c52016318', '8b787f0b-0101-54ff-a849-7128b0372fc7', 'admin', 'integrations.view'),
    ('656da318-4e7d-5fd7-9edf-34100c1543ed', 'af343e28-e831-4075-b057-602e68f248f6', '8b787f0b-0101-54ff-a849-7128b0372fc7', 'manager', 'integrations.view'),
    ('834e8c65-b9a7-5b4a-a3e4-e14a72531999', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '8b787f0b-0101-54ff-a849-7128b0372fc7', 'accountant', 'integrations.view'),
    ('4880b74b-1df1-5d6f-8c48-28ca4e40f1fb', '396b6188-e76d-4d82-bb34-02810a285d1b', '8b787f0b-0101-54ff-a849-7128b0372fc7', 'payroll', 'integrations.view'),
    ('973b87b3-5184-5ae8-a821-ce073723bb3e', 'a920c985-595b-476c-8221-5815bf17c4fe', '8b787f0b-0101-54ff-a849-7128b0372fc7', 'client_owner', 'integrations.view'),
    ('ed23a4b0-737b-541f-9c5e-7de384486c12', 'f9cb0362-3cf2-4f55-814d-788c52016318', 'ba6cd54b-2179-5eae-98ff-aa7224990caf', 'admin', 'integrations.manage'),
    ('e05ed079-1cdb-5cdd-a80b-123c7b5f9dcb', 'af343e28-e831-4075-b057-602e68f248f6', 'ba6cd54b-2179-5eae-98ff-aa7224990caf', 'manager', 'integrations.manage'),
    ('ee9712ce-44bf-554b-b014-ee696ce51e08', 'f9cb0362-3cf2-4f55-814d-788c52016318', 'a1ea7a4f-b04d-5d92-82b4-6ea69b449193', 'admin', 'automations.view'),
    ('a898d60a-a51d-577b-8ed9-2f3ddcb17108', 'af343e28-e831-4075-b057-602e68f248f6', 'a1ea7a4f-b04d-5d92-82b4-6ea69b449193', 'manager', 'automations.view'),
    ('f65b6a0e-0bae-5c1f-8552-afa4f67d2c4f', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', 'a1ea7a4f-b04d-5d92-82b4-6ea69b449193', 'accountant', 'automations.view'),
    ('ef46cffa-0a32-5aa9-a4c4-649e8a218dfd', '396b6188-e76d-4d82-bb34-02810a285d1b', 'a1ea7a4f-b04d-5d92-82b4-6ea69b449193', 'payroll', 'automations.view'),
    ('d80c3116-878e-53e7-bdef-95883c2ffdd5', 'a920c985-595b-476c-8221-5815bf17c4fe', 'a1ea7a4f-b04d-5d92-82b4-6ea69b449193', 'client_owner', 'automations.view'),
    ('7609f0b7-f09a-567a-9dd4-2487800a2a16', 'f9cb0362-3cf2-4f55-814d-788c52016318', 'ba6ec369-4ffe-54b3-92a5-d6325c48dc10', 'admin', 'automations.manage'),
    ('ed286ffd-b51d-5eb6-9385-4e4ec18e800d', 'af343e28-e831-4075-b057-602e68f248f6', 'ba6ec369-4ffe-54b3-92a5-d6325c48dc10', 'manager', 'automations.manage'),
    ('e6d9104e-a42b-54c9-a975-04acc7afbc88', 'f9cb0362-3cf2-4f55-814d-788c52016318', '31e398bd-3444-5698-8148-c4eab1c509a3', 'admin', 'automations.run_manual'),
    ('efedec0e-b242-5128-bf76-b5358e8db674', 'af343e28-e831-4075-b057-602e68f248f6', '31e398bd-3444-5698-8148-c4eab1c509a3', 'manager', 'automations.run_manual'),
    ('003da517-6cc6-5ed0-bb50-af95280ee624', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '31e398bd-3444-5698-8148-c4eab1c509a3', 'accountant', 'automations.run_manual'),
    ('4151b942-85a1-5ce8-af74-60a3a32f8267', '396b6188-e76d-4d82-bb34-02810a285d1b', '31e398bd-3444-5698-8148-c4eab1c509a3', 'payroll', 'automations.run_manual'),
    ('f243dfd7-d465-51dd-be5c-c80c76f3bcd9', 'f9cb0362-3cf2-4f55-814d-788c52016318', 'f53fbe8c-a8c2-52a8-96fe-6aea20629132', 'admin', 'automations.retry'),
    ('60b52090-7048-591c-a9bf-e45d7c2e49e2', 'af343e28-e831-4075-b057-602e68f248f6', 'f53fbe8c-a8c2-52a8-96fe-6aea20629132', 'manager', 'automations.retry'),
    ('5cbb7709-193b-5f33-b59b-8339a1b2d711', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', 'f53fbe8c-a8c2-52a8-96fe-6aea20629132', 'accountant', 'automations.retry'),
    ('9984361f-86a1-5f5b-b13f-cfc7596d3dc2', '396b6188-e76d-4d82-bb34-02810a285d1b', 'f53fbe8c-a8c2-52a8-96fe-6aea20629132', 'payroll', 'automations.retry'),
    ('b5d34841-7ac6-581d-a2bd-1ea1322f36c1', 'f9cb0362-3cf2-4f55-814d-788c52016318', '401899be-3d7a-57ea-8515-20d5956a300f', 'admin', 'users.view'),
    ('5625329a-88b3-5f98-8e8d-54f5790f7d2f', 'af343e28-e831-4075-b057-602e68f248f6', '401899be-3d7a-57ea-8515-20d5956a300f', 'manager', 'users.view'),
    ('d6043937-5108-519b-81c4-eee81d4d4975', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '401899be-3d7a-57ea-8515-20d5956a300f', 'accountant', 'users.view'),
    ('68f45e5b-3b3c-5fa0-ace7-3325cc951eb7', '396b6188-e76d-4d82-bb34-02810a285d1b', '401899be-3d7a-57ea-8515-20d5956a300f', 'payroll', 'users.view'),
    ('da7e64b8-97b3-527e-bbad-8a451c904c11', 'a920c985-595b-476c-8221-5815bf17c4fe', '401899be-3d7a-57ea-8515-20d5956a300f', 'client_owner', 'users.view'),
    ('c02eacbb-afe2-54c8-a8e3-e07e2c3d65bc', 'f9cb0362-3cf2-4f55-814d-788c52016318', '791d1ebf-97d5-51e9-bb91-d994ccd9e948', 'admin', 'users.create'),
    ('104b8657-788d-5a70-b411-4a21c458b524', 'af343e28-e831-4075-b057-602e68f248f6', '791d1ebf-97d5-51e9-bb91-d994ccd9e948', 'manager', 'users.create'),
    ('fe1c5aa8-090e-5a2b-83f7-cafe8a44559e', 'a920c985-595b-476c-8221-5815bf17c4fe', '791d1ebf-97d5-51e9-bb91-d994ccd9e948', 'client_owner', 'users.create'),
    ('5881505c-e090-5eed-bd52-36f0f95fd8c9', 'f9cb0362-3cf2-4f55-814d-788c52016318', 'a6e48d73-a975-5fca-ba14-eab9523f0cc5', 'admin', 'users.edit'),
    ('0b02be5c-a149-5322-b94f-d2851ced7b10', 'af343e28-e831-4075-b057-602e68f248f6', 'a6e48d73-a975-5fca-ba14-eab9523f0cc5', 'manager', 'users.edit'),
    ('18cc5666-b1ae-5461-b0a1-d81a912700ff', 'a920c985-595b-476c-8221-5815bf17c4fe', 'a6e48d73-a975-5fca-ba14-eab9523f0cc5', 'client_owner', 'users.edit'),
    ('35663376-e61b-5e70-86ca-20e2780e44bf', 'f9cb0362-3cf2-4f55-814d-788c52016318', '7bdf210b-7594-57c3-80dd-4df1e0b4e4a8', 'admin', 'users.disable'),
    ('5875c032-480d-5e04-86af-d51a1d7bd095', 'af343e28-e831-4075-b057-602e68f248f6', '7bdf210b-7594-57c3-80dd-4df1e0b4e4a8', 'manager', 'users.disable'),
    ('e07071c6-b0b7-57dc-a2a0-86cc8def605f', 'a920c985-595b-476c-8221-5815bf17c4fe', '7bdf210b-7594-57c3-80dd-4df1e0b4e4a8', 'client_owner', 'users.disable'),
    ('c68fecff-3495-5c2d-a52f-39e119721a93', 'f9cb0362-3cf2-4f55-814d-788c52016318', '2a0bf1d6-2799-55c9-b119-86c350454407', 'admin', 'access.view'),
    ('2cadc4a2-2dc9-5991-b4ef-21c8d8ab1c06', 'af343e28-e831-4075-b057-602e68f248f6', '2a0bf1d6-2799-55c9-b119-86c350454407', 'manager', 'access.view'),
    ('c072a14f-d170-5ccc-949a-8d93949d68e1', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '2a0bf1d6-2799-55c9-b119-86c350454407', 'accountant', 'access.view'),
    ('699de788-da67-552f-b907-f3d33c957e62', 'a920c985-595b-476c-8221-5815bf17c4fe', '2a0bf1d6-2799-55c9-b119-86c350454407', 'client_owner', 'access.view'),
    ('7c1552e5-1f34-5f44-a0e8-d08d42f5739e', 'f9cb0362-3cf2-4f55-814d-788c52016318', '81196288-ba6e-5f15-96d3-068a00672c9b', 'admin', 'access.manage'),
    ('716b7a49-5402-50e7-ba93-9c557a6391ed', 'af343e28-e831-4075-b057-602e68f248f6', '81196288-ba6e-5f15-96d3-068a00672c9b', 'manager', 'access.manage'),
    ('720d5d0c-a7b2-553e-aa09-44cae1dbe94d', 'a920c985-595b-476c-8221-5815bf17c4fe', '81196288-ba6e-5f15-96d3-068a00672c9b', 'client_owner', 'access.manage'),
    ('2b5df572-27a3-51f2-af8b-2667211b8e7f', 'f9cb0362-3cf2-4f55-814d-788c52016318', 'fa82bfa8-539a-5b90-bb6d-d2f3a21fd873', 'admin', 'roles.view'),
    ('ce46b245-a6d7-5e3a-96ae-dc7977a806c8', 'af343e28-e831-4075-b057-602e68f248f6', 'fa82bfa8-539a-5b90-bb6d-d2f3a21fd873', 'manager', 'roles.view'),
    ('9346b487-cb14-5632-a40b-f084e296162d', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', 'fa82bfa8-539a-5b90-bb6d-d2f3a21fd873', 'accountant', 'roles.view'),
    ('1a4d467b-4e24-50ef-826c-e1cb7d8c92be', 'f9cb0362-3cf2-4f55-814d-788c52016318', 'fe742e51-1932-595a-be76-5437bd373f8c', 'admin', 'roles.manage'),
    ('d6afafb9-068f-51ba-be14-180e5a163f1d', 'af343e28-e831-4075-b057-602e68f248f6', 'fe742e51-1932-595a-be76-5437bd373f8c', 'manager', 'roles.manage'),
    ('4c852df1-bb2a-51c6-9704-20cb31bbf784', 'f9cb0362-3cf2-4f55-814d-788c52016318', '544a8d1d-3a32-5f9f-b7d0-c08af6a11a4e', 'admin', 'permissions.view'),
    ('ff4af754-be4f-5294-8b32-4b32e1509db7', 'af343e28-e831-4075-b057-602e68f248f6', '544a8d1d-3a32-5f9f-b7d0-c08af6a11a4e', 'manager', 'permissions.view'),
    ('e18acf5c-75d8-56ac-a051-398670823228', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '544a8d1d-3a32-5f9f-b7d0-c08af6a11a4e', 'accountant', 'permissions.view'),
    ('2cedf48a-7ba7-5493-9bb3-267d2c99983f', 'f9cb0362-3cf2-4f55-814d-788c52016318', 'bc332c3b-d58f-5747-93b7-43f582724cf7', 'admin', 'permissions.manage'),
    ('b084e2e9-2cbc-59fa-85ee-7a840d611a29', 'af343e28-e831-4075-b057-602e68f248f6', 'bc332c3b-d58f-5747-93b7-43f582724cf7', 'manager', 'permissions.manage'),
    ('164139c9-18b6-5013-8987-4cbf70e6a642', 'f9cb0362-3cf2-4f55-814d-788c52016318', '149a0275-cf93-5156-b01d-e7b7e80f1dc6', 'admin', 'applications.view'),
    ('7d26e5e8-aa70-5605-aba2-b8455d4483ad', 'af343e28-e831-4075-b057-602e68f248f6', '149a0275-cf93-5156-b01d-e7b7e80f1dc6', 'manager', 'applications.view'),
    ('398e5b54-50e6-5fcc-a108-25473329c0df', 'b13f6113-20e7-4f35-9711-5e4c9a7e4738', '149a0275-cf93-5156-b01d-e7b7e80f1dc6', 'accountant', 'applications.view'),
    ('5624bb26-5053-5dac-9e24-484fa34b5bf4', '396b6188-e76d-4d82-bb34-02810a285d1b', '149a0275-cf93-5156-b01d-e7b7e80f1dc6', 'payroll', 'applications.view'),
    ('366ae3e5-be5d-5464-919b-3a9ad7344337', 'a920c985-595b-476c-8221-5815bf17c4fe', '149a0275-cf93-5156-b01d-e7b7e80f1dc6', 'client_owner', 'applications.view'),
    ('f695f9cc-fbfd-579e-bb83-8cfbae0cab4c', 'f9cb0362-3cf2-4f55-814d-788c52016318', '23d80816-53d3-5c94-b485-4b449586e670', 'admin', 'applications.manage'),
    ('ad0ca5c7-2203-5264-b39b-01aec7d275de', 'af343e28-e831-4075-b057-602e68f248f6', '23d80816-53d3-5c94-b485-4b449586e670', 'manager', 'applications.manage'),
    ('3c7b8a48-624d-519a-86f1-51216e036f8f', 'f9cb0362-3cf2-4f55-814d-788c52016318', 'a176a3ba-65d4-546b-abd2-b3cfaa5c97c2', 'admin', 'system.settings.view'),
    ('7c5b8190-e76b-5565-b043-df76039d8baa', 'af343e28-e831-4075-b057-602e68f248f6', 'a176a3ba-65d4-546b-abd2-b3cfaa5c97c2', 'manager', 'system.settings.view'),
    ('08a0518f-d190-5152-916b-78236969d3cf', 'f9cb0362-3cf2-4f55-814d-788c52016318', '901187fd-fb34-5b49-b262-16192d695122', 'admin', 'system.settings.manage');

DO $$
BEGIN
    IF (SELECT count(*) FROM public.permissions) <> 23
       OR (SELECT count(*) FROM expected_accounting_permissions) <> 23 THEN
        RAISE EXCEPTION 'Expected exactly 23 existing Accounting permissions';
    END IF;

    IF EXISTS (SELECT 1 FROM public.permissions WHERE application_id IS NULL) THEN
        RAISE EXCEPTION 'Every existing permission must have application ownership';
    END IF;

    IF EXISTS (
        SELECT application_id, code
        FROM public.permissions
        GROUP BY application_id, code
        HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION 'Duplicate application/permission code already exists';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.applications
        WHERE id = '8211ee99-1de8-47ab-abc3-4065950a5827' AND code = 'ACCOUNTING' AND is_active
    ) OR (SELECT count(*) FROM public.applications WHERE code = 'ACCOUNTING') <> 1 THEN
        RAISE EXCEPTION 'Expected active ACCOUNTING application UUID/code pair was not found exactly once';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.applications
        WHERE id = '150251b2-58e1-4981-b05c-d8a9538786cc' AND code = 'OFFICE' AND is_active
    ) OR (SELECT count(*) FROM public.applications WHERE code = 'OFFICE') <> 1 THEN
        RAISE EXCEPTION 'Expected active OFFICE application UUID/code pair was not found exactly once';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM expected_accounting_permissions expected
        LEFT JOIN public.permissions permission
          ON permission.id = expected.permission_id
         AND permission.code = expected.permission_code
         AND permission.application_id = '8211ee99-1de8-47ab-abc3-4065950a5827'
        WHERE permission.id IS NULL
    ) OR EXISTS (
        SELECT 1
        FROM public.permissions permission
        LEFT JOIN expected_accounting_permissions expected
          ON expected.permission_id = permission.id
         AND expected.permission_code = permission.code
        WHERE permission.application_id = '8211ee99-1de8-47ab-abc3-4065950a5827'
          AND expected.permission_id IS NULL
    ) THEN
        RAISE EXCEPTION 'Accounting permission UUID/code/application mapping drifted';
    END IF;

    IF (SELECT count(*) FROM public.roles) <> 7
       OR (SELECT count(*) FROM expected_roles) <> 7
       OR EXISTS (
           SELECT 1
           FROM expected_roles expected
           LEFT JOIN public.roles role
             ON role.id = expected.role_id
            AND role.code = expected.role_code
            AND role.is_active
           WHERE role.id IS NULL
       )
       OR EXISTS (
           SELECT 1
           FROM public.roles role
           LEFT JOIN expected_roles expected
             ON expected.role_id = role.id
            AND expected.role_code = role.code
           WHERE expected.role_id IS NULL
       ) THEN
        RAISE EXCEPTION 'Reviewed active global role catalog does not match';
    END IF;

    IF (SELECT count(*) FROM public.role_permissions) <> 0 THEN
        RAISE EXCEPTION 'Expected role_permissions to be empty';
    END IF;

    IF (SELECT count(*) FROM reviewed_office_permissions) <> 69 THEN
        RAISE EXCEPTION 'Expected exactly 69 reviewed Office permissions';
    END IF;

    IF (SELECT count(*) FROM reviewed_office_role_permissions) <> 297 THEN
        RAISE EXCEPTION 'Expected exactly 297 reviewed Office role mappings';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.permissions
        WHERE application_id = '150251b2-58e1-4981-b05c-d8a9538786cc'
    ) THEN
        RAISE EXCEPTION 'Unexpected pre-existing Office permission state';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM reviewed_office_permissions expected
        JOIN public.permissions existing ON existing.id = expected.permission_id
    ) THEN
        RAISE EXCEPTION 'Deterministic Office permission UUID collision';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM reviewed_office_role_permissions expected
        JOIN public.role_permissions existing ON existing.id = expected.role_permission_id
    ) THEN
        RAISE EXCEPTION 'Deterministic Office role-permission UUID collision';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.permissions'::regclass
          AND conname = 'permissions_code_key'
          AND contype = 'u'
    ) OR EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.permissions'::regclass
          AND conname = 'permissions_application_id_code_key'
    ) THEN
        RAISE EXCEPTION 'Permission uniqueness constraints are not in the expected pre-migration state';
    END IF;
END;
$$;

ALTER TABLE ONLY public.permissions
    DROP CONSTRAINT permissions_code_key;

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_application_id_code_key
    UNIQUE (application_id, code);

INSERT INTO public.permissions (id, application_id, code, name)
SELECT permission_id, '150251b2-58e1-4981-b05c-d8a9538786cc', permission_code, permission_name
FROM reviewed_office_permissions
ORDER BY permission_code;

INSERT INTO public.role_permissions (id, role_id, permission_id)
SELECT role_permission_id, role_id, permission_id
FROM reviewed_office_role_permissions
ORDER BY role_code, permission_code;

DO $$
BEGIN
    IF (SELECT count(*) FROM public.permissions WHERE application_id = '150251b2-58e1-4981-b05c-d8a9538786cc') <> 69 THEN
        RAISE EXCEPTION 'Office permission catalog is incomplete';
    END IF;

    IF (SELECT count(*) FROM public.role_permissions) <> 297 THEN
        RAISE EXCEPTION 'Office default role-permission mapping is incomplete';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM reviewed_office_permissions expected
        LEFT JOIN public.permissions actual
          ON actual.id = expected.permission_id
         AND actual.application_id = '150251b2-58e1-4981-b05c-d8a9538786cc'
         AND actual.code = expected.permission_code
         AND actual.is_active
        WHERE actual.id IS NULL
    ) THEN
        RAISE EXCEPTION 'Office permission catalog verification failed';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM reviewed_office_role_permissions expected
        LEFT JOIN public.role_permissions actual
          ON actual.id = expected.role_permission_id
         AND actual.role_id = expected.role_id
         AND actual.permission_id = expected.permission_id
         AND actual.is_active
        WHERE actual.id IS NULL
    ) THEN
        RAISE EXCEPTION 'Office role-permission verification failed';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM expected_accounting_permissions expected
        LEFT JOIN public.permissions actual
          ON actual.id = expected.permission_id
         AND actual.code = expected.permission_code
         AND actual.application_id = '8211ee99-1de8-47ab-abc3-4065950a5827'
        WHERE actual.id IS NULL
    ) THEN
        RAISE EXCEPTION 'Accounting permission catalog changed during migration';
    END IF;

    IF (SELECT count(*) FROM public.firm_applications) <> 0
       OR (SELECT count(*) FROM public.user_firm_applications) <> 0
       OR (SELECT count(*) FROM public.user_firm_roles) <> 0
       OR (SELECT count(*) FROM public.user_permission_overrides) <> 0
       OR (SELECT count(*) FROM public.permission_resource_scopes) <> 0 THEN
        RAISE EXCEPTION 'Authorization access-assignment tables changed unexpectedly';
    END IF;
END;
$$;

COMMIT;

