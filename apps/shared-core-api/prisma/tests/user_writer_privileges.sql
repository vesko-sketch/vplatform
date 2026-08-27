\set ON_ERROR_STOP on

DO $$
DECLARE role_row record;
BEGIN
  SELECT * INTO STRICT role_row FROM pg_roles WHERE rolname='shared_core_user_writer';
  IF role_row.rolsuper OR role_row.rolcreaterole OR role_row.rolcreatedb OR role_row.rolbypassrls OR role_row.rolreplication THEN
    RAISE EXCEPTION 'user writer has forbidden role attributes';
  END IF;
  IF has_schema_privilege('shared_core_user_writer','public','CREATE')
     OR has_table_privilege('shared_core_user_writer','public.users','DELETE')
     OR has_table_privilege('shared_core_user_writer','public.user_invitations','DELETE')
     OR has_table_privilege('shared_core_user_writer','public.user_external_identities','UPDATE')
     OR has_table_privilege('shared_core_user_writer','public.audit_log','UPDATE')
     OR has_table_privilege('shared_core_user_writer','public.integration_outbox','UPDATE') THEN
    RAISE EXCEPTION 'user writer has forbidden mutation privilege';
  END IF;
  IF NOT has_column_privilege('shared_core_user_writer','public.users','lifecycle_status','UPDATE')
     OR NOT has_column_privilege('shared_core_user_writer','public.user_invitations','status','UPDATE')
     OR NOT has_column_privilege('shared_core_user_writer','public.user_external_identities','subject','INSERT')
     OR NOT has_column_privilege('shared_core_user_writer','public.audit_log','action','INSERT')
     OR NOT has_column_privilege('shared_core_user_writer','public.integration_outbox','event_type','INSERT') THEN
    RAISE EXCEPTION 'user writer is missing reviewed privilege';
  END IF;
  IF has_column_privilege('shared_core_user_writer','public.users','metadata','UPDATE')
     OR has_column_privilege('shared_core_user_writer','public.permissions','is_active','UPDATE')
     OR has_column_privilege('shared_core_user_writer','public.user_application_roles','is_active','UPDATE')
     OR has_column_privilege('shared_core_user_writer','public.user_firm_applications','is_active','UPDATE') THEN
    RAISE EXCEPTION 'user writer can mutate forbidden data';
  END IF;
END
$$;

BEGIN;
SET LOCAL ROLE shared_core_user_writer;
INSERT INTO public.users (id,email,display_name,is_active,lifecycle_status)
VALUES ('97000000-0000-4000-8000-000000000001','writer-invitee@vplatform.invalid','Writer Invitee',false,'INVITED');
INSERT INTO public.user_invitations
 (id,user_id,application_id,invited_email,normalized_email,token_digest,expires_at,created_by)
VALUES ('97000000-0000-4000-8000-000000000002','97000000-0000-4000-8000-000000000001',
 '150251b2-58e1-4981-b05c-d8a9538786cc','writer-invitee@vplatform.invalid','writer-invitee@vplatform.invalid',
 decode(repeat('44',32),'hex'),now()+interval '48 hours','97000000-0000-4000-8000-000000000001');
INSERT INTO public.audit_log (user_id,entity_type,entity_id,action,source_type)
VALUES ('97000000-0000-4000-8000-000000000001','user_invitation','97000000-0000-4000-8000-000000000002','user.invitation.created','shared-core-api');
INSERT INTO public.integration_outbox (id,entity_type,entity_id,event_type,payload,source_application_code)
VALUES ('97000000-0000-4000-8000-000000000003','user_invitation','97000000-0000-4000-8000-000000000002',
 'user.invitation.created','{"deliveryEnvelope":"encrypted"}','OFFICE');

DO $$
BEGIN
  BEGIN
    DELETE FROM public.user_invitations WHERE id='97000000-0000-4000-8000-000000000002';
    RAISE EXCEPTION 'invitation DELETE unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    UPDATE public.users SET metadata='{"forbidden":true}' WHERE id='97000000-0000-4000-8000-000000000001';
    RAISE EXCEPTION 'metadata update unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    INSERT INTO public.user_application_roles (user_id,application_id,role_id)
    VALUES ('97000000-0000-4000-8000-000000000001','150251b2-58e1-4981-b05c-d8a9538786cc','f9cb0362-3cf2-4f55-814d-788c52016318');
    RAISE EXCEPTION 'application-role write unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    CREATE TABLE public.forbidden_user_writer_table(id integer);
    RAISE EXCEPTION 'schema CREATE unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END
$$;
ROLLBACK;

DROP OWNED BY shared_core_user_writer;
DROP ROLE shared_core_user_writer;

SELECT 'user writer disposable privileges verified' AS result;
