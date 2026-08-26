--
-- PostgreSQL database dump
--

\restrict eqgzEMEv4J7he3wQFAsCSptCOODVKcPE2vQSTXmG7UcAoegsYshLmR8kTWo9hxT

-- Dumped from database version 16.13 (Debian 16.13-1.pgdg13+1)
-- Dumped by pg_dump version 16.13 (Debian 16.13-1.pgdg13+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: set_updated_at_and_row_version(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_updated_at_and_row_version() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    NEW.row_version = COALESCE(OLD.row_version, 0) + 1;
    RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: applications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.applications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    access_zone character varying(20) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT applications_access_zone_check CHECK (((access_zone)::text = ANY (ARRAY[('PUBLIC'::character varying)::text, ('PRIVATE'::character varying)::text])))
);


--
-- Name: audit_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid,
    user_id uuid,
    entity_type character varying(100) NOT NULL,
    entity_id uuid,
    action character varying(50) NOT NULL,
    old_values jsonb,
    new_values jsonb,
    reason text,
    source_type character varying(50),
    request_id uuid,
    correlation_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: firm_applications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.firm_applications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    application_id uuid NOT NULL,
    valid_from date,
    valid_to date,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT firm_applications_dates_check CHECK (((valid_to IS NULL) OR (valid_from IS NULL) OR (valid_to >= valid_from)))
);


