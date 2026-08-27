BEGIN;

DO $$
BEGIN
    IF (SELECT count(*) FROM public.permissions) <> 106
       OR (SELECT md5(string_agg(id::text || '|' || application_id::text || '|' || code || '|' || scope_type || '|' || is_active::text, E'\n' ORDER BY id)) FROM public.permissions)
          <> '8657115155c186ece70ee5baa905c650' THEN
        RAISE EXCEPTION 'Reviewed permission catalog drift detected';
    END IF;
    IF (SELECT count(*) FROM public.role_permissions) <> 324
       OR (SELECT md5(string_agg(id::text || '|' || role_id::text || '|' || permission_id::text || '|' || is_active::text, E'\n' ORDER BY id)) FROM public.role_permissions)
          <> '47854aeaa8802726b3055f1c524c4b53' THEN
        RAISE EXCEPTION 'Reviewed role-permission catalog drift detected';
    END IF;
    IF (SELECT count(*) FROM public.applications WHERE id='150251b2-58e1-4981-b05c-d8a9538786cc' AND code='OFFICE' AND is_active) <> 1 THEN
        RAISE EXCEPTION 'Reviewed active OFFICE application not found';
    END IF;
    IF (SELECT count(*) FROM public.roles WHERE code IN ('admin','manager','accountant','payroll','client_owner','client_staff','upload_only') AND is_active) <> 7 THEN
        RAISE EXCEPTION 'Reviewed active role catalog drift detected';
    END IF;
    IF to_regclass('public.user_invitations') IS NOT NULL
       OR EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='users' AND column_name='lifecycle_status') THEN
        RAISE EXCEPTION 'User lifecycle schema already exists';
    END IF;
END
$$;

ALTER TABLE public.users ADD COLUMN lifecycle_status varchar(20);
UPDATE public.users SET lifecycle_status = CASE WHEN is_active THEN 'ACTIVE' ELSE 'DISABLED' END;
ALTER TABLE public.users ALTER COLUMN lifecycle_status SET NOT NULL;
ALTER TABLE public.users
    ADD CONSTRAINT users_lifecycle_status_check CHECK (lifecycle_status IN ('INVITED','ACTIVE','DISABLED')),
    ADD CONSTRAINT users_lifecycle_active_check CHECK (is_active = (lifecycle_status = 'ACTIVE')),
    ADD CONSTRAINT users_email_normalized_check CHECK (email = lower(btrim(email)) AND email <> '');
CREATE INDEX idx_users_lifecycle_status ON public.users (lifecycle_status, created_at);
CREATE UNIQUE INDEX user_external_identities_active_user_issuer_key
    ON public.user_external_identities (user_id, issuer) WHERE status='active';

CREATE TABLE public.user_invitations (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES public.users(id),
    application_id uuid NOT NULL REFERENCES public.applications(id),
    invited_email varchar(255) NOT NULL,
    normalized_email varchar(255) NOT NULL,
    token_digest bytea NOT NULL,
    status varchar(20) NOT NULL DEFAULT 'PENDING',
    expires_at timestamptz NOT NULL,
    consumed_at timestamptz,
    consumed_identity_id uuid REFERENCES public.user_external_identities(id),
    cancelled_at timestamptz,
    cancelled_by uuid REFERENCES public.users(id),
    cancellation_reason text,
    created_by uuid NOT NULL REFERENCES public.users(id),
    request_id uuid,
    correlation_id uuid,
    row_version bigint NOT NULL DEFAULT 1,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT user_invitations_token_digest_length_check CHECK (octet_length(token_digest) = 32),
    CONSTRAINT user_invitations_email_check CHECK (
        normalized_email = lower(btrim(normalized_email))
        AND normalized_email = lower(btrim(invited_email))
        AND normalized_email <> ''
    ),
    CONSTRAINT user_invitations_expiration_check CHECK (expires_at > created_at),
    CONSTRAINT user_invitations_status_check CHECK (status IN ('PENDING','CONSUMED','CANCELLED')),
    CONSTRAINT user_invitations_state_check CHECK (
        (status='PENDING' AND consumed_at IS NULL AND consumed_identity_id IS NULL AND cancelled_at IS NULL AND cancelled_by IS NULL AND cancellation_reason IS NULL)
        OR (status='CONSUMED' AND consumed_at IS NOT NULL AND consumed_identity_id IS NOT NULL AND cancelled_at IS NULL AND cancelled_by IS NULL AND cancellation_reason IS NULL)
        OR (status='CANCELLED' AND consumed_at IS NULL AND consumed_identity_id IS NULL AND cancelled_at IS NOT NULL AND cancelled_by IS NOT NULL AND NULLIF(btrim(cancellation_reason),'') IS NOT NULL)
    ),
    CONSTRAINT user_invitations_token_digest_key UNIQUE (token_digest)
);
CREATE UNIQUE INDEX user_invitations_pending_user_key
    ON public.user_invitations (user_id) WHERE status='PENDING';
