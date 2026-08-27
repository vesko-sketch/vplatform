\set ON_ERROR_STOP on

INSERT INTO public.applications (id, code, name, access_zone, is_active)
VALUES
    ('8211ee99-1de8-47ab-abc3-4065950a5827', 'ACCOUNTING', 'V Accounting', 'PRIVATE', true),
    ('150251b2-58e1-4981-b05c-d8a9538786cc', 'OFFICE', 'V Office', 'PUBLIC', true);

INSERT INTO public.roles (id, code, name)
VALUES
    ('b13f6113-20e7-4f35-9711-5e4c9a7e4738', 'accountant', 'Accountant'),
    ('f9cb0362-3cf2-4f55-814d-788c52016318', 'admin', 'Administrator'),
    ('a920c985-595b-476c-8221-5815bf17c4fe', 'client_owner', 'Client owner'),
    ('9ae73810-5674-4fee-8cd3-728558bcf532', 'client_staff', 'Client staff'),
    ('af343e28-e831-4075-b057-602e68f248f6', 'manager', 'Manager'),
    ('396b6188-e76d-4d82-bb34-02810a285d1b', 'payroll', 'Payroll'),
    ('0ce20ca9-ecc0-444c-9174-e5fb53e920d8', 'upload_only', 'Upload only');

INSERT INTO public.permissions (id, code, name)
VALUES
    ('e03cdcb8-960d-4fbe-bce8-4999994e35df', 'documents.create', 'documents.create'),
    ('af0cdf3f-1078-4f3a-a860-cff46befbe3b', 'documents.delete', 'documents.delete'),
    ('2ccd8982-f41b-470e-b7b3-c34bc2c9016f', 'documents.edit', 'documents.edit'),
    ('1888d5f7-3584-4f5f-912d-6c7ad253071f', 'documents.view', 'documents.view'),
    ('8a7d969a-ffa2-4284-8270-0b499ca54ef8', 'import.execute', 'import.execute'),
    ('321f2fdd-67d4-453d-b30d-d0ba49ba2cd8', 'journal.create', 'journal.create'),
    ('f6f83cb3-bb0e-40e6-af3e-9412c83e8463', 'journal.delete_draft', 'journal.delete_draft'),
    ('4b3113ff-2faa-4751-8b30-f4af8c2fc9de', 'journal.delete_posted', 'journal.delete_posted'),
    ('2d0d4cb3-07ef-4e8c-8347-75caafa8fb7f', 'journal.edit_draft', 'journal.edit_draft'),
    ('d502c180-48af-49fb-a199-03a8a8e4adca', 'journal.edit_posted', 'journal.edit_posted'),
    ('e6a011c4-90bb-42ce-9db8-73f39afdfc5d', 'journal.post', 'journal.post'),
    ('b2ed2fd8-27b1-4660-a2fb-48e1c2c9452b', 'journal.reverse', 'journal.reverse'),
    ('50a83d00-e8de-4730-a936-bd5e52e955d1', 'period.close', 'period.close'),
    ('086731d5-8305-40e2-9278-cf6d758ff0e9', 'period.lock', 'period.lock'),
    ('3603a36b-8fff-40dd-95ee-fadf13e0d6de', 'period.reopen', 'period.reopen'),
    ('bcf1aae9-ef3a-4c84-a086-e9df1158cd18', 'period.unlock', 'period.unlock'),
    ('dabfb333-be22-4719-856e-5fbba6b454a7', 'settlement.create', 'settlement.create'),
    ('c364fd01-230c-4b67-8dfe-6cc369b8f98d', 'settlement.delete', 'settlement.delete'),
    ('9e0005a0-6e65-4bef-8e92-9374cffd9ab0', 'settlement.edit', 'settlement.edit'),
    ('ce279eb1-dd55-4650-870f-12b9b3bed28b', 'vat.correct', 'vat.correct'),
    ('b1f493f4-0e0b-4643-b2a3-d9a1288d6cde', 'vat.finalize', 'vat.finalize'),
    ('31a001eb-2ec5-4043-ab42-03ab6f09b450', 'vat.generate', 'vat.generate'),
    ('3865add7-702c-45c6-8b5e-e56544347122', 'vat.reopen', 'vat.reopen');