--
-- Name: firm_group_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.firm_group_members (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_group_id uuid NOT NULL,
    firm_id uuid NOT NULL,
    member_role character varying(50),
    valid_from date,
    valid_to date,
    is_active boolean DEFAULT true NOT NULL,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: firm_group_purpose_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.firm_group_purpose_assignments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_group_id uuid NOT NULL,
    purpose_id uuid NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: firm_group_purposes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.firm_group_purposes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: firm_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.firm_groups (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    default_currency_id uuid,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: firms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.firms (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    short_name character varying(255),
    legal_form_id uuid,
    country_id uuid NOT NULL,
    registration_number character varying(50),
    base_currency_id uuid NOT NULL,
    default_language_id uuid,
    timezone character varying(100) DEFAULT 'Europe/Sofia'::character varying NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    source_system character varying(100),
    external_id character varying(255),
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: integration_outbox; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.integration_outbox (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid,
    entity_type character varying(100) NOT NULL,
    entity_id uuid NOT NULL,
    event_type character varying(100) NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    processing_status character varying(20) DEFAULT 'pending'::character varying NOT NULL,
    retry_count integer DEFAULT 0 NOT NULL,
    last_error text,
    correlation_id uuid,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL,
    processed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    entity_version bigint,
    source_application_code character varying(50),
    CONSTRAINT integration_outbox_processing_status_check CHECK (((processing_status)::text = ANY (ARRAY[('pending'::character varying)::text, ('processing'::character varying)::text, ('processed'::character varying)::text, ('failed'::character varying)::text])))
);


--
-- Name: permission_resource_scopes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.permission_resource_scopes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_firm_role_id uuid,
    user_permission_override_id uuid,
    permission_id uuid NOT NULL,
    resource_type character varying(100) NOT NULL,
    resource_id uuid,
    effect character varying(10) DEFAULT 'allow'::character varying NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT permission_resource_scopes_check CHECK (((user_firm_role_id IS NOT NULL) OR (user_permission_override_id IS NOT NULL))),
    CONSTRAINT permission_resource_scopes_effect_check CHECK (((effect)::text = ANY (ARRAY[('allow'::character varying)::text, ('deny'::character varying)::text])))
);


--
-- Name: permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.permissions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(100) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    requires_reason boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ref_countries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ref_countries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    iso2_code character varying(2) NOT NULL,
    iso3_code character varying(3),
    name_bg character varying(255) NOT NULL,
    name_en character varying(255),
    is_eu_member boolean DEFAULT false NOT NULL,
    is_eea_member boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    source_system character varying(100),
    external_id character varying(255),
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ref_currencies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ref_currencies (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    iso_code character varying(10) NOT NULL,
    name character varying(255) NOT NULL,
    decimal_places integer DEFAULT 2 NOT NULL,
    is_crypto boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    source_system character varying(100),
    external_id character varying(255),
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ref_currencies_decimal_places_check CHECK (((decimal_places >= 0) AND (decimal_places <= 18)))
);


--
-- Name: ref_languages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ref_languages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    iso_code character varying(10) NOT NULL,
    name_bg character varying(100) NOT NULL,
    name_en character varying(100),
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ref_legal_forms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ref_legal_forms (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(50) NOT NULL,
    short_name character varying(100) NOT NULL,
    full_name character varying(500),
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: role_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.role_permissions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    role_id uuid NOT NULL,
    permission_id uuid NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: user_firm_applications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_firm_applications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    firm_id uuid NOT NULL,
    application_id uuid NOT NULL,
    valid_from date,
    valid_to date,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT user_firm_applications_dates_check CHECK (((valid_to IS NULL) OR (valid_from IS NULL) OR (valid_to >= valid_from)))
);


--
-- Name: user_firm_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_firm_roles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    firm_id uuid NOT NULL,
    role_id uuid NOT NULL,
    valid_from date,
    valid_to date,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: user_permission_overrides; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_permission_overrides (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    firm_id uuid,
    permission_id uuid NOT NULL,
    effect character varying(10) NOT NULL,
    valid_from date,
    valid_to date,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT user_permission_overrides_effect_check CHECK (((effect)::text = ANY (ARRAY[('allow'::character varying)::text, ('deny'::character varying)::text])))
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email character varying(255) NOT NULL,
    display_name character varying(255),
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: applications applications_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_code_key UNIQUE (code);


--
-- Name: applications applications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_pkey PRIMARY KEY (id);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- Name: firm_applications firm_applications_firm_application_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_applications
    ADD CONSTRAINT firm_applications_firm_application_key UNIQUE (firm_id, application_id);


--
-- Name: firm_applications firm_applications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_applications
    ADD CONSTRAINT firm_applications_pkey PRIMARY KEY (id);


--
-- Name: firm_group_members firm_group_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_group_members
    ADD CONSTRAINT firm_group_members_pkey PRIMARY KEY (id);


--
-- Name: firm_group_purpose_assignments firm_group_purpose_assignments_firm_group_id_purpose_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_group_purpose_assignments
    ADD CONSTRAINT firm_group_purpose_assignments_firm_group_id_purpose_id_key UNIQUE (firm_group_id, purpose_id);


--
-- Name: firm_group_purpose_assignments firm_group_purpose_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_group_purpose_assignments
    ADD CONSTRAINT firm_group_purpose_assignments_pkey PRIMARY KEY (id);


--
-- Name: firm_group_purposes firm_group_purposes_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_group_purposes
    ADD CONSTRAINT firm_group_purposes_code_key UNIQUE (code);


--
-- Name: firm_group_purposes firm_group_purposes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_group_purposes
    ADD CONSTRAINT firm_group_purposes_pkey PRIMARY KEY (id);


--
-- Name: firm_groups firm_groups_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_groups
    ADD CONSTRAINT firm_groups_code_key UNIQUE (code);


--
-- Name: firm_groups firm_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_groups
    ADD CONSTRAINT firm_groups_pkey PRIMARY KEY (id);


--
-- Name: firms firms_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firms
    ADD CONSTRAINT firms_code_key UNIQUE (code);


--
-- Name: firms firms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firms
    ADD CONSTRAINT firms_pkey PRIMARY KEY (id);


--
-- Name: integration_outbox integration_outbox_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_outbox
    ADD CONSTRAINT integration_outbox_pkey PRIMARY KEY (id);


--
-- Name: permission_resource_scopes permission_resource_scopes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permission_resource_scopes
    ADD CONSTRAINT permission_resource_scopes_pkey PRIMARY KEY (id);


--
-- Name: permissions permissions_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_code_key UNIQUE (code);


--
-- Name: permissions permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (id);


--
-- Name: ref_countries ref_countries_iso2_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_countries
    ADD CONSTRAINT ref_countries_iso2_code_key UNIQUE (iso2_code);


--
-- Name: ref_countries ref_countries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_countries
    ADD CONSTRAINT ref_countries_pkey PRIMARY KEY (id);


--
-- Name: ref_currencies ref_currencies_iso_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_currencies
    ADD CONSTRAINT ref_currencies_iso_code_key UNIQUE (iso_code);


--
-- Name: ref_currencies ref_currencies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_currencies
    ADD CONSTRAINT ref_currencies_pkey PRIMARY KEY (id);


--
-- Name: ref_languages ref_languages_iso_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_languages
    ADD CONSTRAINT ref_languages_iso_code_key UNIQUE (iso_code);


--
-- Name: ref_languages ref_languages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_languages
    ADD CONSTRAINT ref_languages_pkey PRIMARY KEY (id);


--
-- Name: ref_legal_forms ref_legal_forms_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_legal_forms
    ADD CONSTRAINT ref_legal_forms_code_key UNIQUE (code);


--
-- Name: ref_legal_forms ref_legal_forms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_legal_forms
    ADD CONSTRAINT ref_legal_forms_pkey PRIMARY KEY (id);


--
-- Name: role_permissions role_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_pkey PRIMARY KEY (id);


--
-- Name: role_permissions role_permissions_role_id_permission_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_role_id_permission_id_key UNIQUE (role_id, permission_id);


--
-- Name: roles roles_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_code_key UNIQUE (code);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: user_firm_applications user_firm_applications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_firm_applications
    ADD CONSTRAINT user_firm_applications_pkey PRIMARY KEY (id);


--
-- Name: user_firm_applications user_firm_applications_user_firm_application_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_firm_applications
    ADD CONSTRAINT user_firm_applications_user_firm_application_key UNIQUE (user_id, firm_id, application_id);


--
-- Name: user_firm_roles user_firm_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_firm_roles
    ADD CONSTRAINT user_firm_roles_pkey PRIMARY KEY (id);


--
-- Name: user_firm_roles user_firm_roles_user_id_firm_id_role_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_firm_roles
    ADD CONSTRAINT user_firm_roles_user_id_firm_id_role_id_key UNIQUE (user_id, firm_id, role_id);


--
-- Name: user_permission_overrides user_permission_overrides_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_permission_overrides
    ADD CONSTRAINT user_permission_overrides_pkey PRIMARY KEY (id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_audit_log_entity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_log_entity ON public.audit_log USING btree (entity_type, entity_id);


--
-- Name: idx_audit_log_firm_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_log_firm_date ON public.audit_log USING btree (firm_id, created_at);


--
-- Name: idx_firm_applications_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_firm_applications_active ON public.firm_applications USING btree (firm_id, is_active) WHERE (is_active = true);


--
-- Name: idx_firm_applications_application; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_firm_applications_application ON public.firm_applications USING btree (application_id);


--
-- Name: idx_integration_outbox_firm_entity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_integration_outbox_firm_entity ON public.integration_outbox USING btree (firm_id, entity_type, entity_id);


--
-- Name: idx_integration_outbox_pending; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_integration_outbox_pending ON public.integration_outbox USING btree (processing_status, occurred_at);


--
-- Name: idx_user_firm_applications_active_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_firm_applications_active_lookup ON public.user_firm_applications USING btree (user_id, firm_id, application_id) WHERE (is_active = true);


--
-- Name: idx_user_firm_applications_application; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_firm_applications_application ON public.user_firm_applications USING btree (application_id);


--
-- Name: idx_user_firm_applications_firm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_firm_applications_firm ON public.user_firm_applications USING btree (firm_id);


--
-- Name: uq_firms_registration_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_firms_registration_number ON public.firms USING btree (country_id, registration_number) WHERE (registration_number IS NOT NULL);


--
-- Name: applications trg_applications_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_applications_set_updated_at BEFORE UPDATE ON public.applications FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: firm_applications trg_firm_applications_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firm_applications_set_updated_at BEFORE UPDATE ON public.firm_applications FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: firm_group_members trg_firm_group_members_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firm_group_members_set_updated_at BEFORE UPDATE ON public.firm_group_members FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: firm_group_purpose_assignments trg_firm_group_purpose_assignments_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firm_group_purpose_assignments_set_updated_at BEFORE UPDATE ON public.firm_group_purpose_assignments FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: firm_group_purposes trg_firm_group_purposes_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firm_group_purposes_set_updated_at BEFORE UPDATE ON public.firm_group_purposes FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: firm_groups trg_firm_groups_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firm_groups_set_updated_at BEFORE UPDATE ON public.firm_groups FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: firms trg_firms_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firms_set_updated_at BEFORE UPDATE ON public.firms FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: permission_resource_scopes trg_permission_resource_scopes_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_permission_resource_scopes_set_updated_at BEFORE UPDATE ON public.permission_resource_scopes FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: permissions trg_permissions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_permissions_set_updated_at BEFORE UPDATE ON public.permissions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: ref_countries trg_ref_countries_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ref_countries_set_updated_at BEFORE UPDATE ON public.ref_countries FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: ref_currencies trg_ref_currencies_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ref_currencies_set_updated_at BEFORE UPDATE ON public.ref_currencies FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: ref_languages trg_ref_languages_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ref_languages_set_updated_at BEFORE UPDATE ON public.ref_languages FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: ref_legal_forms trg_ref_legal_forms_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ref_legal_forms_set_updated_at BEFORE UPDATE ON public.ref_legal_forms FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: role_permissions trg_role_permissions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_role_permissions_set_updated_at BEFORE UPDATE ON public.role_permissions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: roles trg_roles_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_roles_set_updated_at BEFORE UPDATE ON public.roles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: user_firm_applications trg_user_firm_applications_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_user_firm_applications_set_updated_at BEFORE UPDATE ON public.user_firm_applications FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: user_firm_roles trg_user_firm_roles_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_user_firm_roles_set_updated_at BEFORE UPDATE ON public.user_firm_roles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: user_permission_overrides trg_user_permission_overrides_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_user_permission_overrides_set_updated_at BEFORE UPDATE ON public.user_permission_overrides FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: users trg_users_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_users_set_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: firm_applications firm_applications_application_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_applications
    ADD CONSTRAINT firm_applications_application_id_fkey FOREIGN KEY (application_id) REFERENCES public.applications(id);


--
-- Name: firm_applications firm_applications_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_applications
    ADD CONSTRAINT firm_applications_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: firm_group_members firm_group_members_firm_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_group_members
    ADD CONSTRAINT firm_group_members_firm_group_id_fkey FOREIGN KEY (firm_group_id) REFERENCES public.firm_groups(id);


--
-- Name: firm_group_members firm_group_members_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_group_members
    ADD CONSTRAINT firm_group_members_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: firm_group_purpose_assignments firm_group_purpose_assignments_firm_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_group_purpose_assignments
    ADD CONSTRAINT firm_group_purpose_assignments_firm_group_id_fkey FOREIGN KEY (firm_group_id) REFERENCES public.firm_groups(id);


--
-- Name: firm_group_purpose_assignments firm_group_purpose_assignments_purpose_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_group_purpose_assignments
    ADD CONSTRAINT firm_group_purpose_assignments_purpose_id_fkey FOREIGN KEY (purpose_id) REFERENCES public.firm_group_purposes(id);


--
-- Name: firm_groups firm_groups_default_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_groups
    ADD CONSTRAINT firm_groups_default_currency_id_fkey FOREIGN KEY (default_currency_id) REFERENCES public.ref_currencies(id);


--
-- Name: firms firms_base_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firms
    ADD CONSTRAINT firms_base_currency_id_fkey FOREIGN KEY (base_currency_id) REFERENCES public.ref_currencies(id);


--
-- Name: firms firms_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firms
    ADD CONSTRAINT firms_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.ref_countries(id);


--
-- Name: firms firms_default_language_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firms
    ADD CONSTRAINT firms_default_language_id_fkey FOREIGN KEY (default_language_id) REFERENCES public.ref_languages(id);


--
-- Name: firms firms_legal_form_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firms
    ADD CONSTRAINT firms_legal_form_id_fkey FOREIGN KEY (legal_form_id) REFERENCES public.ref_legal_forms(id);


--
-- Name: integration_outbox integration_outbox_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_outbox
    ADD CONSTRAINT integration_outbox_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: permission_resource_scopes permission_resource_scopes_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permission_resource_scopes
    ADD CONSTRAINT permission_resource_scopes_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES public.permissions(id);


--
-- Name: permission_resource_scopes permission_resource_scopes_user_firm_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permission_resource_scopes
    ADD CONSTRAINT permission_resource_scopes_user_firm_role_id_fkey FOREIGN KEY (user_firm_role_id) REFERENCES public.user_firm_roles(id);


--
-- Name: permission_resource_scopes permission_resource_scopes_user_permission_override_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permission_resource_scopes
    ADD CONSTRAINT permission_resource_scopes_user_permission_override_id_fkey FOREIGN KEY (user_permission_override_id) REFERENCES public.user_permission_overrides(id);


--
-- Name: role_permissions role_permissions_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES public.permissions(id);


--
-- Name: role_permissions role_permissions_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id);


--
-- Name: user_firm_applications user_firm_applications_application_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_firm_applications
    ADD CONSTRAINT user_firm_applications_application_id_fkey FOREIGN KEY (application_id) REFERENCES public.applications(id);


--
-- Name: user_firm_applications user_firm_applications_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_firm_applications
    ADD CONSTRAINT user_firm_applications_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: user_firm_applications user_firm_applications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_firm_applications
    ADD CONSTRAINT user_firm_applications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: user_firm_roles user_firm_roles_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_firm_roles
    ADD CONSTRAINT user_firm_roles_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: user_firm_roles user_firm_roles_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_firm_roles
    ADD CONSTRAINT user_firm_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id);


--
-- Name: user_firm_roles user_firm_roles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_firm_roles
    ADD CONSTRAINT user_firm_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: user_permission_overrides user_permission_overrides_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_permission_overrides
    ADD CONSTRAINT user_permission_overrides_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: user_permission_overrides user_permission_overrides_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_permission_overrides
    ADD CONSTRAINT user_permission_overrides_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES public.permissions(id);


--
-- Name: user_permission_overrides user_permission_overrides_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_permission_overrides
    ADD CONSTRAINT user_permission_overrides_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- PostgreSQL database dump complete
--

\unrestrict eqgzEMEv4J7he3wQFAsCSptCOODVKcPE2vQSTXmG7UcAoegsYshLmR8kTWo9hxT

