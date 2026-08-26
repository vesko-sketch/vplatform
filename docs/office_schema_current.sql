--
-- PostgreSQL database dump
--

\restrict 5ew5TyaSXCMgXuvY8q6PMSDNfs5xqTJDUb5fwEi03fmuOe0Cup88Qj664dlnjTA

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
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


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
-- Name: accounting_account_catalog; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.accounting_account_catalog (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    source_account_id uuid NOT NULL,
    parent_account_code character varying,
    account_code character varying NOT NULL,
    normalized_code character varying NOT NULL,
    account_name character varying NOT NULL,
    short_name character varying,
    account_type_code character varying NOT NULL,
    account_type_name character varying NOT NULL,
    semantic_type_code character varying NOT NULL,
    semantic_type_name character varying NOT NULL,
    normal_balance_side_code character varying NOT NULL,
    normal_balance_side_name character varying NOT NULL,
    can_post_directly boolean DEFAULT true NOT NULL,
    valid_from date,
    valid_to date,
    is_active boolean DEFAULT true NOT NULL,
    source_version bigint NOT NULL,
    source_updated_at timestamp with time zone,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: accounting_auto_send_policies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.accounting_auto_send_policies (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    name character varying NOT NULL,
    description text,
    is_active boolean DEFAULT true NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    minimum_overall_confidence numeric DEFAULT 0.95 NOT NULL,
    minimum_account_confidence numeric DEFAULT 0.95 NOT NULL,
    require_account_exists boolean DEFAULT true NOT NULL,
    require_account_active boolean DEFAULT true NOT NULL,
    require_direct_posting_account boolean DEFAULT true NOT NULL,
    require_counterparty_match boolean DEFAULT true NOT NULL,
    require_amount_validation boolean DEFAULT true NOT NULL,
    require_vat_validation boolean DEFAULT true NOT NULL,
    require_required_analytics boolean DEFAULT true NOT NULL,
    require_duplicate_check boolean DEFAULT true NOT NULL,
    allow_auto_send boolean DEFAULT false NOT NULL,
    allow_ai_review boolean DEFAULT true NOT NULL,
    max_ai_review_attempts integer DEFAULT 2 NOT NULL,
    policy_rules jsonb DEFAULT '{}'::jsonb NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT accounting_auto_send_policies_account_confidence_check CHECK (((minimum_account_confidence >= (0)::numeric) AND (minimum_account_confidence <= (1)::numeric))),
    CONSTRAINT accounting_auto_send_policies_ai_attempts_check CHECK (((max_ai_review_attempts >= 0) AND (max_ai_review_attempts <= 10))),
    CONSTRAINT accounting_auto_send_policies_overall_confidence_check CHECK (((minimum_overall_confidence >= (0)::numeric) AND (minimum_overall_confidence <= (1)::numeric)))
);


--
-- Name: addresses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.addresses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    country_id uuid NOT NULL,
    district_id uuid,
    municipality_id uuid,
    city_id uuid,
    postal_code_id uuid,
    postal_code character varying,
    street character varying,
    street_number character varying,
    building character varying,
    entrance character varying,
    floor character varying,
    apartment character varying,
    address_line character varying,
    notes text,
    source_system character varying,
    external_id character varying,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: counterparties; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.counterparties (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    country_id uuid,
    name character varying NOT NULL,
    short_name character varying,
    registration_number character varying,
    vat_number character varying,
    is_person boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    source_system character varying,
    external_id character varying,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: document_accounting_proposals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_accounting_proposals (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    document_id uuid NOT NULL,
    schema_version character varying DEFAULT '1.0'::character varying NOT NULL,
    source_application_code character varying,
    source_type character varying NOT NULL,
    source_reference character varying,
    proposal_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    overall_confidence numeric,
    validation_status character varying DEFAULT 'pending'::character varying NOT NULL,
    validation_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    automation_eligible boolean DEFAULT false NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT document_accounting_proposals_confidence_check CHECK (((overall_confidence IS NULL) OR ((overall_confidence >= (0)::numeric) AND (overall_confidence <= (1)::numeric)))),
    CONSTRAINT document_accounting_proposals_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'ready'::character varying, 'sent'::character varying, 'accepted'::character varying, 'rejected'::character varying, 'superseded'::character varying])::text[]))),
    CONSTRAINT document_accounting_proposals_validation_status_check CHECK (((validation_status)::text = ANY ((ARRAY['pending'::character varying, 'valid'::character varying, 'invalid'::character varying, 'warning'::character varying])::text[])))
);


--
-- Name: document_ai_reviews; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_ai_reviews (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    document_id uuid NOT NULL,
    source_proposal_id uuid,
    resulting_proposal_id uuid,
    review_attempt integer NOT NULL,
    review_type character varying DEFAULT 'clever_ai_review'::character varying NOT NULL,
    orchestrator character varying,
    workflow_name character varying,
    workflow_run_id character varying,
    model_name character varying,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    failed_gates jsonb DEFAULT '[]'::jsonb NOT NULL,
    review_evidence jsonb DEFAULT '{}'::jsonb NOT NULL,
    review_result jsonb DEFAULT '{}'::jsonb NOT NULL,
    confidence_before numeric,
    confidence_after numeric,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    error_message text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT document_ai_reviews_attempt_check CHECK ((review_attempt > 0)),
    CONSTRAINT document_ai_reviews_confidence_after_check CHECK (((confidence_after IS NULL) OR ((confidence_after >= (0)::numeric) AND (confidence_after <= (1)::numeric)))),
    CONSTRAINT document_ai_reviews_confidence_before_check CHECK (((confidence_before IS NULL) OR ((confidence_before >= (0)::numeric) AND (confidence_before <= (1)::numeric)))),
    CONSTRAINT document_ai_reviews_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'running'::character varying, 'completed'::character varying, 'failed'::character varying, 'cancelled'::character varying])::text[])))
);


--
-- Name: document_automation_decisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_automation_decisions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    document_id uuid NOT NULL,
    proposal_id uuid,
    policy_id uuid,
    ai_review_id uuid,
    decision character varying NOT NULL,
    decision_stage character varying NOT NULL,
    overall_confidence numeric,
    policy_snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    validation_snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    decision_reasons jsonb DEFAULT '{}'::jsonb NOT NULL,
    decided_by_type character varying NOT NULL,
    decided_by uuid,
    decided_at timestamp with time zone DEFAULT now() NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT document_automation_decisions_confidence_check CHECK (((overall_confidence IS NULL) OR ((overall_confidence >= (0)::numeric) AND (overall_confidence <= (1)::numeric)))),
    CONSTRAINT document_automation_decisions_decided_by_type_check CHECK (((decided_by_type)::text = ANY ((ARRAY['policy_engine'::character varying, 'ai'::character varying, 'human'::character varying, 'system'::character varying])::text[]))),
    CONSTRAINT document_automation_decisions_decision_check CHECK (((decision)::text = ANY ((ARRAY['auto_send'::character varying, 'ai_review'::character varying, 'human_review'::character varying, 'blocked'::character varying, 'human_send'::character varying, 'do_not_send'::character varying])::text[]))),
    CONSTRAINT document_automation_decisions_stage_check CHECK (((decision_stage)::text = ANY ((ARRAY['initial'::character varying, 'post_ai_review'::character varying, 'human'::character varying])::text[])))
);