CREATE UNIQUE INDEX user_invitations_pending_email_key
    ON public.user_invitations (normalized_email) WHERE status='PENDING';
CREATE INDEX idx_user_invitations_application_status
    ON public.user_invitations (application_id, status, created_at DESC);
CREATE INDEX idx_user_invitations_expiration
    ON public.user_invitations (expires_at) WHERE status='PENDING';
CREATE TRIGGER trg_user_invitations_set_updated_at
    BEFORE UPDATE ON public.user_invitations
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();

CREATE TEMPORARY TABLE new_user_admin_permissions (
    id uuid PRIMARY KEY,
    code varchar(100) UNIQUE NOT NULL
) ON COMMIT DROP;
INSERT INTO new_user_admin_permissions VALUES
    ('278da5b0-2f92-5871-8d43-36eada0e886f','users.catalog.view'),
    ('8a995ced-9ab5-5277-890e-a3da26fb8498','users.invite'),
    ('7b40e1cc-71a0-5c3d-9605-a3e2469d4bf5','users.platform.disable'),
    ('9fb51883-790e-50d0-8678-e29477e0d001','users.platform.reactivate'),
    ('dc627646-5baa-5a5b-8234-43bb84846dba','users.invitations.view'),
    ('9109f371-f3fc-5194-932c-a75659ed2320','users.invitations.cancel');

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM new_user_admin_permissions expected JOIN public.permissions actual
          ON actual.id=expected.id OR (actual.application_id='150251b2-58e1-4981-b05c-d8a9538786cc' AND actual.code=expected.code)
    ) THEN RAISE EXCEPTION 'User administration permission UUID or code collision'; END IF;
END
$$;

INSERT INTO public.permissions (id,application_id,code,name,scope_type)
SELECT id,'150251b2-58e1-4981-b05c-d8a9538786cc',code,code,'APPLICATION'
FROM new_user_admin_permissions;

CREATE TEMPORARY TABLE new_user_admin_role_permissions (
    id uuid PRIMARY KEY, role_code varchar(50) NOT NULL, permission_code varchar(100) NOT NULL,
    UNIQUE(role_code,permission_code)
) ON COMMIT DROP;
INSERT INTO new_user_admin_role_permissions VALUES
    ('6f5b9d5c-2243-5bde-a738-521357513e5a','admin','users.catalog.view'),
    ('31f37e3b-72ec-5da2-8e7d-41a13d2fc933','admin','users.invite'),
    ('cc15ea8a-00ec-5a26-83a6-718a176685cf','admin','users.platform.disable'),
    ('1d980ff9-3824-5d03-b727-34340a2cc7dc','admin','users.platform.reactivate'),
    ('611e80b9-ac10-5653-afd4-a981d4fb46c4','admin','users.invitations.view'),
    ('648917f5-9062-5528-ad62-80261766e196','admin','users.invitations.cancel'),
    ('f0520cbd-38ba-5f86-a21f-3597d30fa702','manager','users.catalog.view'),
    ('82419fa9-f7a1-5d82-9eee-274c1657b895','manager','users.invite'),
    ('b0ab5d2b-0561-5e15-8fe2-80c888c4cfe7','manager','users.invitations.view'),
    ('4407426e-a9db-568f-b11e-a2de414ba83f','manager','users.invitations.cancel');

INSERT INTO public.role_permissions (id,role_id,permission_id)
SELECT expected.id,role.id,permission.id
FROM new_user_admin_role_permissions expected
JOIN public.roles role ON role.code=expected.role_code AND role.is_active
JOIN public.permissions permission ON permission.application_id='150251b2-58e1-4981-b05c-d8a9538786cc' AND permission.code=expected.permission_code;

DO $$
BEGIN
    IF (SELECT count(*) FROM public.permissions) <> 112 OR (SELECT count(*) FROM public.role_permissions) <> 334 THEN
        RAISE EXCEPTION 'User administration catalog postcondition failed';
    END IF;
    IF (SELECT count(*) FROM public.permissions WHERE application_id='150251b2-58e1-4981-b05c-d8a9538786cc' AND scope_type='APPLICATION') <> 20 THEN
        RAISE EXCEPTION 'OFFICE APPLICATION permission postcondition failed';
    END IF;
END
$$;

COMMIT;
