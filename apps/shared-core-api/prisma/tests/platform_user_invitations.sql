\set ON_ERROR_STOP on

BEGIN;

INSERT INTO public.users (id,email,display_name,is_active,lifecycle_status)
VALUES
 ('96000000-0000-4000-8000-000000000001','inviter@vplatform.invalid','Inviter',true,'ACTIVE'),
 ('96000000-0000-4000-8000-000000000002','invitee@vplatform.invalid','Invitee',false,'INVITED'),
 ('96000000-0000-4000-8000-000000000003','other@vplatform.invalid','Other',true,'ACTIVE'),
 ('96000000-0000-4000-8000-000000000005','expired@vplatform.invalid','Expired',false,'INVITED');

INSERT INTO public.user_application_roles (id,user_id,application_id,role_id)
VALUES ('96000000-0000-4000-8000-000000000004','96000000-0000-4000-8000-000000000001',
        '150251b2-58e1-4981-b05c-d8a9538786cc','f9cb0362-3cf2-4f55-814d-788c52016318');

INSERT INTO public.user_invitations
 (id,user_id,application_id,invited_email,normalized_email,token_digest,expires_at,created_by)
VALUES
 ('96000000-0000-4000-8000-000000000010','96000000-0000-4000-8000-000000000002',
  '150251b2-58e1-4981-b05c-d8a9538786cc','invitee@vplatform.invalid','invitee@vplatform.invalid',
  decode(repeat('11',32),'hex'),now()+interval '48 hours','96000000-0000-4000-8000-000000000001');

DO $$
BEGIN
  BEGIN
    INSERT INTO public.user_invitations
     (user_id,application_id,invited_email,normalized_email,token_digest,expires_at,created_by)
    VALUES ('96000000-0000-4000-8000-000000000002','150251b2-58e1-4981-b05c-d8a9538786cc',
      'invitee@vplatform.invalid','invitee@vplatform.invalid',decode(repeat('22',32),'hex'),
      now()+interval '48 hours','96000000-0000-4000-8000-000000000001');
    RAISE EXCEPTION 'duplicate pending invitation unexpectedly succeeded';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO public.user_invitations
     (user_id,application_id,invited_email,normalized_email,token_digest,expires_at,created_by)
    VALUES ('96000000-0000-4000-8000-000000000003','150251b2-58e1-4981-b05c-d8a9538786cc',
      'INVITEE@vplatform.invalid','invitee@vplatform.invalid',decode(repeat('55',32),'hex'),
      now()+interval '48 hours','96000000-0000-4000-8000-000000000001');
    RAISE EXCEPTION 'same-email pending ambiguity unexpectedly succeeded';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO public.user_invitations
     (user_id,application_id,invited_email,normalized_email,token_digest,expires_at,created_by)
    VALUES ('96000000-0000-4000-8000-000000000003','150251b2-58e1-4981-b05c-d8a9538786cc',
      'other@vplatform.invalid','other@vplatform.invalid',decode(repeat('11',32),'hex'),
      now()+interval '48 hours','96000000-0000-4000-8000-000000000001');
    RAISE EXCEPTION 'digest collision unexpectedly succeeded';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
END
$$;

UPDATE public.user_invitations
SET status='CANCELLED',cancelled_at=now(),cancelled_by='96000000-0000-4000-8000-000000000001',
    cancellation_reason='Replacement requested'
WHERE id='96000000-0000-4000-8000-000000000010' AND status='PENDING' AND row_version=1;

DO $$
DECLARE changed integer;
BEGIN
  UPDATE public.user_invitations SET status='CONSUMED',consumed_at=now()
  WHERE id='96000000-0000-4000-8000-000000000010' AND status='PENDING';
  GET DIAGNOSTICS changed = ROW_COUNT;
  IF changed <> 0 THEN RAISE EXCEPTION 'cancelled invitation replay succeeded'; END IF;
END
$$;

INSERT INTO public.user_invitations
 (id,user_id,application_id,invited_email,normalized_email,token_digest,expires_at,created_by)
VALUES
 ('96000000-0000-4000-8000-000000000012','96000000-0000-4000-8000-000000000005',
  '150251b2-58e1-4981-b05c-d8a9538786cc','expired@vplatform.invalid','expired@vplatform.invalid',
  decode(repeat('66',32),'hex'),now()+interval '1 second','96000000-0000-4000-8000-000000000001');

DO $$
DECLARE changed integer;
BEGIN
  UPDATE public.user_invitations SET status='CONSUMED',consumed_at=now()
  WHERE id='96000000-0000-4000-8000-000000000012' AND status='PENDING'
    AND expires_at > now()+interval '2 seconds';
  GET DIAGNOSTICS changed = ROW_COUNT;
  IF changed <> 0 THEN RAISE EXCEPTION 'expired invitation replay succeeded'; END IF;
END
$$;

INSERT INTO public.user_invitations
 (id,user_id,application_id,invited_email,normalized_email,token_digest,expires_at,created_by)