--
-- Name: document_class_capabilities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_class_capabilities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    document_class_id uuid NOT NULL,
    capability_code character varying NOT NULL,
    is_enabled boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: document_classes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_classes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying NOT NULL,
    name character varying NOT NULL,
    description text,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: document_counterparty_snapshots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_counterparty_snapshots (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    document_id uuid NOT NULL,
    counterparty_id uuid,
    name_snapshot character varying,
    registration_number_snapshot character varying,
    vat_number_snapshot character varying,
    country_id_snapshot uuid,
    address_snapshot jsonb,
    source_mode character varying NOT NULL,
    manually_overridden boolean DEFAULT false NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: document_directions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_directions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying NOT NULL,
    name character varying NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: document_files; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_files (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    document_id uuid NOT NULL,
    file_role character varying,
    file_name character varying NOT NULL,
    mime_type character varying,
    storage_provider character varying,
    storage_path text NOT NULL,
    checksum_sha256 character varying,
    file_size bigint,
    is_original boolean DEFAULT false NOT NULL,
    is_primary boolean DEFAULT false NOT NULL,
    source_system character varying,
    external_id character varying,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: document_invoice_details; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_invoice_details (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    document_id uuid NOT NULL,
    currency_id uuid,
    net_amount numeric,
    vat_amount numeric,
    gross_amount numeric,
    due_date date,
    payment_terms_days integer,
    payment_reference character varying,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: document_lines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_lines (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    document_id uuid NOT NULL,
    line_no integer NOT NULL,
    description text NOT NULL,
    quantity numeric,
    unit_code character varying,
    unit_id uuid,
    unit_price numeric,
    discount_percent numeric,
    discount_amount numeric,
    net_amount numeric,
    vat_rate_percent numeric,
    vat_amount numeric,
    gross_amount numeric,
    product_service_type character varying,
    source_system character varying,
    external_id character varying,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: document_parties; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_parties (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    document_id uuid NOT NULL,
    role_id uuid NOT NULL,
    counterparty_id uuid,
    firm_id uuid,
    display_name_snapshot character varying,
    registration_number_snapshot character varying,
    vat_number_snapshot character varying,
    address_snapshot jsonb,
    sort_order integer,
    is_primary boolean DEFAULT false NOT NULL,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: document_party_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_party_roles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying NOT NULL,
    name character varying NOT NULL,
    description text,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: document_relation_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_relation_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying NOT NULL,
    name character varying NOT NULL,
    description text,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: document_relations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_relations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    source_document_id uuid NOT NULL,
    target_document_id uuid NOT NULL,
    relation_type_id uuid NOT NULL,
    effective_date date,
    notes text,
    created_by uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT document_relations_no_self_reference_check CHECK ((source_document_id <> target_document_id))
);


--
-- Name: document_sequence_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_sequence_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    document_sequence_id uuid NOT NULL,
    document_type_id uuid NOT NULL,
    is_primary boolean DEFAULT false NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: document_sequences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_sequences (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    operating_unit_id uuid,
    code character varying NOT NULL,
    name character varying NOT NULL,
    prefix character varying,
    digits_count integer DEFAULT 10 NOT NULL,
    start_number bigint DEFAULT 1 NOT NULL,
    next_number bigint DEFAULT 1 NOT NULL,
    max_number bigint,
    reset_period character varying DEFAULT 'none'::character varying NOT NULL,
    date_part_mode character varying DEFAULT 'none'::character varying NOT NULL,
    date_format character varying,
    separator character varying,
    is_default boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT document_sequences_date_part_mode_check CHECK (((date_part_mode)::text = ANY ((ARRAY['none'::character varying, 'year'::character varying, 'year_month'::character varying, 'full_date'::character varying])::text[]))),
    CONSTRAINT document_sequences_reset_period_check CHECK (((reset_period)::text = ANY ((ARRAY['none'::character varying, 'yearly'::character varying, 'monthly'::character varying])::text[])))
);


--
-- Name: document_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_statuses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying NOT NULL,
    name character varying NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    is_terminal boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: document_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    document_class_id uuid NOT NULL,
    code character varying NOT NULL,
    name character varying NOT NULL,
    short_name character varying,
    name_en character varying,
    nap_code character varying,
    default_direction_id uuid,
    uses_internal_sequence boolean DEFAULT false NOT NULL,
    default_digits_count integer,
    letters_allowed boolean DEFAULT true NOT NULL,
    default_position integer DEFAULT 0 NOT NULL,
    default_is_visible boolean DEFAULT true NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    default_posting_disposition character varying DEFAULT 'pending'::character varying NOT NULL,
    CONSTRAINT document_types_default_posting_disposition_check CHECK (((default_posting_disposition)::text = ANY ((ARRAY['pending'::character varying, 'for_posting'::character varying, 'not_for_posting'::character varying])::text[])))
);


--
-- Name: documents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.documents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    document_type_id uuid NOT NULL,
    document_status_id uuid NOT NULL,
    direction_id uuid,
    primary_counterparty_id uuid,
    operating_unit_id uuid,
    sales_point_id uuid,
    sequence_id uuid,
    currency_id uuid,
    document_number character varying,
    document_date date,
    received_date date,
    posting_disposition character varying DEFAULT 'pending'::character varying NOT NULL,
    not_for_posting_reason text,
    description text,
    internal_notes text,
    source_type character varying,
    source_reference character varying,
    is_active boolean DEFAULT true NOT NULL,
    created_by uuid,
    updated_by uuid,
    source_system character varying,
    external_id character varying,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT documents_not_for_posting_reason_check CHECK ((((posting_disposition)::text <> 'not_for_posting'::text) OR (not_for_posting_reason IS NOT NULL))),
    CONSTRAINT documents_posting_disposition_check CHECK (((posting_disposition)::text = ANY ((ARRAY['pending'::character varying, 'for_posting'::character varying, 'not_for_posting'::character varying])::text[])))
);


--
-- Name: firm_bank_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.firm_bank_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    bank_id uuid,
    currency_id uuid NOT NULL,
    iban character varying,
    account_number character varying,
    bic_swift character varying,
    account_name character varying,
    valid_from date,
    valid_to date,
    is_primary boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    notes text,
    source_system character varying,
    external_id character varying,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: firm_document_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.firm_document_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    document_type_id uuid NOT NULL,
    default_sequence_id uuid,
    default_direction_id uuid,
    display_position integer,
    is_visible boolean DEFAULT true NOT NULL,
    is_enabled boolean DEFAULT true NOT NULL,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    posting_disposition_override character varying,
    CONSTRAINT firm_document_types_posting_disposition_override_check CHECK (((posting_disposition_override IS NULL) OR ((posting_disposition_override)::text = ANY ((ARRAY['pending'::character varying, 'for_posting'::character varying, 'not_for_posting'::character varying])::text[]))))
);


--
-- Name: firms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.firms (
    id uuid NOT NULL,
    code character varying NOT NULL,
    name character varying NOT NULL,
    short_name character varying,
    legal_form_id uuid,
    country_id uuid,
    registration_number character varying,
    base_currency_id uuid,
    default_language_id uuid,
    timezone character varying,
    is_active boolean DEFAULT true NOT NULL,
    source_system character varying,
    external_id character varying,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    source_version bigint DEFAULT 0 NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ingestion_extractions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ingestion_extractions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ingestion_item_id uuid NOT NULL,
    ingestion_run_id uuid,
    extraction_type character varying NOT NULL,
    content_json jsonb,
    content_text text,
    confidence numeric,
    is_current boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ingestion_extractions_confidence_check CHECK (((confidence IS NULL) OR ((confidence >= (0)::numeric) AND (confidence <= (1)::numeric)))),
    CONSTRAINT ingestion_extractions_content_check CHECK (((content_json IS NOT NULL) OR (content_text IS NOT NULL)))
);


--
-- Name: ingestion_files; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ingestion_files (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ingestion_item_id uuid NOT NULL,
    file_role character varying,
    file_name character varying NOT NULL,
    mime_type character varying,
    storage_provider character varying,
    storage_path text NOT NULL,
    checksum_sha256 character varying,
    file_size bigint,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ingestion_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ingestion_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid,
    status character varying DEFAULT 'received'::character varying NOT NULL,
    source_type character varying,
    source_reference character varying,
    promoted_document_id uuid,
    is_promoted boolean DEFAULT false NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ingestion_items_promotion_check CHECK (((is_promoted = false) OR ((is_promoted = true) AND (promoted_document_id IS NOT NULL))))
);


--
-- Name: ingestion_predictions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ingestion_predictions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ingestion_item_id uuid NOT NULL,
    ingestion_run_id uuid,
    prediction_type character varying NOT NULL,
    predicted_value jsonb NOT NULL,
    confidence numeric,
    status character varying DEFAULT 'proposed'::character varying NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ingestion_predictions_confidence_check CHECK (((confidence IS NULL) OR ((confidence >= (0)::numeric) AND (confidence <= (1)::numeric))))
);


