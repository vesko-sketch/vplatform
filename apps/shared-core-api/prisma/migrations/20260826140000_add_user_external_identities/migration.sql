CREATE TABLE public.user_external_identities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    issuer text NOT NULL,
    subject text NOT NULL,
    status character varying(20) DEFAULT 'active'::character varying NOT NULL,
    link_provenance character varying(30) NOT NULL,
    linked_by uuid,
    linked_at timestamp with time zone DEFAULT now() NOT NULL,
    status_changed_by uuid,
    status_changed_at timestamp with time zone DEFAULT now() NOT NULL,
    status_change_reason text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,

    CONSTRAINT user_external_identities_issuer_length_check
        CHECK (length(issuer) BETWEEN 1 AND 2048),

    CONSTRAINT user_external_identities_subject_length_check
        CHECK (length(subject) BETWEEN 1 AND 255),

    CONSTRAINT user_external_identities_status_check
        CHECK (
            status::text = ANY (
                ARRAY[
                    'active'::character varying,
                    'disabled'::character varying,
                    'unlinked'::character varying
                ]::text[]
            )
        ),

    CONSTRAINT user_external_identities_link_provenance_check
        CHECK (
            link_provenance::text = ANY (
                ARRAY[
                    'invitation'::character varying,
                    'administrator'::character varying,
                    'migration'::character varying,
                    'recovery'::character varying
                ]::text[]
            )
        ),

    CONSTRAINT user_external_identities_inactive_reason_check
        CHECK (
            status = 'active'
            OR nullif(btrim(status_change_reason), '') IS NOT NULL
        )
);

ALTER TABLE ONLY public.user_external_identities
    ADD CONSTRAINT user_external_identities_pkey
    PRIMARY KEY (id);

ALTER TABLE ONLY public.user_external_identities
    ADD CONSTRAINT user_external_identities_issuer_subject_key
    UNIQUE (issuer, subject);

ALTER TABLE ONLY public.user_external_identities
    ADD CONSTRAINT user_external_identities_user_id_fkey
    FOREIGN KEY (user_id)
    REFERENCES public.users(id);

CREATE INDEX idx_user_external_identities_user_status
    ON public.user_external_identities (user_id, status);

CREATE TRIGGER trg_user_external_identities_set_updated_at
    BEFORE UPDATE ON public.user_external_identities
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at_and_row_version();