VALUES
 ('96000000-0000-4000-8000-000000000011','96000000-0000-4000-8000-000000000002',
  '150251b2-58e1-4981-b05c-d8a9538786cc','invitee@vplatform.invalid','invitee@vplatform.invalid',
  decode(repeat('33',32),'hex'),now()+interval '48 hours','96000000-0000-4000-8000-000000000001');

INSERT INTO public.user_external_identities
 (id,user_id,issuer,subject,status,link_provenance,linked_by)
VALUES
 ('96000000-0000-4000-8000-000000000020','96000000-0000-4000-8000-000000000002',
  'https://identity.test/realms/vplatform','opaque-subject','active','invitation',
  '96000000-0000-4000-8000-000000000001');

DO $$
DECLARE changed integer;
BEGIN
  UPDATE public.user_invitations
  SET status='CONSUMED',consumed_at=now(),consumed_identity_id='96000000-0000-4000-8000-000000000020'
  WHERE id='96000000-0000-4000-8000-000000000011' AND status='PENDING'
    AND expires_at>now() AND row_version=1;
  GET DIAGNOSTICS changed = ROW_COUNT;
  IF changed <> 1 THEN RAISE EXCEPTION 'first consumption failed'; END IF;
  UPDATE public.user_invitations SET consumed_at=now()
  WHERE id='96000000-0000-4000-8000-000000000011' AND status='PENDING';
  GET DIAGNOSTICS changed = ROW_COUNT;
  IF changed <> 0 THEN RAISE EXCEPTION 'replay consumption succeeded'; END IF;
  BEGIN
    INSERT INTO public.user_external_identities
     (user_id,issuer,subject,status,link_provenance)
    VALUES ('96000000-0000-4000-8000-000000000003','https://identity.test/realms/vplatform',
      'opaque-subject','active','administrator');
    RAISE EXCEPTION 'historical subject reassignment unexpectedly succeeded';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO public.user_external_identities
     (user_id,issuer,subject,status,link_provenance)
    VALUES ('96000000-0000-4000-8000-000000000002','https://identity.test/realms/vplatform',
      'second-subject','active','administrator');
    RAISE EXCEPTION 'second active identity for issuer unexpectedly succeeded';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
END
$$;

UPDATE public.users SET lifecycle_status='ACTIVE',is_active=true
WHERE id='96000000-0000-4000-8000-000000000002' AND row_version=1;
UPDATE public.users SET lifecycle_status='DISABLED',is_active=false
WHERE id='96000000-0000-4000-8000-000000000002' AND row_version=2;

DO $$
BEGIN
  BEGIN
    UPDATE public.users SET lifecycle_status='ACTIVE',is_active=true
    WHERE id='96000000-0000-4000-8000-000000000002';
    INSERT INTO public.audit_log (entity_type,action) VALUES (NULL,'forced.failure');
  EXCEPTION WHEN not_null_violation THEN NULL;
  END;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id='96000000-0000-4000-8000-000000000002' AND lifecycle_status='DISABLED' AND NOT is_active) THEN
    RAISE EXCEPTION 'audit failure did not roll back user mutation';
  END IF;
END
$$;

DO $$
BEGIN
  BEGIN
    UPDATE public.user_invitations SET expires_at=expires_at+interval '1 hour'
    WHERE id='96000000-0000-4000-8000-000000000012';
    INSERT INTO public.integration_outbox (entity_type,entity_id,event_type)
    VALUES (NULL,'96000000-0000-4000-8000-000000000012','forced.failure');
  EXCEPTION WHEN not_null_violation THEN NULL;
  END;
  IF (SELECT row_version FROM public.user_invitations WHERE id='96000000-0000-4000-8000-000000000012') <> 1 THEN
    RAISE EXCEPTION 'outbox failure did not roll back invitation mutation';
  END IF;
END
$$;

INSERT INTO public.audit_log (user_id,entity_type,entity_id,action,new_values,source_type)
VALUES ('96000000-0000-4000-8000-000000000001','user_invitation',
        '96000000-0000-4000-8000-000000000011','user.invitation.consumed',
        '{"status":"CONSUMED"}','shared-core-api');
INSERT INTO public.integration_outbox
 (id,entity_type,entity_id,event_type,payload,source_application_code)
VALUES ('96000000-0000-4000-8000-000000000030','user_invitation',
        '96000000-0000-4000-8000-000000000011','user.invitation.created',
        '{"deliveryEnvelope":"encrypted-test-envelope"}','OFFICE');

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.integration_outbox WHERE id='96000000-0000-4000-8000-000000000030' AND payload::text LIKE '%replacement-token%') THEN
    RAISE EXCEPTION 'raw token leaked to outbox';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE id='96000000-0000-4000-8000-000000000002' AND lifecycle_status='DISABLED' AND NOT is_active) THEN
    RAISE EXCEPTION 'disabled lifecycle gate failed';
  END IF;
END
$$;

ROLLBACK;

SELECT 'platform user invitation disposable behavior verified' AS result;