--
-- Name: ingestion_runs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ingestion_runs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ingestion_item_id uuid NOT NULL,
    run_type character varying NOT NULL,
    orchestrator character varying,
    workflow_name character varying,
    workflow_run_id character varying,
    model_name character varying,
    status character varying NOT NULL,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    error_message text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: integration_inbox; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.integration_inbox (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    event_id uuid NOT NULL,
    source_application_code character varying(50) NOT NULL,
    event_type character varying(100) NOT NULL,
    entity_type character varying(50) NOT NULL,
    entity_id uuid,
    entity_version bigint,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    processing_status character varying(30) DEFAULT 'pending'::character varying NOT NULL,
    retry_count integer DEFAULT 0 NOT NULL,
    last_error text,
    received_at timestamp with time zone DEFAULT now() NOT NULL,
    processed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT integration_inbox_processing_status_check CHECK (((processing_status)::text = ANY ((ARRAY['pending'::character varying, 'processing'::character varying, 'processed'::character varying, 'failed'::character varying])::text[]))),
    CONSTRAINT integration_inbox_retry_count_check CHECK ((retry_count >= 0))
);


--
-- Name: integration_outbox; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.integration_outbox (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    event_id uuid DEFAULT gen_random_uuid() NOT NULL,
    source_application_code character varying(50) DEFAULT 'OFFICE'::character varying NOT NULL,
    event_type character varying(100) NOT NULL,
    entity_type character varying(50) NOT NULL,
    entity_id uuid,
    entity_version bigint,
    firm_id uuid,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    processing_status character varying(30) DEFAULT 'pending'::character varying NOT NULL,
    retry_count integer DEFAULT 0 NOT NULL,
    last_error text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    processed_at timestamp with time zone,
    CONSTRAINT integration_outbox_processing_status_check CHECK (((processing_status)::text = ANY ((ARRAY['pending'::character varying, 'processing'::character varying, 'processed'::character varying, 'failed'::character varying])::text[]))),
    CONSTRAINT integration_outbox_retry_count_check CHECK ((retry_count >= 0))
);


--
-- Name: operating_unit_sales_points; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operating_unit_sales_points (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    operating_unit_id uuid NOT NULL,
    code character varying,
    name character varying NOT NULL,
    sales_point_type character varying NOT NULL,
    identifier character varying,
    fiscal_device_number character varying,
    default_sequence_id uuid,
    default_firm_bank_account_id uuid,
    valid_from date,
    valid_to date,
    is_active boolean DEFAULT true NOT NULL,
    notes text,
    source_system character varying,
    external_id character varying,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: operating_units; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operating_units (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    address_id uuid,
    code character varying,
    name character varying NOT NULL,
    unit_type character varying NOT NULL,
    manager_name character varying,
    valid_from date,
    valid_to date,
    is_active boolean DEFAULT true NOT NULL,
    notes text,
    source_system character varying,
    external_id character varying,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ref_banks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ref_banks (
    id uuid NOT NULL,
    country_id uuid,
    bic_swift character varying,
    code character varying,
    name character varying NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    source_system character varying,
    external_id character varying,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    institution_type character varying NOT NULL
);


--
-- Name: ref_cities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ref_cities (
    id uuid NOT NULL,
    country_id uuid NOT NULL,
    municipality_id uuid,
    ekatte character varying,
    postal_code character varying,
    name character varying NOT NULL,
    settlement_type character varying,
    is_active boolean DEFAULT true NOT NULL,
    source_system character varying,
    external_id character varying,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    name_latin character varying
);


--
-- Name: ref_countries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ref_countries (
    id uuid NOT NULL,
    iso2_code character varying,
    iso3_code character varying,
    name_bg character varying NOT NULL,
    name_en character varying,
    is_eu_member boolean DEFAULT false NOT NULL,
    is_eea_member boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    source_system character varying,
    external_id character varying,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ref_currencies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ref_currencies (
    id uuid NOT NULL,
    iso_code character varying NOT NULL,
    name character varying NOT NULL,
    decimal_places integer,
    is_crypto boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    source_system character varying,
    external_id character varying,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ref_districts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ref_districts (
    id uuid NOT NULL,
    country_id uuid NOT NULL,
    code character varying,
    name character varying NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    source_system character varying,
    external_id character varying,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ref_municipalities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ref_municipalities (
    id uuid NOT NULL,
    district_id uuid,
    country_id uuid NOT NULL,
    code character varying,
    name character varying NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    source_system character varying,
    external_id character varying,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ref_postal_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ref_postal_codes (
    id uuid NOT NULL,
    country_id uuid NOT NULL,
    city_id uuid,
    postal_code character varying NOT NULL,
    name character varying,
    description text,
    is_active boolean DEFAULT true NOT NULL,
    source_system character varying,
    external_id character varying,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ref_units_of_measure; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ref_units_of_measure (
    id uuid NOT NULL,
    code character varying NOT NULL,
    name_bg character varying NOT NULL,
    name_en character varying,
    unit_kind character varying DEFAULT 'other'::character varying NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    source_system character varying,
    external_id character varying,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid NOT NULL,
    email character varying NOT NULL,
    display_name character varying,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    source_version bigint DEFAULT 0 NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: accounting_account_catalog accounting_account_catalog_firm_id_account_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounting_account_catalog
    ADD CONSTRAINT accounting_account_catalog_firm_id_account_code_key UNIQUE (firm_id, account_code);


--
-- Name: accounting_account_catalog accounting_account_catalog_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounting_account_catalog
    ADD CONSTRAINT accounting_account_catalog_pkey PRIMARY KEY (id);


--
-- Name: accounting_account_catalog accounting_account_catalog_source_account_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounting_account_catalog
    ADD CONSTRAINT accounting_account_catalog_source_account_id_key UNIQUE (source_account_id);


--
-- Name: accounting_auto_send_policies accounting_auto_send_policies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounting_auto_send_policies
    ADD CONSTRAINT accounting_auto_send_policies_pkey PRIMARY KEY (id);


--
-- Name: addresses addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT addresses_pkey PRIMARY KEY (id);


--
-- Name: counterparties counterparties_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.counterparties
    ADD CONSTRAINT counterparties_pkey PRIMARY KEY (id);


--
-- Name: document_accounting_proposals document_accounting_proposals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_accounting_proposals
    ADD CONSTRAINT document_accounting_proposals_pkey PRIMARY KEY (id);


--
-- Name: document_ai_reviews document_ai_reviews_document_id_review_attempt_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_ai_reviews
    ADD CONSTRAINT document_ai_reviews_document_id_review_attempt_key UNIQUE (document_id, review_attempt);


--
-- Name: document_ai_reviews document_ai_reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_ai_reviews
    ADD CONSTRAINT document_ai_reviews_pkey PRIMARY KEY (id);


--
-- Name: document_automation_decisions document_automation_decisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_automation_decisions
    ADD CONSTRAINT document_automation_decisions_pkey PRIMARY KEY (id);


--
-- Name: document_class_capabilities document_class_capabilities_document_class_id_capability_co_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_class_capabilities
    ADD CONSTRAINT document_class_capabilities_document_class_id_capability_co_key UNIQUE (document_class_id, capability_code);


--
-- Name: document_class_capabilities document_class_capabilities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_class_capabilities
    ADD CONSTRAINT document_class_capabilities_pkey PRIMARY KEY (id);


--
-- Name: document_classes document_classes_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_classes
    ADD CONSTRAINT document_classes_code_key UNIQUE (code);


--
-- Name: document_classes document_classes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_classes
    ADD CONSTRAINT document_classes_pkey PRIMARY KEY (id);


--
-- Name: document_counterparty_snapshots document_counterparty_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_counterparty_snapshots
    ADD CONSTRAINT document_counterparty_snapshots_pkey PRIMARY KEY (id);


--
-- Name: document_directions document_directions_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_directions
    ADD CONSTRAINT document_directions_code_key UNIQUE (code);


--
-- Name: document_directions document_directions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_directions
    ADD CONSTRAINT document_directions_pkey PRIMARY KEY (id);


--
-- Name: document_files document_files_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_files
    ADD CONSTRAINT document_files_pkey PRIMARY KEY (id);


--
-- Name: document_invoice_details document_invoice_details_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_invoice_details
    ADD CONSTRAINT document_invoice_details_pkey PRIMARY KEY (id);


--
-- Name: document_lines document_lines_document_id_line_no_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_lines
    ADD CONSTRAINT document_lines_document_id_line_no_key UNIQUE (document_id, line_no);


--
-- Name: document_lines document_lines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_lines
    ADD CONSTRAINT document_lines_pkey PRIMARY KEY (id);


--
-- Name: document_parties document_parties_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_parties
    ADD CONSTRAINT document_parties_pkey PRIMARY KEY (id);


--
-- Name: document_party_roles document_party_roles_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_party_roles
    ADD CONSTRAINT document_party_roles_code_key UNIQUE (code);


--
-- Name: document_party_roles document_party_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_party_roles
    ADD CONSTRAINT document_party_roles_pkey PRIMARY KEY (id);


--
-- Name: document_relation_types document_relation_types_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_relation_types
    ADD CONSTRAINT document_relation_types_code_key UNIQUE (code);


--
-- Name: document_relation_types document_relation_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_relation_types
    ADD CONSTRAINT document_relation_types_pkey PRIMARY KEY (id);


--
-- Name: document_relations document_relations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_relations
    ADD CONSTRAINT document_relations_pkey PRIMARY KEY (id);


--
-- Name: document_sequence_types document_sequence_types_document_sequence_id_document_type__key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_sequence_types
    ADD CONSTRAINT document_sequence_types_document_sequence_id_document_type__key UNIQUE (document_sequence_id, document_type_id);


--
-- Name: document_sequence_types document_sequence_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_sequence_types
    ADD CONSTRAINT document_sequence_types_pkey PRIMARY KEY (id);


--
-- Name: document_sequences document_sequences_firm_id_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_sequences
    ADD CONSTRAINT document_sequences_firm_id_code_key UNIQUE (firm_id, code);


--
-- Name: document_sequences document_sequences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_sequences
    ADD CONSTRAINT document_sequences_pkey PRIMARY KEY (id);


--
-- Name: document_statuses document_statuses_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_statuses
    ADD CONSTRAINT document_statuses_code_key UNIQUE (code);


--
-- Name: document_statuses document_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_statuses
    ADD CONSTRAINT document_statuses_pkey PRIMARY KEY (id);


--
-- Name: document_types document_types_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_types
    ADD CONSTRAINT document_types_code_key UNIQUE (code);


--
-- Name: document_types document_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_types
    ADD CONSTRAINT document_types_pkey PRIMARY KEY (id);


--
-- Name: documents documents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_pkey PRIMARY KEY (id);


--
-- Name: firm_bank_accounts firm_bank_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_bank_accounts
    ADD CONSTRAINT firm_bank_accounts_pkey PRIMARY KEY (id);


--
-- Name: firm_document_types firm_document_types_firm_id_document_type_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_document_types
    ADD CONSTRAINT firm_document_types_firm_id_document_type_id_key UNIQUE (firm_id, document_type_id);


--
-- Name: firm_document_types firm_document_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_document_types
    ADD CONSTRAINT firm_document_types_pkey PRIMARY KEY (id);


--
-- Name: firms firms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firms
    ADD CONSTRAINT firms_pkey PRIMARY KEY (id);


--
-- Name: ingestion_extractions ingestion_extractions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingestion_extractions
    ADD CONSTRAINT ingestion_extractions_pkey PRIMARY KEY (id);


--
-- Name: ingestion_files ingestion_files_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingestion_files
    ADD CONSTRAINT ingestion_files_pkey PRIMARY KEY (id);


--
-- Name: ingestion_items ingestion_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingestion_items
    ADD CONSTRAINT ingestion_items_pkey PRIMARY KEY (id);


--
-- Name: ingestion_predictions ingestion_predictions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingestion_predictions
    ADD CONSTRAINT ingestion_predictions_pkey PRIMARY KEY (id);


--
-- Name: ingestion_runs ingestion_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingestion_runs
    ADD CONSTRAINT ingestion_runs_pkey PRIMARY KEY (id);


--
-- Name: integration_inbox integration_inbox_event_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_inbox
    ADD CONSTRAINT integration_inbox_event_id_key UNIQUE (event_id);


--
-- Name: integration_inbox integration_inbox_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_inbox
    ADD CONSTRAINT integration_inbox_pkey PRIMARY KEY (id);


--
-- Name: integration_outbox integration_outbox_event_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_outbox
    ADD CONSTRAINT integration_outbox_event_id_key UNIQUE (event_id);


--
-- Name: integration_outbox integration_outbox_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_outbox
    ADD CONSTRAINT integration_outbox_pkey PRIMARY KEY (id);


--
-- Name: operating_unit_sales_points operating_unit_sales_points_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operating_unit_sales_points
    ADD CONSTRAINT operating_unit_sales_points_pkey PRIMARY KEY (id);


--
-- Name: operating_units operating_units_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operating_units
    ADD CONSTRAINT operating_units_pkey PRIMARY KEY (id);


--
-- Name: ref_banks ref_banks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_banks
    ADD CONSTRAINT ref_banks_pkey PRIMARY KEY (id);


--
-- Name: ref_cities ref_cities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_cities
    ADD CONSTRAINT ref_cities_pkey PRIMARY KEY (id);


--
-- Name: ref_countries ref_countries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_countries
    ADD CONSTRAINT ref_countries_pkey PRIMARY KEY (id);


--
-- Name: ref_currencies ref_currencies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_currencies
    ADD CONSTRAINT ref_currencies_pkey PRIMARY KEY (id);


--
-- Name: ref_districts ref_districts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_districts
    ADD CONSTRAINT ref_districts_pkey PRIMARY KEY (id);


--
-- Name: ref_municipalities ref_municipalities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_municipalities
    ADD CONSTRAINT ref_municipalities_pkey PRIMARY KEY (id);


--
-- Name: ref_postal_codes ref_postal_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_postal_codes
    ADD CONSTRAINT ref_postal_codes_pkey PRIMARY KEY (id);


--
-- Name: ref_units_of_measure ref_units_of_measure_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_units_of_measure
    ADD CONSTRAINT ref_units_of_measure_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_integration_inbox_entity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_integration_inbox_entity ON public.integration_inbox USING btree (source_application_code, entity_type, entity_id);


--
-- Name: idx_integration_inbox_pending; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_integration_inbox_pending ON public.integration_inbox USING btree (processing_status, received_at) WHERE ((processing_status)::text = ANY ((ARRAY['pending'::character varying, 'failed'::character varying])::text[]));


--
-- Name: idx_integration_outbox_entity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_integration_outbox_entity ON public.integration_outbox USING btree (entity_type, entity_id, entity_version);


--
-- Name: idx_integration_outbox_firm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_integration_outbox_firm ON public.integration_outbox USING btree (firm_id, created_at);


--
-- Name: idx_integration_outbox_pending; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_integration_outbox_pending ON public.integration_outbox USING btree (processing_status, created_at) WHERE ((processing_status)::text = ANY ((ARRAY['pending'::character varying, 'failed'::character varying])::text[]));


--
-- Name: ix_accounting_account_catalog_firm_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_accounting_account_catalog_firm_active ON public.accounting_account_catalog USING btree (firm_id, is_active, can_post_directly);


--
-- Name: ix_accounting_account_catalog_firm_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_accounting_account_catalog_firm_name ON public.accounting_account_catalog USING btree (firm_id, account_name);


--
-- Name: ix_accounting_account_catalog_firm_normalized_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_accounting_account_catalog_firm_normalized_code ON public.accounting_account_catalog USING btree (firm_id, normalized_code);


--
-- Name: ix_auto_send_policies_firm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_auto_send_policies_firm ON public.accounting_auto_send_policies USING btree (firm_id, is_active);


--
-- Name: ix_document_ai_reviews_document; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_document_ai_reviews_document ON public.document_ai_reviews USING btree (document_id, review_attempt);


--
-- Name: ix_document_ai_reviews_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_document_ai_reviews_status ON public.document_ai_reviews USING btree (status, created_at);


--
-- Name: ix_document_automation_decisions_decision; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_document_automation_decisions_decision ON public.document_automation_decisions USING btree (decision, decided_at);


--
-- Name: ix_document_automation_decisions_document; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_document_automation_decisions_document ON public.document_automation_decisions USING btree (document_id, decided_at);


--
-- Name: ix_ingestion_extractions_item_current; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ingestion_extractions_item_current ON public.ingestion_extractions USING btree (ingestion_item_id, is_current);


--
-- Name: ix_ingestion_files_checksum; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ingestion_files_checksum ON public.ingestion_files USING btree (checksum_sha256) WHERE (checksum_sha256 IS NOT NULL);


--
-- Name: ix_ingestion_files_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ingestion_files_item ON public.ingestion_files USING btree (ingestion_item_id);


--
-- Name: ix_ingestion_items_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ingestion_items_created_at ON public.ingestion_items USING btree (created_at);


--
-- Name: ix_ingestion_items_firm_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ingestion_items_firm_status ON public.ingestion_items USING btree (firm_id, status);


--
-- Name: ix_ingestion_predictions_item_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ingestion_predictions_item_type ON public.ingestion_predictions USING btree (ingestion_item_id, prediction_type);


--
-- Name: ix_ingestion_runs_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_ingestion_runs_item ON public.ingestion_runs USING btree (ingestion_item_id);


--
-- Name: ux_accounting_auto_send_policies_default; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_accounting_auto_send_policies_default ON public.accounting_auto_send_policies USING btree (firm_id) WHERE ((is_default = true) AND (is_active = true));


--
-- Name: ux_office_firms_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_office_firms_code ON public.firms USING btree (code);


--
-- Name: ux_office_users_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_office_users_email ON public.users USING btree (email);


--
-- Name: accounting_account_catalog trg_accounting_account_catalog_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_accounting_account_catalog_set_updated_at BEFORE UPDATE ON public.accounting_account_catalog FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: accounting_auto_send_policies trg_accounting_auto_send_policies_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_accounting_auto_send_policies_set_updated_at BEFORE UPDATE ON public.accounting_auto_send_policies FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: addresses trg_addresses_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_addresses_set_updated_at BEFORE UPDATE ON public.addresses FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: counterparties trg_counterparties_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_counterparties_set_updated_at BEFORE UPDATE ON public.counterparties FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: document_accounting_proposals trg_document_accounting_proposals_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_document_accounting_proposals_set_updated_at BEFORE UPDATE ON public.document_accounting_proposals FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: document_ai_reviews trg_document_ai_reviews_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_document_ai_reviews_set_updated_at BEFORE UPDATE ON public.document_ai_reviews FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: document_automation_decisions trg_document_automation_decisions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_document_automation_decisions_set_updated_at BEFORE UPDATE ON public.document_automation_decisions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: document_class_capabilities trg_document_class_capabilities_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_document_class_capabilities_set_updated_at BEFORE UPDATE ON public.document_class_capabilities FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: document_classes trg_document_classes_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_document_classes_set_updated_at BEFORE UPDATE ON public.document_classes FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: document_counterparty_snapshots trg_document_counterparty_snapshots_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_document_counterparty_snapshots_set_updated_at BEFORE UPDATE ON public.document_counterparty_snapshots FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: document_directions trg_document_directions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_document_directions_set_updated_at BEFORE UPDATE ON public.document_directions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: document_files trg_document_files_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_document_files_set_updated_at BEFORE UPDATE ON public.document_files FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: document_invoice_details trg_document_invoice_details_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_document_invoice_details_set_updated_at BEFORE UPDATE ON public.document_invoice_details FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: document_lines trg_document_lines_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_document_lines_set_updated_at BEFORE UPDATE ON public.document_lines FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: document_parties trg_document_parties_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_document_parties_set_updated_at BEFORE UPDATE ON public.document_parties FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: document_party_roles trg_document_party_roles_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_document_party_roles_set_updated_at BEFORE UPDATE ON public.document_party_roles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: document_relation_types trg_document_relation_types_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_document_relation_types_set_updated_at BEFORE UPDATE ON public.document_relation_types FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: document_relations trg_document_relations_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_document_relations_set_updated_at BEFORE UPDATE ON public.document_relations FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: document_sequence_types trg_document_sequence_types_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_document_sequence_types_set_updated_at BEFORE UPDATE ON public.document_sequence_types FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: document_sequences trg_document_sequences_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_document_sequences_set_updated_at BEFORE UPDATE ON public.document_sequences FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: document_statuses trg_document_statuses_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_document_statuses_set_updated_at BEFORE UPDATE ON public.document_statuses FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: document_types trg_document_types_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_document_types_set_updated_at BEFORE UPDATE ON public.document_types FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: documents trg_documents_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_documents_set_updated_at BEFORE UPDATE ON public.documents FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: firm_bank_accounts trg_firm_bank_accounts_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firm_bank_accounts_set_updated_at BEFORE UPDATE ON public.firm_bank_accounts FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: firm_document_types trg_firm_document_types_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firm_document_types_set_updated_at BEFORE UPDATE ON public.firm_document_types FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: firms trg_firms_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firms_set_updated_at BEFORE UPDATE ON public.firms FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: ingestion_extractions trg_ingestion_extractions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ingestion_extractions_set_updated_at BEFORE UPDATE ON public.ingestion_extractions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: ingestion_files trg_ingestion_files_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ingestion_files_set_updated_at BEFORE UPDATE ON public.ingestion_files FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: ingestion_items trg_ingestion_items_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ingestion_items_set_updated_at BEFORE UPDATE ON public.ingestion_items FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: ingestion_predictions trg_ingestion_predictions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ingestion_predictions_set_updated_at BEFORE UPDATE ON public.ingestion_predictions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: ingestion_runs trg_ingestion_runs_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ingestion_runs_set_updated_at BEFORE UPDATE ON public.ingestion_runs FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: operating_unit_sales_points trg_operating_unit_sales_points_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_operating_unit_sales_points_set_updated_at BEFORE UPDATE ON public.operating_unit_sales_points FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: operating_units trg_operating_units_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_operating_units_set_updated_at BEFORE UPDATE ON public.operating_units FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: users trg_users_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_users_set_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: accounting_account_catalog accounting_account_catalog_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounting_account_catalog
    ADD CONSTRAINT accounting_account_catalog_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: accounting_auto_send_policies accounting_auto_send_policies_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounting_auto_send_policies
    ADD CONSTRAINT accounting_auto_send_policies_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: addresses addresses_city_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT addresses_city_id_fkey FOREIGN KEY (city_id) REFERENCES public.ref_cities(id);


--
-- Name: addresses addresses_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT addresses_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.ref_countries(id);


--
-- Name: addresses addresses_district_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT addresses_district_id_fkey FOREIGN KEY (district_id) REFERENCES public.ref_districts(id);


--
-- Name: addresses addresses_municipality_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT addresses_municipality_id_fkey FOREIGN KEY (municipality_id) REFERENCES public.ref_municipalities(id);


--
-- Name: addresses addresses_postal_code_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT addresses_postal_code_id_fkey FOREIGN KEY (postal_code_id) REFERENCES public.ref_postal_codes(id);


--
-- Name: counterparties counterparties_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.counterparties
    ADD CONSTRAINT counterparties_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.ref_countries(id);


--
-- Name: document_accounting_proposals document_accounting_proposals_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_accounting_proposals
    ADD CONSTRAINT document_accounting_proposals_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.documents(id);


--
-- Name: document_accounting_proposals document_accounting_proposals_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_accounting_proposals
    ADD CONSTRAINT document_accounting_proposals_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: document_ai_reviews document_ai_reviews_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_ai_reviews
    ADD CONSTRAINT document_ai_reviews_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.documents(id);


--
-- Name: document_ai_reviews document_ai_reviews_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_ai_reviews
    ADD CONSTRAINT document_ai_reviews_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: document_ai_reviews document_ai_reviews_resulting_proposal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_ai_reviews
    ADD CONSTRAINT document_ai_reviews_resulting_proposal_id_fkey FOREIGN KEY (resulting_proposal_id) REFERENCES public.document_accounting_proposals(id);


--
-- Name: document_ai_reviews document_ai_reviews_source_proposal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_ai_reviews
    ADD CONSTRAINT document_ai_reviews_source_proposal_id_fkey FOREIGN KEY (source_proposal_id) REFERENCES public.document_accounting_proposals(id);


--
-- Name: document_automation_decisions document_automation_decisions_ai_review_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_automation_decisions
    ADD CONSTRAINT document_automation_decisions_ai_review_id_fkey FOREIGN KEY (ai_review_id) REFERENCES public.document_ai_reviews(id);


--
-- Name: document_automation_decisions document_automation_decisions_decided_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_automation_decisions
    ADD CONSTRAINT document_automation_decisions_decided_by_fkey FOREIGN KEY (decided_by) REFERENCES public.users(id);


--
-- Name: document_automation_decisions document_automation_decisions_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_automation_decisions
    ADD CONSTRAINT document_automation_decisions_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.documents(id);


--
-- Name: document_automation_decisions document_automation_decisions_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_automation_decisions
    ADD CONSTRAINT document_automation_decisions_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: document_automation_decisions document_automation_decisions_policy_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_automation_decisions
    ADD CONSTRAINT document_automation_decisions_policy_id_fkey FOREIGN KEY (policy_id) REFERENCES public.accounting_auto_send_policies(id);


--
-- Name: document_automation_decisions document_automation_decisions_proposal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_automation_decisions
    ADD CONSTRAINT document_automation_decisions_proposal_id_fkey FOREIGN KEY (proposal_id) REFERENCES public.document_accounting_proposals(id);


--
-- Name: document_class_capabilities document_class_capabilities_document_class_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_class_capabilities
    ADD CONSTRAINT document_class_capabilities_document_class_id_fkey FOREIGN KEY (document_class_id) REFERENCES public.document_classes(id);


--
-- Name: document_counterparty_snapshots document_counterparty_snapshots_counterparty_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_counterparty_snapshots
    ADD CONSTRAINT document_counterparty_snapshots_counterparty_id_fkey FOREIGN KEY (counterparty_id) REFERENCES public.counterparties(id);


--
-- Name: document_counterparty_snapshots document_counterparty_snapshots_country_id_snapshot_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_counterparty_snapshots
    ADD CONSTRAINT document_counterparty_snapshots_country_id_snapshot_fkey FOREIGN KEY (country_id_snapshot) REFERENCES public.ref_countries(id);


--
-- Name: document_counterparty_snapshots document_counterparty_snapshots_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_counterparty_snapshots
    ADD CONSTRAINT document_counterparty_snapshots_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.documents(id);


--
-- Name: document_files document_files_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_files
    ADD CONSTRAINT document_files_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.documents(id);


--
-- Name: document_invoice_details document_invoice_details_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_invoice_details
    ADD CONSTRAINT document_invoice_details_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES public.ref_currencies(id);


--
-- Name: document_invoice_details document_invoice_details_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_invoice_details
    ADD CONSTRAINT document_invoice_details_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.documents(id);


--
-- Name: document_lines document_lines_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_lines
    ADD CONSTRAINT document_lines_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.documents(id);


--
-- Name: document_lines document_lines_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_lines
    ADD CONSTRAINT document_lines_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.ref_units_of_measure(id);


--
-- Name: document_parties document_parties_counterparty_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_parties
    ADD CONSTRAINT document_parties_counterparty_id_fkey FOREIGN KEY (counterparty_id) REFERENCES public.counterparties(id);


--
-- Name: document_parties document_parties_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_parties
    ADD CONSTRAINT document_parties_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.documents(id);


--
-- Name: document_parties document_parties_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_parties
    ADD CONSTRAINT document_parties_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: document_parties document_parties_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_parties
    ADD CONSTRAINT document_parties_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.document_party_roles(id);


--
-- Name: document_relations document_relations_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_relations
    ADD CONSTRAINT document_relations_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: document_relations document_relations_relation_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_relations
    ADD CONSTRAINT document_relations_relation_type_id_fkey FOREIGN KEY (relation_type_id) REFERENCES public.document_relation_types(id);


--
-- Name: document_relations document_relations_source_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_relations
    ADD CONSTRAINT document_relations_source_document_id_fkey FOREIGN KEY (source_document_id) REFERENCES public.documents(id);


--
-- Name: document_relations document_relations_target_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_relations
    ADD CONSTRAINT document_relations_target_document_id_fkey FOREIGN KEY (target_document_id) REFERENCES public.documents(id);


--
-- Name: document_sequence_types document_sequence_types_document_sequence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_sequence_types
    ADD CONSTRAINT document_sequence_types_document_sequence_id_fkey FOREIGN KEY (document_sequence_id) REFERENCES public.document_sequences(id);


--
-- Name: document_sequence_types document_sequence_types_document_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_sequence_types
    ADD CONSTRAINT document_sequence_types_document_type_id_fkey FOREIGN KEY (document_type_id) REFERENCES public.document_types(id);


--
-- Name: document_sequences document_sequences_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_sequences
    ADD CONSTRAINT document_sequences_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: document_sequences document_sequences_operating_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_sequences
    ADD CONSTRAINT document_sequences_operating_unit_id_fkey FOREIGN KEY (operating_unit_id) REFERENCES public.operating_units(id);


--
-- Name: document_types document_types_default_direction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_types
    ADD CONSTRAINT document_types_default_direction_id_fkey FOREIGN KEY (default_direction_id) REFERENCES public.document_directions(id);


--
-- Name: document_types document_types_document_class_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_types
    ADD CONSTRAINT document_types_document_class_id_fkey FOREIGN KEY (document_class_id) REFERENCES public.document_classes(id);


--
-- Name: documents documents_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: documents documents_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES public.ref_currencies(id);


--
-- Name: documents documents_direction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_direction_id_fkey FOREIGN KEY (direction_id) REFERENCES public.document_directions(id);


--
-- Name: documents documents_document_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_document_status_id_fkey FOREIGN KEY (document_status_id) REFERENCES public.document_statuses(id);


--
-- Name: documents documents_document_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_document_type_id_fkey FOREIGN KEY (document_type_id) REFERENCES public.document_types(id);


--
-- Name: documents documents_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: documents documents_operating_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_operating_unit_id_fkey FOREIGN KEY (operating_unit_id) REFERENCES public.operating_units(id);


--
-- Name: documents documents_primary_counterparty_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_primary_counterparty_id_fkey FOREIGN KEY (primary_counterparty_id) REFERENCES public.counterparties(id);


--
-- Name: documents documents_sales_point_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_sales_point_id_fkey FOREIGN KEY (sales_point_id) REFERENCES public.operating_unit_sales_points(id);


--
-- Name: documents documents_sequence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_sequence_id_fkey FOREIGN KEY (sequence_id) REFERENCES public.document_sequences(id);


--
-- Name: documents documents_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- Name: firm_bank_accounts firm_bank_accounts_bank_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_bank_accounts
    ADD CONSTRAINT firm_bank_accounts_bank_id_fkey FOREIGN KEY (bank_id) REFERENCES public.ref_banks(id);


--
-- Name: firm_bank_accounts firm_bank_accounts_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_bank_accounts
    ADD CONSTRAINT firm_bank_accounts_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES public.ref_currencies(id);


--
-- Name: firm_bank_accounts firm_bank_accounts_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_bank_accounts
    ADD CONSTRAINT firm_bank_accounts_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: firm_document_types firm_document_types_default_direction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_document_types
    ADD CONSTRAINT firm_document_types_default_direction_id_fkey FOREIGN KEY (default_direction_id) REFERENCES public.document_directions(id);


--
-- Name: firm_document_types firm_document_types_default_sequence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_document_types
    ADD CONSTRAINT firm_document_types_default_sequence_id_fkey FOREIGN KEY (default_sequence_id) REFERENCES public.document_sequences(id);


--
-- Name: firm_document_types firm_document_types_document_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_document_types
    ADD CONSTRAINT firm_document_types_document_type_id_fkey FOREIGN KEY (document_type_id) REFERENCES public.document_types(id);


--
-- Name: firm_document_types firm_document_types_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_document_types
    ADD CONSTRAINT firm_document_types_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: ingestion_extractions ingestion_extractions_ingestion_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingestion_extractions
    ADD CONSTRAINT ingestion_extractions_ingestion_item_id_fkey FOREIGN KEY (ingestion_item_id) REFERENCES public.ingestion_items(id);


--
-- Name: ingestion_extractions ingestion_extractions_ingestion_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingestion_extractions
    ADD CONSTRAINT ingestion_extractions_ingestion_run_id_fkey FOREIGN KEY (ingestion_run_id) REFERENCES public.ingestion_runs(id);


--
-- Name: ingestion_files ingestion_files_ingestion_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingestion_files
    ADD CONSTRAINT ingestion_files_ingestion_item_id_fkey FOREIGN KEY (ingestion_item_id) REFERENCES public.ingestion_items(id);


--
-- Name: ingestion_items ingestion_items_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingestion_items
    ADD CONSTRAINT ingestion_items_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: ingestion_items ingestion_items_promoted_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingestion_items
    ADD CONSTRAINT ingestion_items_promoted_document_id_fkey FOREIGN KEY (promoted_document_id) REFERENCES public.documents(id);


--
-- Name: ingestion_predictions ingestion_predictions_ingestion_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingestion_predictions
    ADD CONSTRAINT ingestion_predictions_ingestion_item_id_fkey FOREIGN KEY (ingestion_item_id) REFERENCES public.ingestion_items(id);


--
-- Name: ingestion_predictions ingestion_predictions_ingestion_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingestion_predictions
    ADD CONSTRAINT ingestion_predictions_ingestion_run_id_fkey FOREIGN KEY (ingestion_run_id) REFERENCES public.ingestion_runs(id);


--
-- Name: ingestion_runs ingestion_runs_ingestion_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingestion_runs
    ADD CONSTRAINT ingestion_runs_ingestion_item_id_fkey FOREIGN KEY (ingestion_item_id) REFERENCES public.ingestion_items(id);


--
-- Name: integration_outbox integration_outbox_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_outbox
    ADD CONSTRAINT integration_outbox_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: operating_unit_sales_points operating_unit_sales_points_default_firm_bank_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operating_unit_sales_points
    ADD CONSTRAINT operating_unit_sales_points_default_firm_bank_account_id_fkey FOREIGN KEY (default_firm_bank_account_id) REFERENCES public.firm_bank_accounts(id);


--
-- Name: operating_unit_sales_points operating_unit_sales_points_default_sequence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operating_unit_sales_points
    ADD CONSTRAINT operating_unit_sales_points_default_sequence_id_fkey FOREIGN KEY (default_sequence_id) REFERENCES public.document_sequences(id);


--
-- Name: operating_unit_sales_points operating_unit_sales_points_operating_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operating_unit_sales_points
    ADD CONSTRAINT operating_unit_sales_points_operating_unit_id_fkey FOREIGN KEY (operating_unit_id) REFERENCES public.operating_units(id);


--
-- Name: operating_units operating_units_address_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operating_units
    ADD CONSTRAINT operating_units_address_id_fkey FOREIGN KEY (address_id) REFERENCES public.addresses(id);


--
-- Name: operating_units operating_units_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operating_units
    ADD CONSTRAINT operating_units_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: ref_banks ref_banks_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_banks
    ADD CONSTRAINT ref_banks_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.ref_countries(id);


--
-- Name: ref_cities ref_cities_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_cities
    ADD CONSTRAINT ref_cities_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.ref_countries(id);


--
-- Name: ref_cities ref_cities_municipality_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_cities
    ADD CONSTRAINT ref_cities_municipality_id_fkey FOREIGN KEY (municipality_id) REFERENCES public.ref_municipalities(id);


--
-- Name: ref_districts ref_districts_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_districts
    ADD CONSTRAINT ref_districts_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.ref_countries(id);


--
-- Name: ref_municipalities ref_municipalities_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_municipalities
    ADD CONSTRAINT ref_municipalities_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.ref_countries(id);


--
-- Name: ref_municipalities ref_municipalities_district_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_municipalities
    ADD CONSTRAINT ref_municipalities_district_id_fkey FOREIGN KEY (district_id) REFERENCES public.ref_districts(id);


--
-- Name: ref_postal_codes ref_postal_codes_city_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_postal_codes
    ADD CONSTRAINT ref_postal_codes_city_id_fkey FOREIGN KEY (city_id) REFERENCES public.ref_cities(id);


--
-- Name: ref_postal_codes ref_postal_codes_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_postal_codes
    ADD CONSTRAINT ref_postal_codes_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.ref_countries(id);


--
-- PostgreSQL database dump complete
--

\unrestrict 5ew5TyaSXCMgXuvY8q6PMSDNfs5xqTJDUb5fwEi03fmuOe0Cup88Qj664dlnjTA

