--
-- PostgreSQL database dump
--

\restrict C97bQSnaPMkXnNcCnDMG5Ai31Kq3imhME25bfeYZMmcGAO982fyfLr6AO8hWyui

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
-- Name: btree_gist; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;


--
-- Name: EXTENSION btree_gist; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION btree_gist IS 'support for indexing common datatypes in GiST';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: confirm_firm_item_match(uuid, uuid, uuid, uuid, uuid, character varying, character varying, numeric, boolean, character varying, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.confirm_firm_item_match(p_firm_id uuid, p_document_line_id uuid, p_selected_firm_item_id uuid, p_counterparty_id uuid DEFAULT NULL::uuid, p_suggested_firm_item_id uuid DEFAULT NULL::uuid, p_decision character varying DEFAULT 'accepted'::character varying, p_suggestion_method character varying DEFAULT NULL::character varying, p_suggestion_confidence numeric DEFAULT NULL::numeric, p_remember_as_alias boolean DEFAULT false, p_alias_scope character varying DEFAULT 'counterparty'::character varying, p_decided_by uuid DEFAULT NULL::uuid) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_document_id UUID;
    v_document_firm_id UUID;
    v_source_text TEXT;
    v_item_firm_id UUID;
    v_item_unit_id UUID;
    v_item_vat_tax_category_id UUID;
    v_normalized TEXT;
    v_alias_id UUID;
    v_decision_id UUID;
BEGIN
    -- Validate decision enum explicitly for clearer errors.
    IF p_decision NOT IN ('accepted','changed','new_item','skipped') THEN
        RAISE EXCEPTION 'Invalid decision: %', p_decision;
    END IF;

    IF p_alias_scope NOT IN ('counterparty','generic') THEN
        RAISE EXCEPTION 'Invalid alias scope: %', p_alias_scope;
    END IF;

    IF p_suggestion_confidence IS NOT NULL
       AND (p_suggestion_confidence < 0 OR p_suggestion_confidence > 1) THEN
        RAISE EXCEPTION 'Suggestion confidence must be between 0 and 1';
    END IF;

    -- Load document line and owning firm.
    SELECT
        dl.document_id,
        d.firm_id,
        dl.description
    INTO
        v_document_id,
        v_document_firm_id,
        v_source_text
    FROM document_lines dl
    JOIN documents d ON d.id = dl.document_id
    WHERE dl.id = p_document_line_id
    FOR UPDATE OF dl;

    IF v_document_id IS NULL THEN
        RAISE EXCEPTION 'Document line % not found', p_document_line_id;
    END IF;

    IF v_document_firm_id <> p_firm_id THEN
        RAISE EXCEPTION
            'Document line % belongs to firm %, not firm %',
            p_document_line_id, v_document_firm_id, p_firm_id;
    END IF;

    -- Load selected master item and verify firm ownership.
    SELECT
        fi.firm_id,
        fi.default_unit_id,
        fi.vat_tax_category_id
    INTO
        v_item_firm_id,
        v_item_unit_id,
        v_item_vat_tax_category_id
    FROM firm_items fi
    WHERE fi.id = p_selected_firm_item_id
      AND fi.is_active = TRUE;

    IF v_item_firm_id IS NULL THEN
        RAISE EXCEPTION 'Firm item % not found or inactive', p_selected_firm_item_id;
    END IF;

    IF v_item_firm_id <> p_firm_id THEN
        RAISE EXCEPTION
            'Firm item % belongs to firm %, not firm %',
            p_selected_firm_item_id, v_item_firm_id, p_firm_id;
    END IF;

    v_normalized := normalize_firm_item_alias(v_source_text);

    IF v_normalized IS NULL THEN
        RAISE EXCEPTION 'Document line description cannot normalize to an empty value';
    END IF;

    -- Update the authoritative link for this document line.
    -- Preserve already-resolved line snapshots; inherit only when NULL.
    UPDATE document_lines
    SET firm_item_id = p_selected_firm_item_id,
        unit_id = COALESCE(unit_id, v_item_unit_id),
        vat_tax_category_id = COALESCE(vat_tax_category_id, v_item_vat_tax_category_id)
    WHERE id = p_document_line_id;

    -- Optionally remember the source description as a confirmed alias.
    IF p_remember_as_alias THEN

        IF p_alias_scope = 'counterparty' AND p_counterparty_id IS NULL THEN
            RAISE EXCEPTION
                'counterparty alias scope requires p_counterparty_id';
        END IF;

        -- Generic alias.
        IF p_alias_scope = 'generic' THEN
            SELECT a.id
            INTO v_alias_id
            FROM firm_item_aliases a
            WHERE a.firm_id = p_firm_id
              AND a.counterparty_id IS NULL
              AND a.normalized_alias = v_normalized
              AND a.is_active = TRUE
            FOR UPDATE;

            IF v_alias_id IS NULL THEN
                INSERT INTO firm_item_aliases
                (
                    id,
                    firm_id,
                    firm_item_id,
                    counterparty_id,
                    alias_text,
                    normalized_alias,
                    alias_source,
                    is_confirmed,
                    last_match_confidence,
                    first_used_at,
                    last_used_at,
                    usage_count,
                    metadata
                )
                VALUES
                (
                    gen_random_uuid(),
                    p_firm_id,
                    p_selected_firm_item_id,
                    NULL,
                    v_source_text,
                    v_normalized,
                    CASE
                        WHEN p_suggestion_method = 'semantic_ai'
                            THEN 'ai_suggested_confirmed'
                        ELSE 'user_confirmed'
                    END,
                    TRUE,
                    p_suggestion_confidence,
                    NOW(),
                    NOW(),
                    1,
                    jsonb_build_object(
                        'created_via','confirm_firm_item_match'
                    )
                )
                RETURNING id INTO v_alias_id;
            ELSE
                UPDATE firm_item_aliases
                SET firm_item_id = p_selected_firm_item_id,
                    alias_text = v_source_text,
                    is_confirmed = TRUE,
                    last_match_confidence = p_suggestion_confidence,
                    first_used_at = COALESCE(first_used_at, NOW()),
                    last_used_at = NOW(),
                    usage_count = usage_count + 1
                WHERE id = v_alias_id;
            END IF;

        -- Counterparty-specific alias.
        ELSE
            SELECT a.id
            INTO v_alias_id
            FROM firm_item_aliases a
            WHERE a.firm_id = p_firm_id
              AND a.counterparty_id = p_counterparty_id
              AND a.normalized_alias = v_normalized
              AND a.is_active = TRUE
            FOR UPDATE;

            IF v_alias_id IS NULL THEN
                INSERT INTO firm_item_aliases
                (
                    id,
                    firm_id,
                    firm_item_id,
                    counterparty_id,
                    alias_text,
                    normalized_alias,
                    alias_source,
                    is_confirmed,
                    last_match_confidence,
                    first_used_at,
                    last_used_at,
                    usage_count,
                    metadata
                )
                VALUES
                (
                    gen_random_uuid(),
                    p_firm_id,
                    p_selected_firm_item_id,
                    p_counterparty_id,
                    v_source_text,
                    v_normalized,
                    CASE
                        WHEN p_suggestion_method = 'semantic_ai'
                            THEN 'ai_suggested_confirmed'
                        ELSE 'user_confirmed'
                    END,
                    TRUE,
                    p_suggestion_confidence,
                    NOW(),
                    NOW(),
                    1,
                    jsonb_build_object(
                        'created_via','confirm_firm_item_match'
                    )
                )
                RETURNING id INTO v_alias_id;
            ELSE
                UPDATE firm_item_aliases
                SET firm_item_id = p_selected_firm_item_id,
                    alias_text = v_source_text,
                    is_confirmed = TRUE,
                    last_match_confidence = p_suggestion_confidence,
                    first_used_at = COALESCE(first_used_at, NOW()),
                    last_used_at = NOW(),
                    usage_count = usage_count + 1
                WHERE id = v_alias_id;
            END IF;
        END IF;
    END IF;

    -- Audit the user/system decision.
    INSERT INTO firm_item_match_decisions
    (
        id,
        firm_id,
        document_line_id,
        counterparty_id,
        source_text,
        normalized_source_text,
        suggested_firm_item_id,
        selected_firm_item_id,
        decision,
        suggestion_method,
        suggestion_confidence,
        remember_as_alias,
        decided_by,
        decided_at,
        metadata
    )
    VALUES
    (
        gen_random_uuid(),
        p_firm_id,
        p_document_line_id,
        p_counterparty_id,
        v_source_text,
        v_normalized,
        p_suggested_firm_item_id,
        p_selected_firm_item_id,
        p_decision,
        p_suggestion_method,
        p_suggestion_confidence,
        p_remember_as_alias,
        p_decided_by,
        NOW(),
        jsonb_build_object(
            'alias_scope',p_alias_scope,
            'alias_id',v_alias_id
        )
    )
    RETURNING id INTO v_decision_id;

    RETURN v_decision_id;
END;
$$;


--
-- Name: FUNCTION confirm_firm_item_match(p_firm_id uuid, p_document_line_id uuid, p_selected_firm_item_id uuid, p_counterparty_id uuid, p_suggested_firm_item_id uuid, p_decision character varying, p_suggestion_method character varying, p_suggestion_confidence numeric, p_remember_as_alias boolean, p_alias_scope character varying, p_decided_by uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.confirm_firm_item_match(p_firm_id uuid, p_document_line_id uuid, p_selected_firm_item_id uuid, p_counterparty_id uuid, p_suggested_firm_item_id uuid, p_decision character varying, p_suggestion_method character varying, p_suggestion_confidence numeric, p_remember_as_alias boolean, p_alias_scope character varying, p_decided_by uuid) IS 'Atomically confirms a document-line match to firm_items, optionally remembers an alias, updates usage statistics and records the decision audit trail.';


--
-- Name: find_firm_item_alias_matches(uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.find_firm_item_alias_matches(p_firm_id uuid, p_counterparty_id uuid, p_source_text text) RETURNS TABLE(alias_id uuid, firm_item_id uuid, firm_item_code character varying, firm_item_name character varying, item_type character varying, match_method character varying, match_rank integer, usage_count bigint, last_used_at timestamp with time zone)
    LANGUAGE sql STABLE
    AS $$
 WITH q AS (SELECT normalize_firm_item_alias(p_source_text) normalized)
 SELECT a.id,a.firm_item_id,i.code,i.name,i.item_type,
   CASE WHEN a.counterparty_id=p_counterparty_id
        THEN 'normalized_counterparty_alias'::VARCHAR
        ELSE 'normalized_generic_alias'::VARCHAR END,
   CASE WHEN a.counterparty_id=p_counterparty_id THEN 1 ELSE 2 END,
   a.usage_count,a.last_used_at
 FROM firm_item_aliases a
 JOIN firm_items i ON i.id=a.firm_item_id
 CROSS JOIN q
 WHERE a.firm_id=p_firm_id
   AND a.is_active=TRUE AND a.is_confirmed=TRUE AND i.is_active=TRUE
   AND q.normalized IS NOT NULL
   AND a.normalized_alias=q.normalized
   AND ((p_counterparty_id IS NOT NULL AND a.counterparty_id=p_counterparty_id)
        OR a.counterparty_id IS NULL)
 ORDER BY CASE WHEN a.counterparty_id=p_counterparty_id THEN 1 ELSE 2 END,
          a.usage_count DESC,a.last_used_at DESC NULLS LAST,a.created_at ASC;
$$;


--
-- Name: normalize_firm_item_alias(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.normalize_firm_item_alias(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE
    AS $$
 SELECT NULLIF(trim(regexp_replace(regexp_replace(lower(trim(p_text)),
 '[[:punct:]]+',' ','g'),'[[:space:]]+',' ','g')),'');
$$;


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


--
-- Name: trg_normalize_firm_item_alias(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_normalize_firm_item_alias() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 NEW.normalized_alias := normalize_firm_item_alias(NEW.alias_text);
 IF NEW.normalized_alias IS NULL THEN
   RAISE EXCEPTION 'alias_text cannot normalize to an empty value';
 END IF;
 RETURN NEW;
END;
$$;


--
-- Name: trg_normalize_firm_item_match_source(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_normalize_firm_item_match_source() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 NEW.normalized_source_text := normalize_firm_item_alias(NEW.source_text);
 IF NEW.normalized_source_text IS NULL THEN
   RAISE EXCEPTION 'source_text cannot normalize to an empty value';
 END IF;
 RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: account_balance_transfer_suggestions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account_balance_transfer_suggestions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    transition_event_id uuid NOT NULL,
    source_account_id uuid NOT NULL,
    target_account_id uuid NOT NULL,
    balance_side character varying(10) NOT NULL,
    currency_id uuid,
    proposed_amount_currency numeric(20,4),
    proposed_amount_base_eur numeric(20,4) NOT NULL,
    status character varying(20) DEFAULT 'suggested'::character varying NOT NULL,
    decided_by uuid,
    journal_entry_id uuid,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT account_balance_transfer_suggestions_balance_side_check CHECK (((balance_side)::text = ANY ((ARRAY['debit'::character varying, 'credit'::character varying])::text[]))),
    CONSTRAINT account_balance_transfer_suggestions_status_check CHECK (((status)::text = ANY ((ARRAY['suggested'::character varying, 'accepted'::character varying, 'modified'::character varying, 'rejected'::character varying, 'executed'::character varying])::text[])))
);


--
-- Name: account_dimension_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account_dimension_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    account_id uuid NOT NULL,
    dimension_id uuid NOT NULL,
    usage_mode character varying(20) NOT NULL,
    tracking_mode character varying(30) DEFAULT 'none'::character varying NOT NULL,
    inherit_to_children boolean DEFAULT true NOT NULL,
    inheritance_mode character varying(30) DEFAULT 'inherit'::character varying NOT NULL,
    is_locked boolean DEFAULT false NOT NULL,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT account_dimension_rules_inheritance_mode_check CHECK (((inheritance_mode)::text = ANY ((ARRAY['none'::character varying, 'inherit'::character varying, 'locked_inherit'::character varying])::text[]))),
    CONSTRAINT account_dimension_rules_tracking_mode_check CHECK (((tracking_mode)::text = ANY ((ARRAY['none'::character varying, 'balance_only'::character varying, 'open_item'::character varying, 'optional_open_item'::character varying])::text[]))),
    CONSTRAINT account_dimension_rules_usage_mode_check CHECK (((usage_mode)::text = ANY ((ARRAY['disabled'::character varying, 'optional'::character varying, 'required'::character varying])::text[])))
);


--
-- Name: account_sections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account_sections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    parent_section_id uuid,
    code character varying(20) NOT NULL,
    name character varying(255) NOT NULL,
    level integer,
    default_account_type_id uuid,
    default_normal_balance_side_id uuid,
    default_semantic_type_id uuid,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: account_semantic_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account_semantic_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    description text
);


--
-- Name: account_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(30) NOT NULL,
    name character varying(100) NOT NULL,
    description text
);


--
-- Name: accounting_periods; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.accounting_periods (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    period_year integer NOT NULL,
    period_month integer NOT NULL,
    date_from date NOT NULL,
    date_to date NOT NULL,
    status character varying(20) DEFAULT 'open'::character varying NOT NULL,
    closed_at timestamp with time zone,
    closed_by uuid,
    locked_at timestamp with time zone,
    locked_by uuid,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT accounting_periods_period_month_check CHECK (((period_month >= 1) AND (period_month <= 12))),
    CONSTRAINT accounting_periods_status_check CHECK (((status)::text = ANY ((ARRAY['open'::character varying, 'closed'::character varying, 'locked'::character varying])::text[])))
);


--
-- Name: activity_vat_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activity_vat_tags (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    activity_code_id uuid NOT NULL,
    vat_activity_tag_id uuid NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
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
    postal_code character varying(20),
    street character varying(255),
    street_number character varying(50),
    building character varying(100),
    entrance character varying(50),
    floor character varying(50),
    apartment character varying(50),
    address_line character varying(500),
    notes text,
    source_system character varying(100),
    external_id character varying(255),
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    postal_code_id uuid
);


--
-- Name: COLUMN addresses.postal_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.addresses.postal_code IS 'Snapshot/fallback postal code retained for OCR/import/foreign and historical source fidelity.';


--
-- Name: COLUMN addresses.postal_code_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.addresses.postal_code_id IS 'Optional structured reference to ref_postal_codes.';


--
-- Name: analytic_dimension_values; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analytic_dimension_values (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    dimension_id uuid NOT NULL,
    parent_id uuid,
    scope_type character varying(20) DEFAULT 'firm'::character varying NOT NULL,
    firm_id uuid,
    firm_group_id uuid,
    code character varying(100),
    name character varying(255) NOT NULL,
    valid_from date,
    valid_to date,
    is_active boolean DEFAULT true NOT NULL,
    source_system character varying(100),
    external_id character varying(255),
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT analytic_dimension_values_check CHECK (((((scope_type)::text = 'firm'::text) AND (firm_id IS NOT NULL) AND (firm_group_id IS NULL)) OR (((scope_type)::text = 'group'::text) AND (firm_id IS NULL) AND (firm_group_id IS NOT NULL)) OR (((scope_type)::text = 'global'::text) AND (firm_id IS NULL) AND (firm_group_id IS NULL)))),
    CONSTRAINT analytic_dimension_values_scope_type_check CHECK (((scope_type)::text = ANY ((ARRAY['firm'::character varying, 'group'::character varying, 'global'::character varying])::text[])))
);


--
-- Name: analytic_dimensions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analytic_dimensions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    value_source_type character varying(100) DEFAULT 'generic'::character varying NOT NULL,
    allows_firm_scope boolean DEFAULT true NOT NULL,
    allows_group_scope boolean DEFAULT false NOT NULL,
    allows_global_scope boolean DEFAULT false NOT NULL,
    is_hierarchical boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
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
-- Name: chart_of_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chart_of_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    section_id uuid,
    parent_id uuid,
    code character varying(50) NOT NULL,
    normalized_code character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    level integer,
    account_type_id uuid NOT NULL,
    normal_balance_side_id uuid NOT NULL,
    semantic_type_id uuid NOT NULL,
    can_post_directly boolean DEFAULT true NOT NULL,
    allows_children boolean DEFAULT true NOT NULL,
    saft_code character varying(50),
    saft_name character varying(255),
    saft_mapping_status character varying(20) DEFAULT 'unmapped'::character varying NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chart_of_accounts_saft_mapping_status_check CHECK (((saft_mapping_status)::text = ANY ((ARRAY['unmapped'::character varying, 'mapped'::character varying, 'manual'::character varying, 'review'::character varying])::text[])))
);


--
-- Name: cost_centers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cost_centers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    parent_id uuid,
    scope_type character varying(20) NOT NULL,
    firm_id uuid,
    firm_group_id uuid,
    code character varying(100),
    name character varying(255) NOT NULL,
    valid_from date,
    valid_to date,
    is_active boolean DEFAULT true NOT NULL,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT cost_centers_scope_type_check CHECK (((scope_type)::text = ANY ((ARRAY['firm'::character varying, 'group'::character varying, 'global'::character varying])::text[])))
);


--
-- Name: counterparties; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.counterparties (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    country_id uuid,
    name character varying(255) NOT NULL,
    short_name character varying(255),
    registration_number character varying(50),
    vat_number character varying(50),
    is_person boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    source_system character varying(100),
    external_id character varying(255),
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: counterparty_addresses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.counterparty_addresses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    counterparty_id uuid NOT NULL,
    address_id uuid NOT NULL,
    address_type character varying(50) NOT NULL,
    valid_from date,
    valid_to date,
    is_primary boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: counterparty_bank_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.counterparty_bank_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    counterparty_id uuid NOT NULL,
    bank_id uuid,
    iban character varying(50),
    account_number character varying(100),
    currency_id uuid,
    bic_swift character varying(20),
    account_name character varying(255),
    valid_from date,
    valid_to date,
    is_primary boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    source_system character varying(100),
    external_id character varying(255),
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT counterparty_bank_accounts_check CHECK (((iban IS NOT NULL) OR (account_number IS NOT NULL)))
);


--
-- Name: counterparty_role_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.counterparty_role_assignments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    counterparty_id uuid NOT NULL,
    role_id uuid NOT NULL,
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
-- Name: counterparty_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.counterparty_roles (
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
-- Name: document_class_capabilities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_class_capabilities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    document_class_id uuid NOT NULL,
    capability_code character varying(100) NOT NULL,
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
-- Name: document_counterparty_snapshots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_counterparty_snapshots (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    document_id uuid NOT NULL,
    counterparty_id uuid,
    name_snapshot character varying(255),
    registration_number_snapshot character varying(100),
    vat_number_snapshot character varying(100),
    country_id_snapshot uuid,
    address_snapshot jsonb,
    source_mode character varying(30) DEFAULT 'copied_from_master'::character varying NOT NULL,
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
    code character varying(20) NOT NULL,
    name character varying(100) NOT NULL,
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
    file_role character varying(50),
    file_name character varying(500) NOT NULL,
    mime_type character varying(150),
    storage_provider character varying(100),
    storage_path text NOT NULL,
    checksum_sha256 character varying(64),
    file_size bigint,
    is_original boolean DEFAULT false NOT NULL,
    is_primary boolean DEFAULT false NOT NULL,
    source_system character varying(100),
    external_id character varying(255),
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
    net_amount numeric(20,4),
    vat_amount numeric(20,4),
    gross_amount numeric(20,4),
    due_date date,
    payment_terms_days integer,
    payment_reference character varying(255),
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: document_line_journal_lines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_line_journal_lines (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    document_line_id uuid NOT NULL,
    journal_entry_line_id uuid NOT NULL,
    allocated_amount_base_eur numeric(20,4),
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
    quantity numeric(20,6),
    unit_code character varying(50),
    unit_price numeric(20,6),
    discount_percent numeric(9,6),
    discount_amount numeric(20,4),
    net_amount numeric(20,4),
    vat_rate_percent numeric(5,2),
    vat_amount numeric(20,4),
    gross_amount numeric(20,4),
    product_service_type character varying(50),
    source_system character varying(100),
    external_id character varying(255),
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    firm_item_id uuid,
    unit_id uuid,
    vat_tax_category_id uuid
);


--
-- Name: COLUMN document_lines.firm_item_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.document_lines.firm_item_id IS 'Optional link to reusable firm_items master. Raw description on the document line remains preserved as the document snapshot.';


--
-- Name: COLUMN document_lines.unit_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.document_lines.unit_id IS 'Normalized unit-of-measure reference. Original imported unit_code remains preserved for source fidelity.';


--
-- Name: COLUMN document_lines.vat_tax_category_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.document_lines.vat_tax_category_id IS 'Resolved VAT tax category snapshot for this document line. Normally inherited from firm_item but stored here so historical classification remains stable if the master item changes later.';


--
-- Name: document_parties; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_parties (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    document_id uuid NOT NULL,
    role_id uuid NOT NULL,
    counterparty_id uuid,
    firm_id uuid,
    display_name_snapshot character varying(255),
    registration_number_snapshot character varying(100),
    vat_number_snapshot character varying(100),
    address_snapshot jsonb,
    sort_order integer,
    is_primary boolean DEFAULT false NOT NULL,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT document_parties_check CHECK (((counterparty_id IS NOT NULL) OR (firm_id IS NOT NULL) OR (display_name_snapshot IS NOT NULL)))
);


--
-- Name: document_party_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_party_roles (
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
-- Name: document_relation_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_relation_types (
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
    CONSTRAINT document_relations_check CHECK ((source_document_id <> target_document_id))
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
    code character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    prefix character varying(50),
    digits_count integer DEFAULT 10 NOT NULL,
    start_number bigint DEFAULT 1 NOT NULL,
    next_number bigint DEFAULT 1 NOT NULL,
    max_number bigint,
    reset_period character varying(20) DEFAULT 'none'::character varying NOT NULL,
    date_part_mode character varying(20) DEFAULT 'none'::character varying NOT NULL,
    date_format character varying(50),
    separator character varying(10),
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
    code character varying(30) NOT NULL,
    name character varying(100) NOT NULL,
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
    code character varying(50) NOT NULL,
    name character varying(150) NOT NULL,
    short_name character varying(50),
    name_en character varying(150),
    nap_code character varying(20),
    default_direction_id uuid,
    default_posting_disposition character varying(20) DEFAULT 'pending'::character varying NOT NULL,
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
    document_number character varying(255),
    document_date date,
    received_date date,
    posting_date date,
    posting_disposition character varying(20) DEFAULT 'pending'::character varying NOT NULL,
    not_for_posting_reason text,
    description text,
    internal_notes text,
    source_type character varying(50),
    source_reference character varying(255),
    is_active boolean DEFAULT true NOT NULL,
    created_by uuid,
    updated_by uuid,
    source_system character varying(100),
    external_id character varying(255),
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT documents_posting_disposition_check CHECK (((posting_disposition)::text = ANY ((ARRAY['pending'::character varying, 'for_posting'::character varying, 'not_for_posting'::character varying])::text[])))
);


--
-- Name: economic_activity_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.economic_activity_codes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    version_id uuid NOT NULL,
    parent_id uuid,
    code character varying(30) NOT NULL,
    name character varying(500) NOT NULL,
    level integer,
    is_leaf boolean DEFAULT true NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: economic_activity_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.economic_activity_versions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    valid_from date,
    valid_to date,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: firm_account_dimension_bindings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.firm_account_dimension_bindings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_account_id uuid NOT NULL,
    dimension_id uuid NOT NULL,
    value_ref_type character varying(100) NOT NULL,
    value_ref_id uuid NOT NULL,
    binding_mode character varying(20) NOT NULL,
    inherit_to_children boolean DEFAULT true NOT NULL,
    locked_for_children boolean DEFAULT false NOT NULL,
    effective_from date,
    effective_to date,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT firm_account_dimension_bindings_binding_mode_check CHECK (((binding_mode)::text = ANY ((ARRAY['fixed'::character varying, 'default'::character varying])::text[])))
);


--
-- Name: firm_account_dimension_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.firm_account_dimension_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_account_id uuid NOT NULL,
    dimension_id uuid NOT NULL,
    usage_mode character varying(20) NOT NULL,
    tracking_mode character varying(30) DEFAULT 'none'::character varying NOT NULL,
    inherit_to_children boolean DEFAULT true NOT NULL,
    inheritance_mode character varying(30) DEFAULT 'inherit'::character varying NOT NULL,
    effective_from date,
    effective_to date,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT firm_account_dimension_rules_inheritance_mode_check CHECK (((inheritance_mode)::text = ANY ((ARRAY['none'::character varying, 'inherit'::character varying, 'locked_inherit'::character varying])::text[]))),
    CONSTRAINT firm_account_dimension_rules_tracking_mode_check CHECK (((tracking_mode)::text = ANY ((ARRAY['none'::character varying, 'balance_only'::character varying, 'open_item'::character varying, 'optional_open_item'::character varying])::text[]))),
    CONSTRAINT firm_account_dimension_rules_usage_mode_check CHECK (((usage_mode)::text = ANY ((ARRAY['disabled'::character varying, 'optional'::character varying, 'required'::character varying])::text[])))
);


--
-- Name: firm_account_transition_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.firm_account_transition_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    transition_type character varying(30) NOT NULL,
    effective_date date NOT NULL,
    reason text,
    notes text,
    is_active boolean DEFAULT true NOT NULL,
    created_by uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT firm_account_transition_events_transition_type_check CHECK (((transition_type)::text = ANY ((ARRAY['renumbered_to'::character varying, 'replaced_by'::character varying, 'split_into'::character varying, 'merged_into'::character varying, 'closed_to'::character varying])::text[])))
);


--
-- Name: firm_account_transition_sources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.firm_account_transition_sources (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    transition_event_id uuid NOT NULL,
    firm_account_id uuid NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: firm_account_transition_targets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.firm_account_transition_targets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    transition_event_id uuid NOT NULL,
    firm_account_id uuid NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: firm_accounting_locks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.firm_accounting_locks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    locked_through_date date NOT NULL,
    reason text,
    is_active boolean DEFAULT true NOT NULL,
    created_by uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: firm_activities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.firm_activities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    activity_code_id uuid NOT NULL,
    is_primary boolean DEFAULT false NOT NULL,
    primary_basis character varying(50),
    valid_from date,
    valid_to date,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: firm_addresses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.firm_addresses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    address_id uuid NOT NULL,
    address_type character varying(50) NOT NULL,
    valid_from date,
    valid_to date,
    is_primary boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: firm_bank_account_ledger_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.firm_bank_account_ledger_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_bank_account_id uuid NOT NULL,
    firm_account_id uuid NOT NULL,
    valid_from date,
    valid_to date,
    is_default boolean DEFAULT true NOT NULL,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: firm_bank_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.firm_bank_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    bank_id uuid,
    iban character varying(50),
    account_number character varying(100),
    currency_id uuid NOT NULL,
    bic_swift character varying(20),
    account_name character varying(255),
    valid_from date,
    valid_to date,
    is_primary boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    notes text,
    source_system character varying(100),
    external_id character varying(255),
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT firm_bank_accounts_check CHECK (((iban IS NOT NULL) OR (account_number IS NOT NULL)))
);


--
-- Name: firm_chart_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.firm_chart_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    master_account_id uuid,
    parent_id uuid,
    section_id uuid NOT NULL,
    account_type_id uuid NOT NULL,
    normal_balance_side_id uuid NOT NULL,
    semantic_type_id uuid NOT NULL,
    code character varying(50) NOT NULL,
    normalized_code character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    short_name character varying(255),
    can_post_directly boolean DEFAULT true NOT NULL,
    allows_children boolean DEFAULT true NOT NULL,
    children_inherit_dimensions boolean DEFAULT true NOT NULL,
    children_can_override_dimensions boolean DEFAULT true NOT NULL,
    valid_from date,
    valid_to date,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer,
    notes text,
    source_system character varying(100),
    external_id character varying(255),
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: firm_counterparties; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.firm_counterparties (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    counterparty_id uuid NOT NULL,
    internal_code character varying(50),
    default_currency_id uuid,
    payment_terms_days integer,
    is_blocked boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    notes text,
    source_system character varying(100),
    external_id character varying(255),
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: firm_counterparty_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.firm_counterparty_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_counterparty_id uuid NOT NULL,
    firm_account_id uuid NOT NULL,
    account_usage_type character varying(50) NOT NULL,
    currency_id uuid,
    valid_from date,
    valid_to date,
    is_default boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    notes text,
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
    posting_disposition_override character varying(20),
    display_position integer,
    is_visible boolean DEFAULT true NOT NULL,
    is_enabled boolean DEFAULT true NOT NULL,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT firm_document_types_posting_disposition_override_check CHECK (((posting_disposition_override)::text = ANY ((ARRAY['pending'::character varying, 'for_posting'::character varying, 'not_for_posting'::character varying])::text[])))
);


--
-- Name: firm_foreign_vat_registrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.firm_foreign_vat_registrations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    country_id uuid NOT NULL,
    registration_number character varying(100),
    registration_type character varying(30) DEFAULT 'local_vat'::character varying NOT NULL,
    valid_from date NOT NULL,
    valid_to date,
    is_active boolean DEFAULT true NOT NULL,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT firm_foreign_vat_reg_dates_check CHECK (((valid_to IS NULL) OR (valid_to >= valid_from))),
    CONSTRAINT firm_foreign_vat_reg_type_check CHECK (((registration_type)::text = ANY ((ARRAY['local_vat'::character varying, 'oss_union'::character varying])::text[])))
);


--
-- Name: TABLE firm_foreign_vat_registrations; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.firm_foreign_vat_registrations IS 'Foreign VAT reporting registrations/routes by firm and country. Used to choose OSS Union versus direct local VAT reporting after destination taxation has been determined.';


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
-- Name: firm_item_aliases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.firm_item_aliases (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    firm_item_id uuid NOT NULL,
    counterparty_id uuid,
    alias_text text NOT NULL,
    normalized_alias text NOT NULL,
    alias_source character varying(30) DEFAULT 'user_confirmed'::character varying NOT NULL,
    is_confirmed boolean DEFAULT true NOT NULL,
    last_match_confidence numeric(6,5),
    first_used_at timestamp with time zone,
    last_used_at timestamp with time zone,
    usage_count bigint DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT firm_item_aliases_confidence_check CHECK (((last_match_confidence IS NULL) OR ((last_match_confidence >= (0)::numeric) AND (last_match_confidence <= (1)::numeric)))),
    CONSTRAINT firm_item_aliases_source_check CHECK (((alias_source)::text = ANY ((ARRAY['user_confirmed'::character varying, 'imported'::character varying, 'ai_suggested_confirmed'::character varying, 'system'::character varying])::text[])))
);


--
-- Name: firm_item_match_decisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.firm_item_match_decisions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    document_line_id uuid,
    counterparty_id uuid,
    source_text text NOT NULL,
    normalized_source_text text NOT NULL,
    suggested_firm_item_id uuid,
    selected_firm_item_id uuid,
    decision character varying(30) NOT NULL,
    suggestion_method character varying(40),
    suggestion_confidence numeric(6,5),
    remember_as_alias boolean DEFAULT false NOT NULL,
    decided_by uuid,
    decided_at timestamp with time zone DEFAULT now() NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT firm_item_match_decisions_confidence_check CHECK (((suggestion_confidence IS NULL) OR ((suggestion_confidence >= (0)::numeric) AND (suggestion_confidence <= (1)::numeric)))),
    CONSTRAINT firm_item_match_decisions_decision_check CHECK (((decision)::text = ANY ((ARRAY['accepted'::character varying, 'changed'::character varying, 'new_item'::character varying, 'skipped'::character varying])::text[]))),
    CONSTRAINT firm_item_match_decisions_method_check CHECK (((suggestion_method IS NULL) OR ((suggestion_method)::text = ANY ((ARRAY['exact_counterparty_alias'::character varying, 'exact_generic_alias'::character varying, 'normalized_counterparty_alias'::character varying, 'normalized_generic_alias'::character varying, 'usage_history'::character varying, 'semantic_ai'::character varying, 'manual_search'::character varying, 'none'::character varying])::text[]))))
);


--
-- Name: firm_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.firm_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    item_type character varying(20) NOT NULL,
    code character varying(100),
    name character varying(255) NOT NULL,
    description text,
    default_unit_id uuid,
    vat_tax_category_id uuid,
    revenue_account_id uuid,
    expense_account_id uuid,
    inventory_account_id uuid,
    is_stock_managed boolean DEFAULT false NOT NULL,
    allows_quantity boolean DEFAULT true NOT NULL,
    valid_from date,
    valid_to date,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer,
    source_system character varying(100),
    external_id character varying(150),
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT firm_items_dates_check CHECK (((valid_to IS NULL) OR (valid_from IS NULL) OR (valid_to >= valid_from))),
    CONSTRAINT firm_items_type_check CHECK (((item_type)::text = ANY ((ARRAY['goods'::character varying, 'service'::character varying])::text[])))
);


--
-- Name: TABLE firm_items; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.firm_items IS 'Firm-level master for reusable goods and services. VAT tax category is attached here so destination-country VAT can be resolved independently of accounting account.';


--
-- Name: COLUMN firm_items.is_stock_managed; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.firm_items.is_stock_managed IS 'TRUE for items whose quantities/stock movements are maintained as inventory. Services are normally FALSE.';


--
-- Name: COLUMN firm_items.allows_quantity; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.firm_items.allows_quantity IS 'Whether document lines for this item may carry quantity/unit data. Kept TRUE by default because services may also be quantity-based (hours, months, sessions, etc.).';


--
-- Name: firm_report_account_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.firm_report_account_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    master_report_account_rule_id uuid,
    report_line_id uuid NOT NULL,
    firm_account_id uuid,
    metric_type character varying(30),
    include_descendants boolean,
    corresponding_firm_account_id uuid,
    multiplier numeric(12,4),
    priority integer,
    is_active boolean DEFAULT true NOT NULL,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: firm_vat_credit_coefficients; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.firm_vat_credit_coefficients (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    applicable_year integer NOT NULL,
    applied_coefficient numeric(12,10) NOT NULL,
    final_coefficient numeric(12,10),
    calculated_at timestamp with time zone,
    finalized_at timestamp with time zone,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT firm_vat_credit_coefficients_applied_check CHECK (((applied_coefficient >= (0)::numeric) AND (applied_coefficient <= (1)::numeric))),
    CONSTRAINT firm_vat_credit_coefficients_final_check CHECK (((final_coefficient IS NULL) OR ((final_coefficient >= (0)::numeric) AND (final_coefficient <= (1)::numeric)))),
    CONSTRAINT firm_vat_credit_coefficients_year_check CHECK (((applicable_year >= 1900) AND (applicable_year <= 9999)))
);


--
-- Name: TABLE firm_vat_credit_coefficients; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.firm_vat_credit_coefficients IS 'One annual partial input-VAT credit coefficient record per firm/year. The coefficient calculation is derived from transactions and VAT classifications rather than duplicated as stored turnover totals.';


--
-- Name: COLUMN firm_vat_credit_coefficients.applied_coefficient; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.firm_vat_credit_coefficients.applied_coefficient IS 'Coefficient applied for the applicable year. Calculation logic is derived dynamically from transactions/VAT terms and may be populated manually or by the VAT engine.';


--
-- Name: COLUMN firm_vat_credit_coefficients.final_coefficient; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.firm_vat_credit_coefficients.final_coefficient IS 'Optional final coefficient after annual recalculation. Historical document VAT amounts remain unchanged.';


--
-- Name: firm_vat_registrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.firm_vat_registrations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    vat_number character varying(50),
    valid_from date NOT NULL,
    valid_to date,
    is_current boolean DEFAULT false NOT NULL,
    notes text,
    source_system character varying(100),
    external_id character varying(255),
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    vat_registration_type_id uuid NOT NULL,
    CONSTRAINT firm_vat_registrations_valid_period_chk CHECK (((valid_to IS NULL) OR (valid_to >= valid_from)))
);


--
-- Name: COLUMN firm_vat_registrations.is_current; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.firm_vat_registrations.is_current IS 'Operational convenience flag only. Historical VAT logic must use valid_from/valid_to rather than relying on is_current.';


--
-- Name: COLUMN firm_vat_registrations.vat_registration_type_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.firm_vat_registrations.vat_registration_type_id IS 'VAT registration/regime type applicable to the firm for the validity period. Multiple different types may be active in parallel.';


--
-- Name: firm_vat_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.firm_vat_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    master_vat_rule_id uuid,
    code character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    transaction_scope character varying(20),
    territory_scope character varying(20),
    vat_activity_tag_id uuid,
    vat_term_id uuid,
    vies_type_id uuid,
    vat_special_regime_id uuid,
    vat_article_id uuid,
    requires_protocol boolean,
    allows_tax_credit boolean,
    priority integer,
    is_active boolean DEFAULT true NOT NULL,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: firm_vat_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.firm_vat_settings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    nondeductible_vat_account_id uuid,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE firm_vat_settings; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.firm_vat_settings IS 'Firm-level VAT accounting defaults. Master VAT rules must not hardcode a firm ledger account such as 609.';


--
-- Name: COLUMN firm_vat_settings.nondeductible_vat_account_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.firm_vat_settings.nondeductible_vat_account_id IS 'Default firm ledger account for VAT with no right to tax credit. May be 609 or a firm-specific analytic derivative/configured cost account.';


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
-- Name: import_batches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.import_batches (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid,
    import_type character varying(100) NOT NULL,
    source_format character varying(50),
    source_file_name character varying(500),
    source_file_checksum character varying(64),
    status character varying(30) DEFAULT 'created'::character varying NOT NULL,
    total_rows integer,
    success_rows integer,
    warning_rows integer,
    error_rows integer,
    created_by uuid,
    source_system character varying(100),
    external_id character varying(255),
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
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
    extraction_type character varying(50) NOT NULL,
    content_json jsonb,
    content_text text,
    confidence numeric(8,6),
    is_current boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ingestion_files; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ingestion_files (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ingestion_item_id uuid NOT NULL,
    file_role character varying(50),
    file_name character varying(500) NOT NULL,
    mime_type character varying(150),
    storage_provider character varying(100),
    storage_path text NOT NULL,
    checksum_sha256 character varying(64),
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
    status character varying(50) DEFAULT 'received'::character varying NOT NULL,
    source_type character varying(50),
    source_reference character varying(255),
    promoted_document_id uuid,
    is_promoted boolean DEFAULT false NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ingestion_predictions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ingestion_predictions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ingestion_item_id uuid NOT NULL,
    ingestion_run_id uuid,
    prediction_type character varying(100) NOT NULL,
    predicted_value jsonb NOT NULL,
    confidence numeric(8,6),
    status character varying(30) DEFAULT 'suggested'::character varying NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ingestion_runs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ingestion_runs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    ingestion_item_id uuid NOT NULL,
    run_type character varying(100) NOT NULL,
    orchestrator character varying(100),
    workflow_name character varying(255),
    workflow_run_id character varying(255),
    model_name character varying(255),
    status character varying(30) NOT NULL,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    error_message text,
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
    CONSTRAINT integration_outbox_processing_status_check CHECK (((processing_status)::text = ANY ((ARRAY['pending'::character varying, 'processing'::character varying, 'processed'::character varying, 'failed'::character varying])::text[])))
);


--
-- Name: journal_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.journal_entries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    accounting_period_id uuid,
    posting_date date NOT NULL,
    description text,
    source_type character varying(50) DEFAULT 'manual'::character varying NOT NULL,
    source_reference character varying(255),
    import_batch_id uuid,
    status character varying(20) DEFAULT 'draft'::character varying NOT NULL,
    duplicate_status character varying(20) DEFAULT 'none'::character varying NOT NULL,
    source_group_key character varying(255),
    created_by uuid,
    updated_by uuid,
    source_system character varying(100),
    external_id character varying(255),
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT journal_entries_duplicate_status_check CHECK (((duplicate_status)::text = ANY ((ARRAY['none'::character varying, 'possible'::character varying, 'confirmed'::character varying])::text[]))),
    CONSTRAINT journal_entries_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'suggested'::character varying, 'posted'::character varying, 'cancelled'::character varying])::text[])))
);


--
-- Name: journal_entry_documents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.journal_entry_documents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    journal_entry_id uuid NOT NULL,
    document_id uuid NOT NULL,
    relation_role character varying(50) DEFAULT 'source'::character varying NOT NULL,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: journal_entry_lines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.journal_entry_lines (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    journal_entry_id uuid NOT NULL,
    line_no integer NOT NULL,
    firm_account_id uuid NOT NULL,
    debit_amount_base_eur numeric(20,4) DEFAULT 0 NOT NULL,
    credit_amount_base_eur numeric(20,4) DEFAULT 0 NOT NULL,
    currency_id uuid,
    amount_currency numeric(20,4),
    exchange_rate_to_eur numeric(20,10),
    counterparty_id uuid,
    vat_term_id uuid,
    vat_article_id uuid,
    vies_type_id uuid,
    vat_special_regime_id uuid,
    vat_tax_base_amount numeric(20,4),
    vat_amount numeric(20,4),
    due_date date,
    description text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    line_role character varying(30) DEFAULT 'base'::character varying NOT NULL,
    vat_assessment_id uuid,
    CONSTRAINT journal_entry_lines_check CHECK ((((debit_amount_base_eur > (0)::numeric) AND (credit_amount_base_eur = (0)::numeric)) OR ((credit_amount_base_eur > (0)::numeric) AND (debit_amount_base_eur = (0)::numeric)) OR ((debit_amount_base_eur = (0)::numeric) AND (credit_amount_base_eur = (0)::numeric)))),
    CONSTRAINT journal_entry_lines_line_role_check CHECK (((line_role)::text = ANY ((ARRAY['base'::character varying, 'vat_input'::character varying, 'vat_output'::character varying, 'vat_nondeductible'::character varying])::text[])))
);


--
-- Name: COLUMN journal_entry_lines.line_role; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.journal_entry_lines.line_role IS 'Accounting semantic role. base = economic operation; vat_input/vat_output/vat_nondeductible = VAT-only layer generated by VAT assessment/protocol.';


--
-- Name: COLUMN journal_entry_lines.vat_assessment_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.journal_entry_lines.vat_assessment_id IS 'Links VAT-only journal lines to the VAT assessment/protocol that generated them. Base lines normally remain NULL.';


--
-- Name: journal_line_analytics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.journal_line_analytics (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    journal_entry_line_id uuid NOT NULL,
    dimension_id uuid NOT NULL,
    value_ref_type character varying(100) NOT NULL,
    value_ref_id uuid NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: normal_balance_sides; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.normal_balance_sides (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(100) NOT NULL,
    description text
);


--
-- Name: open_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.open_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    source_journal_entry_line_id uuid NOT NULL,
    firm_account_id uuid NOT NULL,
    counterparty_id uuid,
    currency_id uuid,
    original_amount_currency numeric(20,4),
    original_amount_base_eur numeric(20,4) NOT NULL,
    due_date date,
    status character varying(30) DEFAULT 'open'::character varying NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT open_items_status_check CHECK (((status)::text = ANY ((ARRAY['open'::character varying, 'partially_settled'::character varying, 'settled'::character varying, 'cancelled'::character varying])::text[])))
);


--
-- Name: operating_unit_sales_points; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operating_unit_sales_points (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    operating_unit_id uuid NOT NULL,
    code character varying(50),
    name character varying(255) NOT NULL,
    sales_point_type character varying(50) NOT NULL,
    identifier character varying(100),
    fiscal_device_number character varying(100),
    default_sequence_id uuid,
    default_firm_bank_account_id uuid,
    valid_from date,
    valid_to date,
    is_active boolean DEFAULT true NOT NULL,
    notes text,
    source_system character varying(100),
    external_id character varying(255),
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
    code character varying(50),
    name character varying(255) NOT NULL,
    unit_type character varying(50) NOT NULL,
    manager_name character varying(255),
    valid_from date,
    valid_to date,
    is_active boolean DEFAULT true NOT NULL,
    notes text,
    source_system character varying(100),
    external_id character varying(255),
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
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
    CONSTRAINT permission_resource_scopes_effect_check CHECK (((effect)::text = ANY ((ARRAY['allow'::character varying, 'deny'::character varying])::text[])))
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
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    parent_id uuid,
    scope_type character varying(20) NOT NULL,
    firm_id uuid,
    firm_group_id uuid,
    code character varying(100),
    name character varying(255) NOT NULL,
    valid_from date,
    valid_to date,
    is_active boolean DEFAULT true NOT NULL,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT projects_scope_type_check CHECK (((scope_type)::text = ANY ((ARRAY['firm'::character varying, 'group'::character varying, 'global'::character varying])::text[])))
);


--
-- Name: ref_banks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ref_banks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    country_id uuid,
    bic_swift character varying(20),
    code character varying(50),
    name character varying(255) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    source_system character varying(100),
    external_id character varying(255),
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    institution_type character varying(40) NOT NULL,
    CONSTRAINT ref_banks_institution_type_check CHECK (((institution_type)::text = ANY ((ARRAY['central_bank'::character varying, 'bank'::character varying, 'foreign_bank_branch'::character varying, 'payment_institution'::character varying, 'electronic_money_institution'::character varying, 'other'::character varying])::text[])))
);


--
-- Name: COLUMN ref_banks.institution_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ref_banks.institution_type IS 'Type of payment-service institution. Supports official records and custom providers.';


--
-- Name: ref_cities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ref_cities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    country_id uuid NOT NULL,
    municipality_id uuid,
    ekatte character varying(20),
    postal_code character varying(20),
    name character varying(255) NOT NULL,
    settlement_type character varying(50),
    is_active boolean DEFAULT true NOT NULL,
    source_system character varying(100),
    external_id character varying(255),
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    name_latin character varying
);


--
-- Name: COLUMN ref_cities.postal_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ref_cities.postal_code IS 'Compatibility/default field only. Use ref_postal_codes for complete many-postal-codes-per-settlement mapping.';


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
-- Name: ref_districts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ref_districts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    country_id uuid NOT NULL,
    code character varying(30),
    name character varying(255) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    source_system character varying(100),
    external_id character varying(255),
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
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
-- Name: ref_municipalities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ref_municipalities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    district_id uuid,
    country_id uuid NOT NULL,
    code character varying(30),
    name character varying(255) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    source_system character varying(100),
    external_id character varying(255),
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ref_post_offices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ref_post_offices (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    postal_code_id uuid NOT NULL,
    district_id uuid,
    name character varying(255) NOT NULL,
    address text,
    is_active boolean DEFAULT true NOT NULL,
    source_system character varying(100),
    external_id character varying(255),
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE ref_post_offices; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.ref_post_offices IS 'Postal offices/service points. Separate from postal-code master because office names are not settlement names and several offices may exist for one postal code or settlement.';


--
-- Name: COLUMN ref_post_offices.postal_code_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ref_post_offices.postal_code_id IS 'Postal code served by this office. The postal code itself may optionally be linked to a settlement through ref_postal_codes.city_id.';


--
-- Name: COLUMN ref_post_offices.district_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ref_post_offices.district_id IS 'Optional administrative district from the source data. Useful before or when settlement matching is incomplete.';


--
-- Name: COLUMN ref_post_offices.address; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ref_post_offices.address IS 'Source address of the postal office/service point.';


--
-- Name: ref_postal_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ref_postal_codes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    country_id uuid NOT NULL,
    city_id uuid,
    postal_code character varying(32) NOT NULL,
    name character varying(255),
    description text,
    is_active boolean DEFAULT true NOT NULL,
    source_system character varying(100),
    external_id character varying(255),
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE ref_postal_codes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.ref_postal_codes IS 'Postal-code master. One settlement may have multiple postal codes.';


--
-- Name: ref_units_of_measure; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ref_units_of_measure (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(30) NOT NULL,
    name_bg character varying(120) NOT NULL,
    name_en character varying(120),
    unit_kind character varying(30) DEFAULT 'other'::character varying NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    source_system character varying(100),
    external_id character varying(150),
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ref_units_of_measure_kind_check CHECK (((unit_kind)::text = ANY ((ARRAY['count'::character varying, 'mass'::character varying, 'volume'::character varying, 'length'::character varying, 'area'::character varying, 'time'::character varying, 'service'::character varying, 'package'::character varying, 'other'::character varying])::text[])))
);


--
-- Name: report_account_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.report_account_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    report_line_id uuid NOT NULL,
    master_account_id uuid,
    master_section_id uuid,
    metric_type character varying(30) NOT NULL,
    include_descendants boolean DEFAULT false NOT NULL,
    corresponding_master_account_id uuid,
    corresponding_section_id uuid,
    multiplier numeric(12,4) DEFAULT 1 NOT NULL,
    priority integer DEFAULT 100 NOT NULL,
    valid_from date,
    valid_to date,
    is_active boolean DEFAULT true NOT NULL,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT report_account_rules_metric_type_check CHECK (((metric_type)::text = ANY ((ARRAY['opening_debit'::character varying, 'opening_credit'::character varying, 'debit_turnover'::character varying, 'credit_turnover'::character varying, 'closing_debit'::character varying, 'closing_credit'::character varying])::text[])))
);


--
-- Name: report_definitions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.report_definitions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(100) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    default_date_basis character varying(20) DEFAULT 'posting_date'::character varying NOT NULL,
    allowed_date_bases jsonb DEFAULT '["posting_date"]'::jsonb NOT NULL,
    valid_from date,
    valid_to date,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT report_definitions_default_date_basis_check CHECK (((default_date_basis)::text = ANY ((ARRAY['posting_date'::character varying, 'document_date'::character varying, 'vat_period'::character varying])::text[])))
);


--
-- Name: report_lines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.report_lines (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    report_definition_id uuid NOT NULL,
    parent_id uuid,
    code character varying(100),
    name character varying(500) NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    line_type character varying(30) DEFAULT 'calculated'::character varying NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: report_rule_filters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.report_rule_filters (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    report_account_rule_id uuid NOT NULL,
    filter_type character varying(50) NOT NULL,
    dimension_id uuid,
    operator character varying(20) NOT NULL,
    value_ref_type character varying(100),
    value_ref_id uuid,
    excluded_master_account_id uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT report_rule_filters_operator_check CHECK (((operator)::text = ANY ((ARRAY['equals'::character varying, 'not_equals'::character varying, 'in'::character varying, 'not_in'::character varying, 'exists'::character varying])::text[])))
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
-- Name: settlement_allocations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.settlement_allocations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    settlement_id uuid NOT NULL,
    open_item_id uuid NOT NULL,
    journal_entry_line_id uuid,
    amount_currency numeric(20,4),
    amount_base_eur numeric(20,4) NOT NULL,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: settlements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.settlements (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    settlement_date date NOT NULL,
    settlement_type character varying(50) NOT NULL,
    journal_entry_id uuid,
    document_id uuid,
    description text,
    status character varying(20) DEFAULT 'active'::character varying NOT NULL,
    created_by uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT settlements_status_check CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'cancelled'::character varying])::text[])))
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
    CONSTRAINT user_permission_overrides_effect_check CHECK (((effect)::text = ANY ((ARRAY['allow'::character varying, 'deny'::character varying])::text[])))
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
-- Name: v_firm_item_alias_candidates; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_firm_item_alias_candidates AS
 SELECT a.id AS alias_id,
    a.firm_id,
    a.counterparty_id,
    a.firm_item_id,
    i.code AS firm_item_code,
    i.name AS firm_item_name,
    i.item_type,
    a.alias_text,
    a.normalized_alias,
    a.is_confirmed,
    a.alias_source,
    a.usage_count,
    a.last_used_at,
    a.last_match_confidence
   FROM (public.firm_item_aliases a
     JOIN public.firm_items i ON ((i.id = a.firm_item_id)))
  WHERE ((a.is_active = true) AND (i.is_active = true));


--
-- Name: vat_activity_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vat_activity_tags (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    vat_category character varying(50),
    supply_type character varying(50),
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: vat_article_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vat_article_groups (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    vat_activity_tag_id uuid,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: vat_articles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vat_articles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    vat_article_group_id uuid,
    article_text character varying(100) NOT NULL,
    article_number integer,
    article_suffix character varying(10),
    paragraph_number integer,
    description text,
    search_key character varying(100) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: vat_assessments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vat_assessments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    source_document_id uuid,
    protocol_document_id uuid,
    journal_entry_id uuid NOT NULL,
    vat_rule_id uuid,
    protocol_date date NOT NULL,
    tax_base_amount numeric(20,2) NOT NULL,
    vat_rate_percent numeric(9,6) NOT NULL,
    vat_amount numeric(20,2) NOT NULL,
    tax_credit_mode character varying(20) NOT NULL,
    input_claim_vat_period_id uuid,
    output_vat_term_id uuid,
    input_vat_term_id uuid,
    vies_type_id uuid,
    vat_special_regime_id uuid,
    vat_article_id uuid,
    status character varying(20) DEFAULT 'draft'::character varying NOT NULL,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT vat_assessments_distinct_documents_check CHECK (((source_document_id IS NULL) OR (protocol_document_id IS NULL) OR (source_document_id <> protocol_document_id))),
    CONSTRAINT vat_assessments_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'calculated'::character varying, 'posted'::character varying, 'cancelled'::character varying])::text[]))),
    CONSTRAINT vat_assessments_tax_base_check CHECK ((tax_base_amount >= (0)::numeric)),
    CONSTRAINT vat_assessments_tax_credit_mode_check CHECK (((tax_credit_mode)::text = ANY ((ARRAY['full'::character varying, 'partial'::character varying, 'none'::character varying, 'not_applicable'::character varying])::text[]))),
    CONSTRAINT vat_assessments_vat_amount_check CHECK ((vat_amount >= (0)::numeric)),
    CONSTRAINT vat_assessments_vat_rate_check CHECK (((vat_rate_percent >= (0)::numeric) AND (vat_rate_percent <= (100)::numeric)))
);


--
-- Name: TABLE vat_assessments; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.vat_assessments IS 'VAT self-assessment/protocol layer linked to one economic operation. Stores full tax base/VAT as historical fact. Reporting-period logic and partial-credit coefficients do not overwrite document VAT amounts.';


--
-- Name: COLUMN vat_assessments.protocol_date; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.vat_assessments.protocol_date IS 'Determines mandatory output/sales VAT period. The period is derived from protocol_date rather than independently stored, avoiding duplicate truth.';


--
-- Name: COLUMN vat_assessments.tax_credit_mode; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.vat_assessments.tax_credit_mode IS 'full = full Dr 4531/Cr 4532; partial = full Dr 4531/Cr 4532 and coefficient applied at VAT-period level; none = configured expense/cost Dr / Cr 4532 without artificial 4531; not_applicable = no input-credit side.';


--
-- Name: COLUMN vat_assessments.input_claim_vat_period_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.vat_assessments.input_claim_vat_period_id IS 'VAT period in which input tax credit is claimed in the purchase ledger. It may differ from the protocol month when law permits later exercise of the credit.';


--
-- Name: vat_b2c_destination_policies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vat_b2c_destination_policies (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    calendar_year integer NOT NULL,
    policy_scope character varying(40) DEFAULT 'EU_B2C_THRESHOLD'::character varying NOT NULL,
    destination_taxation_elected boolean DEFAULT false NOT NULL,
    election_valid_from date,
    election_valid_to date,
    reporting_route character varying(30) DEFAULT 'auto'::character varying NOT NULL,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT vat_b2c_destination_policies_dates_check CHECK (((election_valid_to IS NULL) OR (election_valid_from IS NULL) OR (election_valid_to >= election_valid_from))),
    CONSTRAINT vat_b2c_destination_policies_route_check CHECK (((reporting_route)::text = ANY ((ARRAY['auto'::character varying, 'oss_union'::character varying, 'local_registration'::character varying])::text[]))),
    CONSTRAINT vat_b2c_destination_policies_scope_check CHECK (((policy_scope)::text = 'EU_B2C_THRESHOLD'::text)),
    CONSTRAINT vat_b2c_destination_policies_year_check CHECK (((calendar_year >= 1900) AND (calendar_year <= 9999)))
);


--
-- Name: TABLE vat_b2c_destination_policies; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.vat_b2c_destination_policies IS 'Firm/year policy inputs for deciding HOME versus DESTINATION taxation of qualifying EU B2C distance-goods/TBE transactions. Actual turnover is derived from transactions.';


--
-- Name: vat_country_rate_applicability; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vat_country_rate_applicability (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    country_id uuid NOT NULL,
    vat_tax_category_id uuid NOT NULL,
    vat_rate_type_id uuid NOT NULL,
    valid_from date NOT NULL,
    valid_to date,
    is_active boolean DEFAULT true NOT NULL,
    legal_reference character varying(255),
    source_reference character varying(500),
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT vat_country_rate_app_dates_check CHECK (((valid_to IS NULL) OR (valid_to >= valid_from)))
);


--
-- Name: TABLE vat_country_rate_applicability; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.vat_country_rate_applicability IS 'Country- and date-specific mapping from a good/service tax category to the VAT rate type that must be resolved against vat_country_rates.';


--
-- Name: vat_country_rates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vat_country_rates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    country_id uuid NOT NULL,
    vat_rate_type_id uuid NOT NULL,
    local_rate_code character varying(80),
    rate_percent numeric(9,6) NOT NULL,
    valid_from date NOT NULL,
    valid_to date,
    is_default_for_type boolean DEFAULT true NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    legal_reference character varying(255),
    source_reference character varying(500),
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT vat_country_rates_dates_check CHECK (((valid_to IS NULL) OR (valid_to >= valid_from))),
    CONSTRAINT vat_country_rates_percent_check CHECK (((rate_percent >= (0)::numeric) AND (rate_percent <= (100)::numeric)))
);


--
-- Name: TABLE vat_country_rates; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.vat_country_rates IS 'Historically versioned VAT rates by country and rate type. Used by destination-country VAT resolution for OSS/local foreign VAT reporting.';


--
-- Name: vat_ledger_snapshot_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vat_ledger_snapshot_entries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    snapshot_id uuid NOT NULL,
    document_id uuid,
    counterparty_id uuid,
    document_number_snapshot character varying(255),
    document_date_snapshot date,
    counterparty_name_snapshot character varying(255),
    counterparty_vat_number_snapshot character varying(100),
    total_tax_base numeric(20,4),
    total_vat_amount numeric(20,4),
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: vat_ledger_snapshot_lines; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vat_ledger_snapshot_lines (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    snapshot_entry_id uuid NOT NULL,
    vat_term_id uuid NOT NULL,
    vat_article_id uuid,
    vies_type_id uuid,
    vat_special_regime_id uuid,
    tax_base_amount numeric(20,4) DEFAULT 0 NOT NULL,
    vat_amount numeric(20,4) DEFAULT 0 NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: vat_ledger_snapshots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vat_ledger_snapshots (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    vat_period_id uuid NOT NULL,
    version_no integer NOT NULL,
    snapshot_type character varying(20) DEFAULT 'generated'::character varying NOT NULL,
    is_current boolean DEFAULT true NOT NULL,
    generated_by uuid,
    generated_at timestamp with time zone DEFAULT now() NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT vat_ledger_snapshots_snapshot_type_check CHECK (((snapshot_type)::text = ANY ((ARRAY['generated'::character varying, 'final'::character varying, 'submitted'::character varying, 'corrected'::character varying])::text[])))
);


--
-- Name: vat_periods; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vat_periods (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    firm_id uuid NOT NULL,
    period_year integer NOT NULL,
    period_month integer NOT NULL,
    period_start date NOT NULL,
    period_end date NOT NULL,
    status character varying(20) DEFAULT 'open'::character varying NOT NULL,
    generated_at timestamp with time zone,
    finalized_at timestamp with time zone,
    submitted_at timestamp with time zone,
    created_by uuid,
    updated_by uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT vat_periods_period_month_check CHECK (((period_month >= 1) AND (period_month <= 12))),
    CONSTRAINT vat_periods_status_check CHECK (((status)::text = ANY ((ARRAY['open'::character varying, 'generated'::character varying, 'finalized'::character varying, 'submitted'::character varying, 'corrected'::character varying])::text[])))
);


--
-- Name: vat_rate_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vat_rate_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    sort_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE vat_rate_types; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.vat_rate_types IS 'Controlled vocabulary for VAT rate categories such as standard, reduced, super-reduced, zero and parking/intermediate rates.';


--
-- Name: vat_registration_compatibility; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vat_registration_compatibility (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    type_a_id uuid NOT NULL,
    type_b_id uuid NOT NULL,
    compatibility character varying(20) NOT NULL,
    legal_reference character varying(255),
    notes text,
    valid_from date DEFAULT '1900-01-01'::date NOT NULL,
    valid_to date,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT vat_registration_compatibility_canonical_pair_chk CHECK (((type_a_id)::text < (type_b_id)::text)),
    CONSTRAINT vat_registration_compatibility_distinct_types_chk CHECK ((type_a_id <> type_b_id)),
    CONSTRAINT vat_registration_compatibility_valid_period_chk CHECK (((valid_to IS NULL) OR (valid_to >= valid_from))),
    CONSTRAINT vat_registration_compatibility_value_chk CHECK (((compatibility)::text = ANY ((ARRAY['allowed'::character varying, 'prohibited'::character varying, 'conditional'::character varying])::text[])))
);


--
-- Name: TABLE vat_registration_compatibility; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.vat_registration_compatibility IS 'Versioned pairwise compatibility rules between VAT registration/regime types. Missing pair means not yet determined, not automatically allowed.';


--
-- Name: vat_registration_trigger_conditions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vat_registration_trigger_conditions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    trigger_rule_id uuid NOT NULL,
    vat_registration_type_id uuid NOT NULL,
    condition_mode character varying(20) NOT NULL,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT vat_registration_trigger_conditions_mode_check CHECK (((condition_mode)::text = ANY ((ARRAY['must_be_present'::character varying, 'must_be_absent'::character varying])::text[])))
);


--
-- Name: TABLE vat_registration_trigger_conditions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.vat_registration_trigger_conditions IS 'Registration-state conditions controlling when a compliance trigger applies. Example: ART_97A absent AND STANDARD absent.';


--
-- Name: vat_registration_trigger_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vat_registration_trigger_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(100) NOT NULL,
    name character varying(255) NOT NULL,
    transaction_scope character varying(20) NOT NULL,
    territory_scope character varying(30) NOT NULL,
    supply_type character varying(30) NOT NULL,
    counterparty_type character varying(20) NOT NULL,
    counterparty_vat_status character varying(30) DEFAULT 'any'::character varying NOT NULL,
    target_registration_type_id uuid NOT NULL,
    turnover_type_id uuid,
    trigger_mode character varying(30) NOT NULL,
    deadline_days_before integer,
    blocking_level character varying(20) DEFAULT 'block'::character varying NOT NULL,
    priority integer DEFAULT 100 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    legal_reference character varying(255),
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT vat_registration_trigger_blocking_check CHECK (((blocking_level)::text = ANY ((ARRAY['info'::character varying, 'warning'::character varying, 'block'::character varying])::text[]))),
    CONSTRAINT vat_registration_trigger_counterparty_type_check CHECK (((counterparty_type)::text = ANY ((ARRAY['b2b'::character varying, 'b2c'::character varying, 'any'::character varying])::text[]))),
    CONSTRAINT vat_registration_trigger_counterparty_vat_check CHECK (((counterparty_vat_status)::text = ANY ((ARRAY['valid_vat'::character varying, 'no_vat'::character varying, 'unknown'::character varying, 'any'::character varying])::text[]))),
    CONSTRAINT vat_registration_trigger_deadline_check CHECK (((deadline_days_before IS NULL) OR (deadline_days_before >= 0))),
    CONSTRAINT vat_registration_trigger_mode_check CHECK (((trigger_mode)::text = ANY ((ARRAY['before_transaction'::character varying, 'threshold_crossing'::character varying, 'immediate_review'::character varying])::text[]))),
    CONSTRAINT vat_registration_trigger_supply_check CHECK (((supply_type)::text = ANY ((ARRAY['goods'::character varying, 'service'::character varying, 'any'::character varying])::text[]))),
    CONSTRAINT vat_registration_trigger_territory_check CHECK (((territory_scope)::text = ANY ((ARRAY['BG'::character varying, 'EU_VAT'::character varying, 'EU_SPECIAL'::character varying, 'THIRD_COUNTRY'::character varying, 'all'::character varying])::text[]))),
    CONSTRAINT vat_registration_trigger_transaction_check CHECK (((transaction_scope)::text = ANY ((ARRAY['purchase'::character varying, 'sale'::character varying, 'both'::character varying])::text[])))
);


--
-- Name: TABLE vat_registration_trigger_rules; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.vat_registration_trigger_rules IS 'Compliance rules evaluated before VAT treatment. They identify missing registrations/regimes required by a planned or imported transaction.';


--
-- Name: vat_registration_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vat_registration_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(80) NOT NULL,
    name character varying(255) NOT NULL,
    category character varying(40) NOT NULL,
    description text,
    legal_reference character varying(255),
    valid_from date DEFAULT '1900-01-01'::date NOT NULL,
    valid_to date,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT vat_registration_types_category_chk CHECK (((category)::text = ANY ((ARRAY['BASE'::character varying, 'SME'::character varying, 'OSS_IOSS'::character varying, 'ADDITIONAL'::character varying])::text[]))),
    CONSTRAINT vat_registration_types_valid_period_chk CHECK (((valid_to IS NULL) OR (valid_to >= valid_from)))
);


--
-- Name: TABLE vat_registration_types; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.vat_registration_types IS 'Versioned master nomenclature of VAT registrations and additional VAT regimes.';


--
-- Name: vat_rule_registration_requirements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vat_rule_registration_requirements (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    vat_rule_id uuid NOT NULL,
    vat_registration_type_id uuid NOT NULL,
    requirement_mode character varying(20) NOT NULL,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT vat_rule_registration_requirements_mode_check CHECK (((requirement_mode)::text = ANY ((ARRAY['required'::character varying, 'prohibited'::character varying])::text[])))
);


--
-- Name: vat_rule_turnover_effects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vat_rule_turnover_effects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    vat_rule_id uuid NOT NULL,
    turnover_type_id uuid NOT NULL,
    effect character varying(20) NOT NULL,
    country_basis character varying(30) DEFAULT 'none'::character varying NOT NULL,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT vat_rule_turnover_effects_country_basis_check CHECK (((country_basis)::text = ANY ((ARRAY['none'::character varying, 'supplier_country'::character varying, 'customer_country'::character varying, 'destination_country'::character varying, 'place_of_supply_country'::character varying])::text[]))),
    CONSTRAINT vat_rule_turnover_effects_effect_check CHECK (((effect)::text = ANY ((ARRAY['included'::character varying, 'excluded'::character varying, 'conditional'::character varying])::text[])))
);


--
-- Name: vat_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vat_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    transaction_scope character varying(20) DEFAULT 'both'::character varying NOT NULL,
    territory_scope character varying(20) DEFAULT 'all'::character varying NOT NULL,
    vat_activity_tag_id uuid,
    vat_term_id uuid NOT NULL,
    vies_type_id uuid,
    vat_special_regime_id uuid,
    vat_article_id uuid,
    requires_protocol boolean DEFAULT false NOT NULL,
    allows_tax_credit boolean,
    priority integer DEFAULT 100 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    supply_type character varying(30) DEFAULT 'any'::character varying NOT NULL,
    counterparty_type character varying(20) DEFAULT 'any'::character varying NOT NULL,
    counterparty_vat_status character varying(30) DEFAULT 'any'::character varying NOT NULL,
    purchase_use character varying(30) DEFAULT 'any'::character varying NOT NULL,
    tax_credit_mode character varying(30) DEFAULT 'conditional'::character varying NOT NULL,
    output_vat_term_id uuid,
    input_vat_term_id uuid,
    vat_rate_resolution_mode character varying(30) DEFAULT 'term_default'::character varying NOT NULL,
    fixed_vat_rate_percent numeric(9,6),
    CONSTRAINT vat_rules_counterparty_type_check CHECK (((counterparty_type)::text = ANY ((ARRAY['b2b'::character varying, 'b2c'::character varying, 'any'::character varying])::text[]))),
    CONSTRAINT vat_rules_counterparty_vat_status_check CHECK (((counterparty_vat_status)::text = ANY ((ARRAY['valid_vat'::character varying, 'no_vat'::character varying, 'unknown'::character varying, 'any'::character varying])::text[]))),
    CONSTRAINT vat_rules_fixed_vat_rate_percent_check CHECK (((fixed_vat_rate_percent IS NULL) OR ((fixed_vat_rate_percent >= (0)::numeric) AND (fixed_vat_rate_percent <= (100)::numeric)))),
    CONSTRAINT vat_rules_fixed_vat_rate_required_check CHECK ((((vat_rate_resolution_mode)::text <> 'fixed'::text) OR (fixed_vat_rate_percent IS NOT NULL))),
    CONSTRAINT vat_rules_purchase_use_check CHECK (((purchase_use)::text = ANY ((ARRAY['taxable_only'::character varying, 'exempt_only'::character varying, 'mixed'::character varying, 'any'::character varying])::text[]))),
    CONSTRAINT vat_rules_supply_type_check CHECK (((supply_type)::text = ANY ((ARRAY['goods'::character varying, 'service'::character varying, 'any'::character varying])::text[]))),
    CONSTRAINT vat_rules_tax_credit_mode_check CHECK (((tax_credit_mode)::text = ANY ((ARRAY['full'::character varying, 'none'::character varying, 'partial'::character varying, 'conditional'::character varying, 'not_applicable'::character varying])::text[]))),
    CONSTRAINT vat_rules_territory_scope_check CHECK (((territory_scope)::text = ANY ((ARRAY['BG'::character varying, 'EU_VAT'::character varying, 'EU_SPECIAL'::character varying, 'THIRD_COUNTRY'::character varying, 'all'::character varying])::text[]))),
    CONSTRAINT vat_rules_transaction_scope_check CHECK (((transaction_scope)::text = ANY ((ARRAY['purchase'::character varying, 'sale'::character varying, 'both'::character varying])::text[]))),
    CONSTRAINT vat_rules_vat_rate_resolution_mode_check CHECK (((vat_rate_resolution_mode)::text = ANY ((ARRAY['none'::character varying, 'term_default'::character varying, 'domestic_equivalent'::character varying, 'destination_country'::character varying, 'fixed'::character varying])::text[])))
);


--
-- Name: COLUMN vat_rules.output_vat_term_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.vat_rules.output_vat_term_id IS 'VAT term used for the output/sales-ledger side of a VAT assessment/protocol.';


--
-- Name: COLUMN vat_rules.input_vat_term_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.vat_rules.input_vat_term_id IS 'VAT term used for the input/purchases-ledger side of a VAT assessment/protocol. May still exist when no credit is claimable, depending on statutory ledger presentation.';


--
-- Name: COLUMN vat_rules.vat_rate_resolution_mode; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.vat_rules.vat_rate_resolution_mode IS 'How the VAT assessment rate is resolved: none, term_default, domestic_equivalent, destination_country, fixed. Reverse-charge services normally use domestic_equivalent, not a blindly hardcoded 20%.';


--
-- Name: COLUMN vat_rules.fixed_vat_rate_percent; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.vat_rules.fixed_vat_rate_percent IS 'Explicit rate only when vat_rate_resolution_mode=fixed.';


--
-- Name: vat_special_regimes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vat_special_regimes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: vat_tax_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vat_tax_categories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(100) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    supply_type character varying(30) DEFAULT 'any'::character varying NOT NULL,
    parent_id uuid,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT vat_tax_categories_supply_type_check CHECK (((supply_type)::text = ANY ((ARRAY['goods'::character varying, 'service'::character varying, 'any'::character varying])::text[])))
);


--
-- Name: TABLE vat_tax_categories; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.vat_tax_categories IS 'Tax classification of goods/services used to determine the applicable VAT rate category. It is independent from accounting accounts and product identity.';


--
-- Name: vat_terms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vat_terms (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    transaction_type_id uuid NOT NULL,
    default_vies_type_id uuid,
    code character varying(20) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    ledger_position_no integer NOT NULL,
    default_vat_rate_percent numeric(5,2) DEFAULT 0 NOT NULL,
    is_reported_in_vat_ledger boolean DEFAULT true NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: vat_territories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vat_territories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    country_id uuid,
    code character varying(80) NOT NULL,
    name character varying(255) NOT NULL,
    territory_kind character varying(30) NOT NULL,
    eu_vat_rules_apply boolean NOT NULL,
    vies_applicable boolean DEFAULT false NOT NULL,
    goods_scope character varying(30) NOT NULL,
    services_scope character varying(30) NOT NULL,
    treated_as_country_id uuid,
    is_active boolean DEFAULT true NOT NULL,
    valid_from date DEFAULT '1900-01-01'::date NOT NULL,
    valid_to date,
    legal_reference character varying(255),
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT vat_territories_dates_check CHECK (((valid_to IS NULL) OR (valid_to >= valid_from))),
    CONSTRAINT vat_territories_goods_scope_check CHECK (((goods_scope)::text = ANY ((ARRAY['EU_VAT'::character varying, 'OUTSIDE_EU_VAT'::character varying, 'EU_VAT_GOODS_ONLY'::character varying, 'TREATED_AS_MEMBER_STATE'::character varying])::text[]))),
    CONSTRAINT vat_territories_kind_check CHECK (((territory_kind)::text = ANY ((ARRAY['EU_STANDARD'::character varying, 'EU_SPECIAL'::character varying, 'NON_EU_SPECIAL'::character varying])::text[]))),
    CONSTRAINT vat_territories_services_scope_check CHECK (((services_scope)::text = ANY ((ARRAY['EU_VAT'::character varying, 'OUTSIDE_EU_VAT'::character varying, 'TREATED_AS_MEMBER_STATE'::character varying])::text[])))
);


--
-- Name: vat_transaction_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vat_transaction_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: vat_turnover_override_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vat_turnover_override_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(120) NOT NULL,
    name character varying(255) NOT NULL,
    turnover_type_id uuid NOT NULL,
    effect character varying(20) NOT NULL,
    vat_category character varying(30),
    vat_activity_tag_id uuid,
    is_incidental boolean,
    priority integer DEFAULT 100 NOT NULL,
    valid_from date DEFAULT '1900-01-01'::date NOT NULL,
    valid_to date,
    is_active boolean DEFAULT true NOT NULL,
    legal_reference character varying(255),
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT vat_turnover_override_rules_dates_check CHECK (((valid_to IS NULL) OR (valid_to >= valid_from))),
    CONSTRAINT vat_turnover_override_rules_effect_check CHECK (((effect)::text = ANY ((ARRAY['included'::character varying, 'excluded'::character varying, 'conditional'::character varying])::text[]))),
    CONSTRAINT vat_turnover_override_rules_vat_category_check CHECK (((vat_category IS NULL) OR ((vat_category)::text = ANY ((ARRAY['taxable'::character varying, 'exempt'::character varying, 'mixed'::character varying, 'outside_scope'::character varying])::text[]))))
);


--
-- Name: TABLE vat_turnover_override_rules; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.vat_turnover_override_rules IS 'Higher-priority turnover effects applied from transaction context after the base vat_rule_turnover_effects result. Used for cross-cutting facts such as incidental/supplementary exempt transactions without duplicating every VAT rule.';


--
-- Name: COLUMN vat_turnover_override_rules.is_incidental; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.vat_turnover_override_rules.is_incidental IS 'Transaction-context condition. TRUE means this override applies only when the concrete supply is marked incidental/supplementary. NULL means any value.';


--
-- Name: vat_turnover_thresholds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vat_turnover_thresholds (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    turnover_type_id uuid NOT NULL,
    country_id uuid,
    threshold_amount numeric(20,2) NOT NULL,
    currency_id uuid NOT NULL,
    valid_from date NOT NULL,
    valid_to date,
    threshold_period character varying(30) DEFAULT 'calendar_year'::character varying NOT NULL,
    threshold_role character varying(30) DEFAULT 'registration'::character varying NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    legal_reference character varying(255),
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT vat_turnover_thresholds_dates_check CHECK (((valid_to IS NULL) OR (valid_to >= valid_from))),
    CONSTRAINT vat_turnover_thresholds_period_check CHECK (((threshold_period)::text = ANY ((ARRAY['transaction'::character varying, 'calendar_month'::character varying, 'calendar_quarter'::character varying, 'calendar_year'::character varying, 'rolling_period'::character varying])::text[]))),
    CONSTRAINT vat_turnover_thresholds_role_check CHECK (((threshold_role)::text = ANY ((ARRAY['registration'::character varying, 'scheme_eligibility'::character varying, 'place_of_supply'::character varying, 'warning'::character varying])::text[]))),
    CONSTRAINT vat_turnover_thresholds_threshold_amount_check CHECK ((threshold_amount >= (0)::numeric))
);


--
-- Name: vat_turnover_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vat_turnover_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(80) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    aggregation_scope character varying(30) NOT NULL,
    excludes_home_country boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT vat_turnover_types_aggregation_scope_check CHECK (((aggregation_scope)::text = ANY ((ARRAY['home_country'::character varying, 'per_country'::character varying, 'eu_total'::character varying, 'global'::character varying])::text[])))
);


--
-- Name: COLUMN vat_turnover_types.aggregation_scope; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.vat_turnover_types.aggregation_scope IS 'How turnover is aggregated: home_country, per_country, eu_total, global.';


--
-- Name: COLUMN vat_turnover_types.excludes_home_country; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.vat_turnover_types.excludes_home_country IS 'For EU-wide metrics, indicates that the firm home Member State is excluded from the aggregate.';


--
-- Name: vies_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vies_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_version bigint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: account_balance_transfer_suggestions account_balance_transfer_suggestions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_balance_transfer_suggestions
    ADD CONSTRAINT account_balance_transfer_suggestions_pkey PRIMARY KEY (id);


--
-- Name: account_dimension_rules account_dimension_rules_account_id_dimension_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_dimension_rules
    ADD CONSTRAINT account_dimension_rules_account_id_dimension_id_key UNIQUE (account_id, dimension_id);


--
-- Name: account_dimension_rules account_dimension_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_dimension_rules
    ADD CONSTRAINT account_dimension_rules_pkey PRIMARY KEY (id);


--
-- Name: account_sections account_sections_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_sections
    ADD CONSTRAINT account_sections_code_key UNIQUE (code);


--
-- Name: account_sections account_sections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_sections
    ADD CONSTRAINT account_sections_pkey PRIMARY KEY (id);


--
-- Name: account_semantic_types account_semantic_types_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_semantic_types
    ADD CONSTRAINT account_semantic_types_code_key UNIQUE (code);


--
-- Name: account_semantic_types account_semantic_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_semantic_types
    ADD CONSTRAINT account_semantic_types_pkey PRIMARY KEY (id);


--
-- Name: account_types account_types_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_types
    ADD CONSTRAINT account_types_code_key UNIQUE (code);


--
-- Name: account_types account_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_types
    ADD CONSTRAINT account_types_pkey PRIMARY KEY (id);


--
-- Name: accounting_periods accounting_periods_firm_id_period_year_period_month_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounting_periods
    ADD CONSTRAINT accounting_periods_firm_id_period_year_period_month_key UNIQUE (firm_id, period_year, period_month);


--
-- Name: accounting_periods accounting_periods_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounting_periods
    ADD CONSTRAINT accounting_periods_pkey PRIMARY KEY (id);


--
-- Name: activity_vat_tags activity_vat_tags_activity_code_id_vat_activity_tag_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_vat_tags
    ADD CONSTRAINT activity_vat_tags_activity_code_id_vat_activity_tag_id_key UNIQUE (activity_code_id, vat_activity_tag_id);


--
-- Name: activity_vat_tags activity_vat_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_vat_tags
    ADD CONSTRAINT activity_vat_tags_pkey PRIMARY KEY (id);


--
-- Name: addresses addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT addresses_pkey PRIMARY KEY (id);


--
-- Name: analytic_dimension_values analytic_dimension_values_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytic_dimension_values
    ADD CONSTRAINT analytic_dimension_values_pkey PRIMARY KEY (id);


--
-- Name: analytic_dimensions analytic_dimensions_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytic_dimensions
    ADD CONSTRAINT analytic_dimensions_code_key UNIQUE (code);


--
-- Name: analytic_dimensions analytic_dimensions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytic_dimensions
    ADD CONSTRAINT analytic_dimensions_pkey PRIMARY KEY (id);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- Name: chart_of_accounts chart_of_accounts_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chart_of_accounts
    ADD CONSTRAINT chart_of_accounts_code_key UNIQUE (code);


--
-- Name: chart_of_accounts chart_of_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chart_of_accounts
    ADD CONSTRAINT chart_of_accounts_pkey PRIMARY KEY (id);


--
-- Name: cost_centers cost_centers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cost_centers
    ADD CONSTRAINT cost_centers_pkey PRIMARY KEY (id);


--
-- Name: counterparties counterparties_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.counterparties
    ADD CONSTRAINT counterparties_pkey PRIMARY KEY (id);


--
-- Name: counterparty_addresses counterparty_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.counterparty_addresses
    ADD CONSTRAINT counterparty_addresses_pkey PRIMARY KEY (id);


--
-- Name: counterparty_bank_accounts counterparty_bank_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.counterparty_bank_accounts
    ADD CONSTRAINT counterparty_bank_accounts_pkey PRIMARY KEY (id);


--
-- Name: counterparty_role_assignments counterparty_role_assignments_counterparty_id_role_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.counterparty_role_assignments
    ADD CONSTRAINT counterparty_role_assignments_counterparty_id_role_id_key UNIQUE (counterparty_id, role_id);


--
-- Name: counterparty_role_assignments counterparty_role_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.counterparty_role_assignments
    ADD CONSTRAINT counterparty_role_assignments_pkey PRIMARY KEY (id);


--
-- Name: counterparty_roles counterparty_roles_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.counterparty_roles
    ADD CONSTRAINT counterparty_roles_code_key UNIQUE (code);


--
-- Name: counterparty_roles counterparty_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.counterparty_roles
    ADD CONSTRAINT counterparty_roles_pkey PRIMARY KEY (id);


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
-- Name: document_invoice_details document_invoice_details_document_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_invoice_details
    ADD CONSTRAINT document_invoice_details_document_id_key UNIQUE (document_id);


--
-- Name: document_invoice_details document_invoice_details_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_invoice_details
    ADD CONSTRAINT document_invoice_details_pkey PRIMARY KEY (id);


--
-- Name: document_line_journal_lines document_line_journal_lines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_line_journal_lines
    ADD CONSTRAINT document_line_journal_lines_pkey PRIMARY KEY (id);


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
-- Name: economic_activity_codes economic_activity_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economic_activity_codes
    ADD CONSTRAINT economic_activity_codes_pkey PRIMARY KEY (id);


--
-- Name: economic_activity_codes economic_activity_codes_version_id_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economic_activity_codes
    ADD CONSTRAINT economic_activity_codes_version_id_code_key UNIQUE (version_id, code);


--
-- Name: economic_activity_versions economic_activity_versions_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economic_activity_versions
    ADD CONSTRAINT economic_activity_versions_code_key UNIQUE (code);


--
-- Name: economic_activity_versions economic_activity_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economic_activity_versions
    ADD CONSTRAINT economic_activity_versions_pkey PRIMARY KEY (id);


--
-- Name: firm_account_dimension_bindings firm_account_dimension_bindings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_account_dimension_bindings
    ADD CONSTRAINT firm_account_dimension_bindings_pkey PRIMARY KEY (id);


--
-- Name: firm_account_dimension_rules firm_account_dimension_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_account_dimension_rules
    ADD CONSTRAINT firm_account_dimension_rules_pkey PRIMARY KEY (id);


--
-- Name: firm_account_transition_events firm_account_transition_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_account_transition_events
    ADD CONSTRAINT firm_account_transition_events_pkey PRIMARY KEY (id);


--
-- Name: firm_account_transition_sources firm_account_transition_sourc_transition_event_id_firm_acco_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_account_transition_sources
    ADD CONSTRAINT firm_account_transition_sourc_transition_event_id_firm_acco_key UNIQUE (transition_event_id, firm_account_id);


--
-- Name: firm_account_transition_sources firm_account_transition_sources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_account_transition_sources
    ADD CONSTRAINT firm_account_transition_sources_pkey PRIMARY KEY (id);


--
-- Name: firm_account_transition_targets firm_account_transition_targe_transition_event_id_firm_acco_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_account_transition_targets
    ADD CONSTRAINT firm_account_transition_targe_transition_event_id_firm_acco_key UNIQUE (transition_event_id, firm_account_id);


--
-- Name: firm_account_transition_targets firm_account_transition_targets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_account_transition_targets
    ADD CONSTRAINT firm_account_transition_targets_pkey PRIMARY KEY (id);


--
-- Name: firm_accounting_locks firm_accounting_locks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_accounting_locks
    ADD CONSTRAINT firm_accounting_locks_pkey PRIMARY KEY (id);


--
-- Name: firm_activities firm_activities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_activities
    ADD CONSTRAINT firm_activities_pkey PRIMARY KEY (id);


--
-- Name: firm_addresses firm_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_addresses
    ADD CONSTRAINT firm_addresses_pkey PRIMARY KEY (id);


--
-- Name: firm_bank_account_ledger_accounts firm_bank_account_ledger_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_bank_account_ledger_accounts
    ADD CONSTRAINT firm_bank_account_ledger_accounts_pkey PRIMARY KEY (id);


--
-- Name: firm_bank_accounts firm_bank_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_bank_accounts
    ADD CONSTRAINT firm_bank_accounts_pkey PRIMARY KEY (id);


--
-- Name: firm_chart_accounts firm_chart_accounts_firm_id_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_chart_accounts
    ADD CONSTRAINT firm_chart_accounts_firm_id_code_key UNIQUE (firm_id, code);


--
-- Name: firm_chart_accounts firm_chart_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_chart_accounts
    ADD CONSTRAINT firm_chart_accounts_pkey PRIMARY KEY (id);


--
-- Name: firm_counterparties firm_counterparties_firm_id_counterparty_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_counterparties
    ADD CONSTRAINT firm_counterparties_firm_id_counterparty_id_key UNIQUE (firm_id, counterparty_id);


--
-- Name: firm_counterparties firm_counterparties_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_counterparties
    ADD CONSTRAINT firm_counterparties_pkey PRIMARY KEY (id);


--
-- Name: firm_counterparty_accounts firm_counterparty_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_counterparty_accounts
    ADD CONSTRAINT firm_counterparty_accounts_pkey PRIMARY KEY (id);


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
-- Name: firm_foreign_vat_registrations firm_foreign_vat_registrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_foreign_vat_registrations
    ADD CONSTRAINT firm_foreign_vat_registrations_pkey PRIMARY KEY (id);


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
-- Name: firm_item_aliases firm_item_aliases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_item_aliases
    ADD CONSTRAINT firm_item_aliases_pkey PRIMARY KEY (id);


--
-- Name: firm_item_match_decisions firm_item_match_decisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_item_match_decisions
    ADD CONSTRAINT firm_item_match_decisions_pkey PRIMARY KEY (id);


--
-- Name: firm_items firm_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_items
    ADD CONSTRAINT firm_items_pkey PRIMARY KEY (id);


--
-- Name: firm_report_account_rules firm_report_account_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_report_account_rules
    ADD CONSTRAINT firm_report_account_rules_pkey PRIMARY KEY (id);


--
-- Name: firm_vat_credit_coefficients firm_vat_credit_coefficients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_vat_credit_coefficients
    ADD CONSTRAINT firm_vat_credit_coefficients_pkey PRIMARY KEY (id);


--
-- Name: firm_vat_credit_coefficients firm_vat_credit_coefficients_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_vat_credit_coefficients
    ADD CONSTRAINT firm_vat_credit_coefficients_unique UNIQUE (firm_id, applicable_year);


--
-- Name: firm_vat_registrations firm_vat_registrations_no_same_type_overlap; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_vat_registrations
    ADD CONSTRAINT firm_vat_registrations_no_same_type_overlap EXCLUDE USING gist (firm_id WITH =, vat_registration_type_id WITH =, daterange(valid_from,
CASE
    WHEN (valid_to IS NULL) THEN NULL::date
    ELSE (valid_to + 1)
END, '[)'::text) WITH &&);


--
-- Name: firm_vat_registrations firm_vat_registrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_vat_registrations
    ADD CONSTRAINT firm_vat_registrations_pkey PRIMARY KEY (id);


--
-- Name: firm_vat_rules firm_vat_rules_firm_id_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_vat_rules
    ADD CONSTRAINT firm_vat_rules_firm_id_code_key UNIQUE (firm_id, code);


--
-- Name: firm_vat_rules firm_vat_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_vat_rules
    ADD CONSTRAINT firm_vat_rules_pkey PRIMARY KEY (id);


--
-- Name: firm_vat_settings firm_vat_settings_firm_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_vat_settings
    ADD CONSTRAINT firm_vat_settings_firm_id_key UNIQUE (firm_id);


--
-- Name: firm_vat_settings firm_vat_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_vat_settings
    ADD CONSTRAINT firm_vat_settings_pkey PRIMARY KEY (id);


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
-- Name: import_batches import_batches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_batches
    ADD CONSTRAINT import_batches_pkey PRIMARY KEY (id);


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
-- Name: integration_outbox integration_outbox_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integration_outbox
    ADD CONSTRAINT integration_outbox_pkey PRIMARY KEY (id);


--
-- Name: journal_entries journal_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entries
    ADD CONSTRAINT journal_entries_pkey PRIMARY KEY (id);


--
-- Name: journal_entry_documents journal_entry_documents_journal_entry_id_document_id_relati_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entry_documents
    ADD CONSTRAINT journal_entry_documents_journal_entry_id_document_id_relati_key UNIQUE (journal_entry_id, document_id, relation_role);


--
-- Name: journal_entry_documents journal_entry_documents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entry_documents
    ADD CONSTRAINT journal_entry_documents_pkey PRIMARY KEY (id);


--
-- Name: journal_entry_lines journal_entry_lines_journal_entry_id_line_no_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entry_lines
    ADD CONSTRAINT journal_entry_lines_journal_entry_id_line_no_key UNIQUE (journal_entry_id, line_no);


--
-- Name: journal_entry_lines journal_entry_lines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entry_lines
    ADD CONSTRAINT journal_entry_lines_pkey PRIMARY KEY (id);


--
-- Name: journal_line_analytics journal_line_analytics_journal_entry_line_id_dimension_id_v_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_line_analytics
    ADD CONSTRAINT journal_line_analytics_journal_entry_line_id_dimension_id_v_key UNIQUE (journal_entry_line_id, dimension_id, value_ref_type, value_ref_id);


--
-- Name: journal_line_analytics journal_line_analytics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_line_analytics
    ADD CONSTRAINT journal_line_analytics_pkey PRIMARY KEY (id);


--
-- Name: normal_balance_sides normal_balance_sides_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.normal_balance_sides
    ADD CONSTRAINT normal_balance_sides_code_key UNIQUE (code);


--
-- Name: normal_balance_sides normal_balance_sides_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.normal_balance_sides
    ADD CONSTRAINT normal_balance_sides_pkey PRIMARY KEY (id);


--
-- Name: open_items open_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.open_items
    ADD CONSTRAINT open_items_pkey PRIMARY KEY (id);


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
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


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
-- Name: ref_districts ref_districts_country_id_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_districts
    ADD CONSTRAINT ref_districts_country_id_code_key UNIQUE (country_id, code);


--
-- Name: ref_districts ref_districts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_districts
    ADD CONSTRAINT ref_districts_pkey PRIMARY KEY (id);


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
-- Name: ref_municipalities ref_municipalities_country_id_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_municipalities
    ADD CONSTRAINT ref_municipalities_country_id_code_key UNIQUE (country_id, code);


--
-- Name: ref_municipalities ref_municipalities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_municipalities
    ADD CONSTRAINT ref_municipalities_pkey PRIMARY KEY (id);


--
-- Name: ref_post_offices ref_post_offices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_post_offices
    ADD CONSTRAINT ref_post_offices_pkey PRIMARY KEY (id);


--
-- Name: ref_postal_codes ref_postal_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_postal_codes
    ADD CONSTRAINT ref_postal_codes_pkey PRIMARY KEY (id);


--
-- Name: ref_units_of_measure ref_units_of_measure_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_units_of_measure
    ADD CONSTRAINT ref_units_of_measure_code_key UNIQUE (code);


--
-- Name: ref_units_of_measure ref_units_of_measure_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_units_of_measure
    ADD CONSTRAINT ref_units_of_measure_pkey PRIMARY KEY (id);


--
-- Name: report_account_rules report_account_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_account_rules
    ADD CONSTRAINT report_account_rules_pkey PRIMARY KEY (id);


--
-- Name: report_definitions report_definitions_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_definitions
    ADD CONSTRAINT report_definitions_code_key UNIQUE (code);


--
-- Name: report_definitions report_definitions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_definitions
    ADD CONSTRAINT report_definitions_pkey PRIMARY KEY (id);


--
-- Name: report_lines report_lines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_lines
    ADD CONSTRAINT report_lines_pkey PRIMARY KEY (id);


--
-- Name: report_rule_filters report_rule_filters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_rule_filters
    ADD CONSTRAINT report_rule_filters_pkey PRIMARY KEY (id);


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
-- Name: settlement_allocations settlement_allocations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settlement_allocations
    ADD CONSTRAINT settlement_allocations_pkey PRIMARY KEY (id);


--
-- Name: settlements settlements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settlements
    ADD CONSTRAINT settlements_pkey PRIMARY KEY (id);


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
-- Name: vat_activity_tags vat_activity_tags_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_activity_tags
    ADD CONSTRAINT vat_activity_tags_code_key UNIQUE (code);


--
-- Name: vat_activity_tags vat_activity_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_activity_tags
    ADD CONSTRAINT vat_activity_tags_pkey PRIMARY KEY (id);


--
-- Name: vat_article_groups vat_article_groups_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_article_groups
    ADD CONSTRAINT vat_article_groups_code_key UNIQUE (code);


--
-- Name: vat_article_groups vat_article_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_article_groups
    ADD CONSTRAINT vat_article_groups_pkey PRIMARY KEY (id);


--
-- Name: vat_articles vat_articles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_articles
    ADD CONSTRAINT vat_articles_pkey PRIMARY KEY (id);


--
-- Name: vat_assessments vat_assessments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_assessments
    ADD CONSTRAINT vat_assessments_pkey PRIMARY KEY (id);


--
-- Name: vat_b2c_destination_policies vat_b2c_destination_policies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_b2c_destination_policies
    ADD CONSTRAINT vat_b2c_destination_policies_pkey PRIMARY KEY (id);


--
-- Name: vat_b2c_destination_policies vat_b2c_destination_policies_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_b2c_destination_policies
    ADD CONSTRAINT vat_b2c_destination_policies_unique UNIQUE (firm_id, calendar_year, policy_scope);


--
-- Name: vat_country_rate_applicability vat_country_rate_app_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_country_rate_applicability
    ADD CONSTRAINT vat_country_rate_app_unique UNIQUE (country_id, vat_tax_category_id, valid_from);


--
-- Name: vat_country_rate_applicability vat_country_rate_applicability_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_country_rate_applicability
    ADD CONSTRAINT vat_country_rate_applicability_pkey PRIMARY KEY (id);


--
-- Name: vat_country_rates vat_country_rates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_country_rates
    ADD CONSTRAINT vat_country_rates_pkey PRIMARY KEY (id);


--
-- Name: vat_country_rates vat_country_rates_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_country_rates
    ADD CONSTRAINT vat_country_rates_unique UNIQUE (country_id, vat_rate_type_id, rate_percent, valid_from);


--
-- Name: vat_ledger_snapshot_entries vat_ledger_snapshot_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_ledger_snapshot_entries
    ADD CONSTRAINT vat_ledger_snapshot_entries_pkey PRIMARY KEY (id);


--
-- Name: vat_ledger_snapshot_lines vat_ledger_snapshot_lines_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_ledger_snapshot_lines
    ADD CONSTRAINT vat_ledger_snapshot_lines_pkey PRIMARY KEY (id);


--
-- Name: vat_ledger_snapshots vat_ledger_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_ledger_snapshots
    ADD CONSTRAINT vat_ledger_snapshots_pkey PRIMARY KEY (id);


--
-- Name: vat_ledger_snapshots vat_ledger_snapshots_vat_period_id_version_no_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_ledger_snapshots
    ADD CONSTRAINT vat_ledger_snapshots_vat_period_id_version_no_key UNIQUE (vat_period_id, version_no);


--
-- Name: vat_periods vat_periods_firm_id_period_year_period_month_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_periods
    ADD CONSTRAINT vat_periods_firm_id_period_year_period_month_key UNIQUE (firm_id, period_year, period_month);


--
-- Name: vat_periods vat_periods_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_periods
    ADD CONSTRAINT vat_periods_pkey PRIMARY KEY (id);


--
-- Name: vat_rate_types vat_rate_types_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_rate_types
    ADD CONSTRAINT vat_rate_types_code_key UNIQUE (code);


--
-- Name: vat_rate_types vat_rate_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_rate_types
    ADD CONSTRAINT vat_rate_types_pkey PRIMARY KEY (id);


--
-- Name: vat_registration_compatibility vat_registration_compatibility_no_overlap; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_registration_compatibility
    ADD CONSTRAINT vat_registration_compatibility_no_overlap EXCLUDE USING gist (type_a_id WITH =, type_b_id WITH =, daterange(valid_from,
CASE
    WHEN (valid_to IS NULL) THEN NULL::date
    ELSE (valid_to + 1)
END, '[)'::text) WITH &&);


--
-- Name: vat_registration_compatibility vat_registration_compatibility_pair_start_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_registration_compatibility
    ADD CONSTRAINT vat_registration_compatibility_pair_start_key UNIQUE (type_a_id, type_b_id, valid_from);


--
-- Name: vat_registration_compatibility vat_registration_compatibility_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_registration_compatibility
    ADD CONSTRAINT vat_registration_compatibility_pkey PRIMARY KEY (id);


--
-- Name: vat_registration_trigger_conditions vat_registration_trigger_conditions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_registration_trigger_conditions
    ADD CONSTRAINT vat_registration_trigger_conditions_pkey PRIMARY KEY (id);


--
-- Name: vat_registration_trigger_conditions vat_registration_trigger_conditions_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_registration_trigger_conditions
    ADD CONSTRAINT vat_registration_trigger_conditions_unique UNIQUE (trigger_rule_id, vat_registration_type_id);


--
-- Name: vat_registration_trigger_rules vat_registration_trigger_rules_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_registration_trigger_rules
    ADD CONSTRAINT vat_registration_trigger_rules_code_key UNIQUE (code);


--
-- Name: vat_registration_trigger_rules vat_registration_trigger_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_registration_trigger_rules
    ADD CONSTRAINT vat_registration_trigger_rules_pkey PRIMARY KEY (id);


--
-- Name: vat_registration_types vat_registration_types_code_valid_from_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_registration_types
    ADD CONSTRAINT vat_registration_types_code_valid_from_key UNIQUE (code, valid_from);


--
-- Name: vat_registration_types vat_registration_types_no_overlapping_versions; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_registration_types
    ADD CONSTRAINT vat_registration_types_no_overlapping_versions EXCLUDE USING gist (code WITH =, daterange(valid_from,
CASE
    WHEN (valid_to IS NULL) THEN NULL::date
    ELSE (valid_to + 1)
END, '[)'::text) WITH &&);


--
-- Name: vat_registration_types vat_registration_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_registration_types
    ADD CONSTRAINT vat_registration_types_pkey PRIMARY KEY (id);


--
-- Name: vat_rule_registration_requirements vat_rule_registration_requirements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_rule_registration_requirements
    ADD CONSTRAINT vat_rule_registration_requirements_pkey PRIMARY KEY (id);


--
-- Name: vat_rule_registration_requirements vat_rule_registration_requirements_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_rule_registration_requirements
    ADD CONSTRAINT vat_rule_registration_requirements_unique UNIQUE (vat_rule_id, vat_registration_type_id);


--
-- Name: vat_rule_turnover_effects vat_rule_turnover_effects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_rule_turnover_effects
    ADD CONSTRAINT vat_rule_turnover_effects_pkey PRIMARY KEY (id);


--
-- Name: vat_rule_turnover_effects vat_rule_turnover_effects_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_rule_turnover_effects
    ADD CONSTRAINT vat_rule_turnover_effects_unique UNIQUE (vat_rule_id, turnover_type_id);


--
-- Name: vat_rules vat_rules_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_rules
    ADD CONSTRAINT vat_rules_code_key UNIQUE (code);


--
-- Name: vat_rules vat_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_rules
    ADD CONSTRAINT vat_rules_pkey PRIMARY KEY (id);


--
-- Name: vat_special_regimes vat_special_regimes_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_special_regimes
    ADD CONSTRAINT vat_special_regimes_code_key UNIQUE (code);


--
-- Name: vat_special_regimes vat_special_regimes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_special_regimes
    ADD CONSTRAINT vat_special_regimes_pkey PRIMARY KEY (id);


--
-- Name: vat_tax_categories vat_tax_categories_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_tax_categories
    ADD CONSTRAINT vat_tax_categories_code_key UNIQUE (code);


--
-- Name: vat_tax_categories vat_tax_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_tax_categories
    ADD CONSTRAINT vat_tax_categories_pkey PRIMARY KEY (id);


--
-- Name: vat_terms vat_terms_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_terms
    ADD CONSTRAINT vat_terms_code_key UNIQUE (code);


--
-- Name: vat_terms vat_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_terms
    ADD CONSTRAINT vat_terms_pkey PRIMARY KEY (id);


--
-- Name: vat_territories vat_territories_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_territories
    ADD CONSTRAINT vat_territories_code_key UNIQUE (code);


--
-- Name: vat_territories vat_territories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_territories
    ADD CONSTRAINT vat_territories_pkey PRIMARY KEY (id);


--
-- Name: vat_transaction_types vat_transaction_types_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_transaction_types
    ADD CONSTRAINT vat_transaction_types_code_key UNIQUE (code);


--
-- Name: vat_transaction_types vat_transaction_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_transaction_types
    ADD CONSTRAINT vat_transaction_types_pkey PRIMARY KEY (id);


--
-- Name: vat_turnover_override_rules vat_turnover_override_rules_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_turnover_override_rules
    ADD CONSTRAINT vat_turnover_override_rules_code_key UNIQUE (code);


--
-- Name: vat_turnover_override_rules vat_turnover_override_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_turnover_override_rules
    ADD CONSTRAINT vat_turnover_override_rules_pkey PRIMARY KEY (id);


--
-- Name: vat_turnover_thresholds vat_turnover_thresholds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_turnover_thresholds
    ADD CONSTRAINT vat_turnover_thresholds_pkey PRIMARY KEY (id);


--
-- Name: vat_turnover_types vat_turnover_types_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_turnover_types
    ADD CONSTRAINT vat_turnover_types_code_key UNIQUE (code);


--
-- Name: vat_turnover_types vat_turnover_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_turnover_types
    ADD CONSTRAINT vat_turnover_types_pkey PRIMARY KEY (id);


--
-- Name: vies_types vies_types_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vies_types
    ADD CONSTRAINT vies_types_code_key UNIQUE (code);


--
-- Name: vies_types vies_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vies_types
    ADD CONSTRAINT vies_types_pkey PRIMARY KEY (id);


--
-- Name: idx_addresses_postal_code_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_addresses_postal_code_id ON public.addresses USING btree (postal_code_id) WHERE (postal_code_id IS NOT NULL);


--
-- Name: idx_audit_log_entity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_log_entity ON public.audit_log USING btree (entity_type, entity_id);


--
-- Name: idx_audit_log_firm_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_log_firm_date ON public.audit_log USING btree (firm_id, created_at);


--
-- Name: idx_document_lines_firm_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_document_lines_firm_item ON public.document_lines USING btree (firm_item_id) WHERE (firm_item_id IS NOT NULL);


--
-- Name: idx_document_lines_vat_tax_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_document_lines_vat_tax_category ON public.document_lines USING btree (vat_tax_category_id) WHERE (vat_tax_category_id IS NOT NULL);


--
-- Name: idx_documents_counterparty; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_documents_counterparty ON public.documents USING btree (primary_counterparty_id);


--
-- Name: idx_documents_firm_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_documents_firm_date ON public.documents USING btree (firm_id, document_date);


--
-- Name: idx_firm_foreign_vat_reg_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_firm_foreign_vat_reg_lookup ON public.firm_foreign_vat_registrations USING btree (firm_id, country_id, valid_from, valid_to) WHERE (is_active = true);


--
-- Name: idx_firm_item_aliases_item; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_firm_item_aliases_item ON public.firm_item_aliases USING btree (firm_item_id);


--
-- Name: idx_firm_item_aliases_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_firm_item_aliases_lookup ON public.firm_item_aliases USING btree (firm_id, counterparty_id, normalized_alias) WHERE (is_active = true);


--
-- Name: idx_firm_item_match_decisions_firm_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_firm_item_match_decisions_firm_date ON public.firm_item_match_decisions USING btree (firm_id, decided_at DESC);


--
-- Name: idx_firm_item_match_decisions_line; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_firm_item_match_decisions_line ON public.firm_item_match_decisions USING btree (document_line_id) WHERE (document_line_id IS NOT NULL);


--
-- Name: idx_firm_items_firm_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_firm_items_firm_name ON public.firm_items USING btree (firm_id, name);


--
-- Name: idx_firm_items_vat_tax_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_firm_items_vat_tax_category ON public.firm_items USING btree (vat_tax_category_id) WHERE (vat_tax_category_id IS NOT NULL);


--
-- Name: idx_firm_vat_registrations_profile; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_firm_vat_registrations_profile ON public.firm_vat_registrations USING btree (firm_id, valid_from, valid_to, vat_registration_type_id);


--
-- Name: idx_integration_outbox_firm_entity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_integration_outbox_firm_entity ON public.integration_outbox USING btree (firm_id, entity_type, entity_id);


--
-- Name: idx_integration_outbox_pending; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_integration_outbox_pending ON public.integration_outbox USING btree (processing_status, occurred_at);


--
-- Name: idx_journal_entries_firm_posting_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_journal_entries_firm_posting_date ON public.journal_entries USING btree (firm_id, posting_date);


--
-- Name: idx_journal_entries_source_reference; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_journal_entries_source_reference ON public.journal_entries USING btree (firm_id, source_reference) WHERE (source_reference IS NOT NULL);


--
-- Name: idx_journal_entry_lines_line_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_journal_entry_lines_line_role ON public.journal_entry_lines USING btree (journal_entry_id, line_role);


--
-- Name: idx_journal_entry_lines_vat_assessment; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_journal_entry_lines_vat_assessment ON public.journal_entry_lines USING btree (vat_assessment_id, line_role) WHERE (vat_assessment_id IS NOT NULL);


--
-- Name: idx_ref_banks_bic_swift; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ref_banks_bic_swift ON public.ref_banks USING btree (bic_swift) WHERE (bic_swift IS NOT NULL);


--
-- Name: idx_ref_banks_institution_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ref_banks_institution_type ON public.ref_banks USING btree (institution_type, is_active);


--
-- Name: idx_ref_post_offices_district_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ref_post_offices_district_id ON public.ref_post_offices USING btree (district_id) WHERE (district_id IS NOT NULL);


--
-- Name: idx_ref_post_offices_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ref_post_offices_name ON public.ref_post_offices USING btree (name);


--
-- Name: idx_ref_post_offices_postal_code_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ref_post_offices_postal_code_id ON public.ref_post_offices USING btree (postal_code_id);


--
-- Name: idx_ref_postal_codes_city; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ref_postal_codes_city ON public.ref_postal_codes USING btree (city_id, postal_code) WHERE (city_id IS NOT NULL);


--
-- Name: idx_ref_postal_codes_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ref_postal_codes_code ON public.ref_postal_codes USING btree (postal_code);


--
-- Name: idx_vat_assessments_firm_protocol_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vat_assessments_firm_protocol_date ON public.vat_assessments USING btree (firm_id, protocol_date);


--
-- Name: idx_vat_assessments_input_claim_period; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vat_assessments_input_claim_period ON public.vat_assessments USING btree (input_claim_vat_period_id) WHERE (input_claim_vat_period_id IS NOT NULL);


--
-- Name: idx_vat_assessments_journal_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vat_assessments_journal_entry ON public.vat_assessments USING btree (journal_entry_id);


--
-- Name: idx_vat_assessments_protocol_document; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vat_assessments_protocol_document ON public.vat_assessments USING btree (protocol_document_id) WHERE (protocol_document_id IS NOT NULL);


--
-- Name: idx_vat_assessments_source_document; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vat_assessments_source_document ON public.vat_assessments USING btree (source_document_id) WHERE (source_document_id IS NOT NULL);


--
-- Name: idx_vat_b2c_destination_policies_firm_year; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vat_b2c_destination_policies_firm_year ON public.vat_b2c_destination_policies USING btree (firm_id, calendar_year);


--
-- Name: idx_vat_country_rate_app_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vat_country_rate_app_lookup ON public.vat_country_rate_applicability USING btree (country_id, vat_tax_category_id, valid_from, valid_to) WHERE (is_active = true);


--
-- Name: idx_vat_country_rates_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vat_country_rates_lookup ON public.vat_country_rates USING btree (country_id, vat_rate_type_id, valid_from, valid_to) WHERE (is_active = true);


--
-- Name: idx_vat_registration_compatibility_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vat_registration_compatibility_lookup ON public.vat_registration_compatibility USING btree (type_a_id, type_b_id, valid_from, valid_to) WHERE (is_active = true);


--
-- Name: idx_vat_registration_trigger_conditions_rule; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vat_registration_trigger_conditions_rule ON public.vat_registration_trigger_conditions USING btree (trigger_rule_id);


--
-- Name: idx_vat_registration_trigger_rules_decision; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vat_registration_trigger_rules_decision ON public.vat_registration_trigger_rules USING btree (transaction_scope, territory_scope, supply_type, counterparty_type, counterparty_vat_status, priority) WHERE (is_active = true);


--
-- Name: idx_vat_registration_types_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vat_registration_types_lookup ON public.vat_registration_types USING btree (code, valid_from, valid_to) WHERE (is_active = true);


--
-- Name: idx_vat_rule_reg_req_rule; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vat_rule_reg_req_rule ON public.vat_rule_registration_requirements USING btree (vat_rule_id);


--
-- Name: idx_vat_rule_reg_req_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vat_rule_reg_req_type ON public.vat_rule_registration_requirements USING btree (vat_registration_type_id);


--
-- Name: idx_vat_rule_turnover_effects_rule; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vat_rule_turnover_effects_rule ON public.vat_rule_turnover_effects USING btree (vat_rule_id);


--
-- Name: idx_vat_rule_turnover_effects_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vat_rule_turnover_effects_type ON public.vat_rule_turnover_effects USING btree (turnover_type_id);


--
-- Name: idx_vat_rules_decision_dimensions; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vat_rules_decision_dimensions ON public.vat_rules USING btree (transaction_scope, territory_scope, supply_type, counterparty_type, counterparty_vat_status, purchase_use, priority) WHERE (is_active = true);


--
-- Name: idx_vat_rules_input_vat_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vat_rules_input_vat_term ON public.vat_rules USING btree (input_vat_term_id) WHERE (input_vat_term_id IS NOT NULL);


--
-- Name: idx_vat_rules_output_vat_term; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vat_rules_output_vat_term ON public.vat_rules USING btree (output_vat_term_id) WHERE (output_vat_term_id IS NOT NULL);


--
-- Name: idx_vat_tax_categories_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vat_tax_categories_parent ON public.vat_tax_categories USING btree (parent_id);


--
-- Name: idx_vat_territories_country; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vat_territories_country ON public.vat_territories USING btree (country_id) WHERE (country_id IS NOT NULL);


--
-- Name: idx_vat_territories_vies; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vat_territories_vies ON public.vat_territories USING btree (vies_applicable) WHERE (is_active = true);


--
-- Name: idx_vat_turnover_override_rules_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vat_turnover_override_rules_lookup ON public.vat_turnover_override_rules USING btree (turnover_type_id, vat_category, is_incidental, priority) WHERE (is_active = true);


--
-- Name: idx_vat_turnover_thresholds_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_vat_turnover_thresholds_lookup ON public.vat_turnover_thresholds USING btree (turnover_type_id, country_id, valid_from, valid_to) WHERE (is_active = true);


--
-- Name: uq_firm_bank_accounts_iban; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_firm_bank_accounts_iban ON public.firm_bank_accounts USING btree (firm_id, iban) WHERE (iban IS NOT NULL);


--
-- Name: uq_firms_registration_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_firms_registration_number ON public.firms USING btree (country_id, registration_number) WHERE (registration_number IS NOT NULL);


--
-- Name: uq_operating_units_firm_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_operating_units_firm_code ON public.operating_units USING btree (firm_id, code) WHERE (code IS NOT NULL);


--
-- Name: uq_ref_banks_bic; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_ref_banks_bic ON public.ref_banks USING btree (bic_swift) WHERE (bic_swift IS NOT NULL);


--
-- Name: uq_ref_cities_ekatte; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_ref_cities_ekatte ON public.ref_cities USING btree (ekatte) WHERE (ekatte IS NOT NULL);


--
-- Name: uq_ref_post_offices_source_external; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_ref_post_offices_source_external ON public.ref_post_offices USING btree (source_system, external_id) WHERE ((source_system IS NOT NULL) AND (external_id IS NOT NULL));


--
-- Name: uq_ref_postal_codes_country_city_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_ref_postal_codes_country_city_code ON public.ref_postal_codes USING btree (country_id, COALESCE(city_id, '00000000-0000-0000-0000-000000000000'::uuid), postal_code);


--
-- Name: ux_firm_item_aliases_counterparty; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_firm_item_aliases_counterparty ON public.firm_item_aliases USING btree (firm_id, counterparty_id, normalized_alias) WHERE ((counterparty_id IS NOT NULL) AND (is_active = true));


--
-- Name: ux_firm_item_aliases_generic; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_firm_item_aliases_generic ON public.firm_item_aliases USING btree (firm_id, normalized_alias) WHERE ((counterparty_id IS NULL) AND (is_active = true));


--
-- Name: ux_firm_items_firm_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_firm_items_firm_code ON public.firm_items USING btree (firm_id, code) WHERE (code IS NOT NULL);


--
-- Name: account_balance_transfer_suggestions trg_account_balance_transfer_suggestions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_account_balance_transfer_suggestions_set_updated_at BEFORE UPDATE ON public.account_balance_transfer_suggestions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: account_dimension_rules trg_account_dimension_rules_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_account_dimension_rules_set_updated_at BEFORE UPDATE ON public.account_dimension_rules FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: account_sections trg_account_sections_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_account_sections_set_updated_at BEFORE UPDATE ON public.account_sections FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: accounting_periods trg_accounting_periods_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_accounting_periods_set_updated_at BEFORE UPDATE ON public.accounting_periods FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: activity_vat_tags trg_activity_vat_tags_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_activity_vat_tags_set_updated_at BEFORE UPDATE ON public.activity_vat_tags FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: addresses trg_addresses_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_addresses_set_updated_at BEFORE UPDATE ON public.addresses FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: analytic_dimension_values trg_analytic_dimension_values_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_analytic_dimension_values_set_updated_at BEFORE UPDATE ON public.analytic_dimension_values FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: analytic_dimensions trg_analytic_dimensions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_analytic_dimensions_set_updated_at BEFORE UPDATE ON public.analytic_dimensions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: chart_of_accounts trg_chart_of_accounts_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_chart_of_accounts_set_updated_at BEFORE UPDATE ON public.chart_of_accounts FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: cost_centers trg_cost_centers_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_cost_centers_set_updated_at BEFORE UPDATE ON public.cost_centers FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: counterparties trg_counterparties_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_counterparties_set_updated_at BEFORE UPDATE ON public.counterparties FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: counterparty_addresses trg_counterparty_addresses_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_counterparty_addresses_set_updated_at BEFORE UPDATE ON public.counterparty_addresses FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: counterparty_bank_accounts trg_counterparty_bank_accounts_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_counterparty_bank_accounts_set_updated_at BEFORE UPDATE ON public.counterparty_bank_accounts FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: counterparty_role_assignments trg_counterparty_role_assignments_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_counterparty_role_assignments_set_updated_at BEFORE UPDATE ON public.counterparty_role_assignments FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: counterparty_roles trg_counterparty_roles_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_counterparty_roles_set_updated_at BEFORE UPDATE ON public.counterparty_roles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


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
-- Name: document_line_journal_lines trg_document_line_journal_lines_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_document_line_journal_lines_set_updated_at BEFORE UPDATE ON public.document_line_journal_lines FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


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
-- Name: economic_activity_codes trg_economic_activity_codes_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_economic_activity_codes_set_updated_at BEFORE UPDATE ON public.economic_activity_codes FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: economic_activity_versions trg_economic_activity_versions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_economic_activity_versions_set_updated_at BEFORE UPDATE ON public.economic_activity_versions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: firm_account_dimension_bindings trg_firm_account_dimension_bindings_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firm_account_dimension_bindings_set_updated_at BEFORE UPDATE ON public.firm_account_dimension_bindings FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: firm_account_dimension_rules trg_firm_account_dimension_rules_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firm_account_dimension_rules_set_updated_at BEFORE UPDATE ON public.firm_account_dimension_rules FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: firm_account_transition_events trg_firm_account_transition_events_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firm_account_transition_events_set_updated_at BEFORE UPDATE ON public.firm_account_transition_events FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: firm_accounting_locks trg_firm_accounting_locks_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firm_accounting_locks_set_updated_at BEFORE UPDATE ON public.firm_accounting_locks FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: firm_activities trg_firm_activities_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firm_activities_set_updated_at BEFORE UPDATE ON public.firm_activities FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: firm_addresses trg_firm_addresses_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firm_addresses_set_updated_at BEFORE UPDATE ON public.firm_addresses FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: firm_bank_account_ledger_accounts trg_firm_bank_account_ledger_accounts_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firm_bank_account_ledger_accounts_set_updated_at BEFORE UPDATE ON public.firm_bank_account_ledger_accounts FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: firm_bank_accounts trg_firm_bank_accounts_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firm_bank_accounts_set_updated_at BEFORE UPDATE ON public.firm_bank_accounts FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: firm_chart_accounts trg_firm_chart_accounts_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firm_chart_accounts_set_updated_at BEFORE UPDATE ON public.firm_chart_accounts FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: firm_counterparties trg_firm_counterparties_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firm_counterparties_set_updated_at BEFORE UPDATE ON public.firm_counterparties FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: firm_counterparty_accounts trg_firm_counterparty_accounts_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firm_counterparty_accounts_set_updated_at BEFORE UPDATE ON public.firm_counterparty_accounts FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: firm_document_types trg_firm_document_types_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firm_document_types_set_updated_at BEFORE UPDATE ON public.firm_document_types FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: firm_foreign_vat_registrations trg_firm_foreign_vat_registrations_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firm_foreign_vat_registrations_set_updated_at BEFORE UPDATE ON public.firm_foreign_vat_registrations FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


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
-- Name: firm_item_aliases trg_firm_item_aliases_normalize; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firm_item_aliases_normalize BEFORE INSERT OR UPDATE OF alias_text ON public.firm_item_aliases FOR EACH ROW EXECUTE FUNCTION public.trg_normalize_firm_item_alias();


--
-- Name: firm_item_aliases trg_firm_item_aliases_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firm_item_aliases_set_updated_at BEFORE UPDATE ON public.firm_item_aliases FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: firm_item_match_decisions trg_firm_item_match_decisions_normalize; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firm_item_match_decisions_normalize BEFORE INSERT OR UPDATE OF source_text ON public.firm_item_match_decisions FOR EACH ROW EXECUTE FUNCTION public.trg_normalize_firm_item_match_source();


--
-- Name: firm_item_match_decisions trg_firm_item_match_decisions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firm_item_match_decisions_set_updated_at BEFORE UPDATE ON public.firm_item_match_decisions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: firm_items trg_firm_items_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firm_items_set_updated_at BEFORE UPDATE ON public.firm_items FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: firm_report_account_rules trg_firm_report_account_rules_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firm_report_account_rules_set_updated_at BEFORE UPDATE ON public.firm_report_account_rules FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: firm_vat_credit_coefficients trg_firm_vat_credit_coefficients_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firm_vat_credit_coefficients_set_updated_at BEFORE UPDATE ON public.firm_vat_credit_coefficients FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: firm_vat_registrations trg_firm_vat_registrations_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firm_vat_registrations_set_updated_at BEFORE UPDATE ON public.firm_vat_registrations FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: firm_vat_rules trg_firm_vat_rules_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firm_vat_rules_set_updated_at BEFORE UPDATE ON public.firm_vat_rules FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: firm_vat_settings trg_firm_vat_settings_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firm_vat_settings_set_updated_at BEFORE UPDATE ON public.firm_vat_settings FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: firms trg_firms_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_firms_set_updated_at BEFORE UPDATE ON public.firms FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: import_batches trg_import_batches_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_import_batches_set_updated_at BEFORE UPDATE ON public.import_batches FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


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
-- Name: journal_entries trg_journal_entries_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_journal_entries_set_updated_at BEFORE UPDATE ON public.journal_entries FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: journal_entry_documents trg_journal_entry_documents_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_journal_entry_documents_set_updated_at BEFORE UPDATE ON public.journal_entry_documents FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: journal_entry_lines trg_journal_entry_lines_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_journal_entry_lines_set_updated_at BEFORE UPDATE ON public.journal_entry_lines FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: journal_line_analytics trg_journal_line_analytics_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_journal_line_analytics_set_updated_at BEFORE UPDATE ON public.journal_line_analytics FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: open_items trg_open_items_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_open_items_set_updated_at BEFORE UPDATE ON public.open_items FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: operating_unit_sales_points trg_operating_unit_sales_points_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_operating_unit_sales_points_set_updated_at BEFORE UPDATE ON public.operating_unit_sales_points FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: operating_units trg_operating_units_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_operating_units_set_updated_at BEFORE UPDATE ON public.operating_units FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: permission_resource_scopes trg_permission_resource_scopes_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_permission_resource_scopes_set_updated_at BEFORE UPDATE ON public.permission_resource_scopes FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: permissions trg_permissions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_permissions_set_updated_at BEFORE UPDATE ON public.permissions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: projects trg_projects_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_projects_set_updated_at BEFORE UPDATE ON public.projects FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: ref_banks trg_ref_banks_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ref_banks_set_updated_at BEFORE UPDATE ON public.ref_banks FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: ref_cities trg_ref_cities_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ref_cities_set_updated_at BEFORE UPDATE ON public.ref_cities FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: ref_countries trg_ref_countries_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ref_countries_set_updated_at BEFORE UPDATE ON public.ref_countries FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: ref_currencies trg_ref_currencies_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ref_currencies_set_updated_at BEFORE UPDATE ON public.ref_currencies FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: ref_districts trg_ref_districts_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ref_districts_set_updated_at BEFORE UPDATE ON public.ref_districts FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: ref_languages trg_ref_languages_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ref_languages_set_updated_at BEFORE UPDATE ON public.ref_languages FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: ref_legal_forms trg_ref_legal_forms_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ref_legal_forms_set_updated_at BEFORE UPDATE ON public.ref_legal_forms FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: ref_municipalities trg_ref_municipalities_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ref_municipalities_set_updated_at BEFORE UPDATE ON public.ref_municipalities FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: ref_post_offices trg_ref_post_offices_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ref_post_offices_set_updated_at BEFORE UPDATE ON public.ref_post_offices FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: ref_postal_codes trg_ref_postal_codes_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ref_postal_codes_set_updated_at BEFORE UPDATE ON public.ref_postal_codes FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: ref_units_of_measure trg_ref_units_of_measure_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ref_units_of_measure_set_updated_at BEFORE UPDATE ON public.ref_units_of_measure FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: report_account_rules trg_report_account_rules_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_report_account_rules_set_updated_at BEFORE UPDATE ON public.report_account_rules FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: report_definitions trg_report_definitions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_report_definitions_set_updated_at BEFORE UPDATE ON public.report_definitions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: report_lines trg_report_lines_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_report_lines_set_updated_at BEFORE UPDATE ON public.report_lines FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: report_rule_filters trg_report_rule_filters_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_report_rule_filters_set_updated_at BEFORE UPDATE ON public.report_rule_filters FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: role_permissions trg_role_permissions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_role_permissions_set_updated_at BEFORE UPDATE ON public.role_permissions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: roles trg_roles_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_roles_set_updated_at BEFORE UPDATE ON public.roles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: settlement_allocations trg_settlement_allocations_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_settlement_allocations_set_updated_at BEFORE UPDATE ON public.settlement_allocations FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: settlements trg_settlements_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_settlements_set_updated_at BEFORE UPDATE ON public.settlements FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


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
-- Name: vat_activity_tags trg_vat_activity_tags_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_vat_activity_tags_set_updated_at BEFORE UPDATE ON public.vat_activity_tags FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: vat_article_groups trg_vat_article_groups_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_vat_article_groups_set_updated_at BEFORE UPDATE ON public.vat_article_groups FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: vat_articles trg_vat_articles_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_vat_articles_set_updated_at BEFORE UPDATE ON public.vat_articles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: vat_assessments trg_vat_assessments_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_vat_assessments_set_updated_at BEFORE UPDATE ON public.vat_assessments FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: vat_b2c_destination_policies trg_vat_b2c_destination_policies_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_vat_b2c_destination_policies_set_updated_at BEFORE UPDATE ON public.vat_b2c_destination_policies FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: vat_country_rate_applicability trg_vat_country_rate_app_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_vat_country_rate_app_set_updated_at BEFORE UPDATE ON public.vat_country_rate_applicability FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: vat_country_rates trg_vat_country_rates_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_vat_country_rates_set_updated_at BEFORE UPDATE ON public.vat_country_rates FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: vat_periods trg_vat_periods_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_vat_periods_set_updated_at BEFORE UPDATE ON public.vat_periods FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: vat_rate_types trg_vat_rate_types_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_vat_rate_types_set_updated_at BEFORE UPDATE ON public.vat_rate_types FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: vat_registration_compatibility trg_vat_registration_compatibility_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_vat_registration_compatibility_set_updated_at BEFORE UPDATE ON public.vat_registration_compatibility FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: vat_registration_trigger_conditions trg_vat_registration_trigger_conditions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_vat_registration_trigger_conditions_set_updated_at BEFORE UPDATE ON public.vat_registration_trigger_conditions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: vat_registration_trigger_rules trg_vat_registration_trigger_rules_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_vat_registration_trigger_rules_set_updated_at BEFORE UPDATE ON public.vat_registration_trigger_rules FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: vat_registration_types trg_vat_registration_types_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_vat_registration_types_set_updated_at BEFORE UPDATE ON public.vat_registration_types FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: vat_rule_registration_requirements trg_vat_rule_registration_requirements_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_vat_rule_registration_requirements_set_updated_at BEFORE UPDATE ON public.vat_rule_registration_requirements FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: vat_rule_turnover_effects trg_vat_rule_turnover_effects_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_vat_rule_turnover_effects_set_updated_at BEFORE UPDATE ON public.vat_rule_turnover_effects FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: vat_rules trg_vat_rules_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_vat_rules_set_updated_at BEFORE UPDATE ON public.vat_rules FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: vat_special_regimes trg_vat_special_regimes_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_vat_special_regimes_set_updated_at BEFORE UPDATE ON public.vat_special_regimes FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: vat_tax_categories trg_vat_tax_categories_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_vat_tax_categories_set_updated_at BEFORE UPDATE ON public.vat_tax_categories FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: vat_terms trg_vat_terms_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_vat_terms_set_updated_at BEFORE UPDATE ON public.vat_terms FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: vat_territories trg_vat_territories_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_vat_territories_set_updated_at BEFORE UPDATE ON public.vat_territories FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: vat_transaction_types trg_vat_transaction_types_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_vat_transaction_types_set_updated_at BEFORE UPDATE ON public.vat_transaction_types FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: vat_turnover_override_rules trg_vat_turnover_override_rules_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_vat_turnover_override_rules_set_updated_at BEFORE UPDATE ON public.vat_turnover_override_rules FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: vat_turnover_thresholds trg_vat_turnover_thresholds_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_vat_turnover_thresholds_set_updated_at BEFORE UPDATE ON public.vat_turnover_thresholds FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: vat_turnover_types trg_vat_turnover_types_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_vat_turnover_types_set_updated_at BEFORE UPDATE ON public.vat_turnover_types FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: vies_types trg_vies_types_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_vies_types_set_updated_at BEFORE UPDATE ON public.vies_types FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_and_row_version();


--
-- Name: account_balance_transfer_suggestions account_balance_transfer_suggestions_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_balance_transfer_suggestions
    ADD CONSTRAINT account_balance_transfer_suggestions_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES public.ref_currencies(id);


--
-- Name: account_balance_transfer_suggestions account_balance_transfer_suggestions_decided_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_balance_transfer_suggestions
    ADD CONSTRAINT account_balance_transfer_suggestions_decided_by_fkey FOREIGN KEY (decided_by) REFERENCES public.users(id);


--
-- Name: account_balance_transfer_suggestions account_balance_transfer_suggestions_journal_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_balance_transfer_suggestions
    ADD CONSTRAINT account_balance_transfer_suggestions_journal_entry_id_fkey FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id);


--
-- Name: account_balance_transfer_suggestions account_balance_transfer_suggestions_source_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_balance_transfer_suggestions
    ADD CONSTRAINT account_balance_transfer_suggestions_source_account_id_fkey FOREIGN KEY (source_account_id) REFERENCES public.firm_chart_accounts(id);


--
-- Name: account_balance_transfer_suggestions account_balance_transfer_suggestions_target_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_balance_transfer_suggestions
    ADD CONSTRAINT account_balance_transfer_suggestions_target_account_id_fkey FOREIGN KEY (target_account_id) REFERENCES public.firm_chart_accounts(id);


--
-- Name: account_balance_transfer_suggestions account_balance_transfer_suggestions_transition_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_balance_transfer_suggestions
    ADD CONSTRAINT account_balance_transfer_suggestions_transition_event_id_fkey FOREIGN KEY (transition_event_id) REFERENCES public.firm_account_transition_events(id);


--
-- Name: account_dimension_rules account_dimension_rules_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_dimension_rules
    ADD CONSTRAINT account_dimension_rules_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.chart_of_accounts(id);


--
-- Name: account_dimension_rules account_dimension_rules_dimension_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_dimension_rules
    ADD CONSTRAINT account_dimension_rules_dimension_id_fkey FOREIGN KEY (dimension_id) REFERENCES public.analytic_dimensions(id);


--
-- Name: account_sections account_sections_default_account_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_sections
    ADD CONSTRAINT account_sections_default_account_type_id_fkey FOREIGN KEY (default_account_type_id) REFERENCES public.account_types(id);


--
-- Name: account_sections account_sections_default_normal_balance_side_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_sections
    ADD CONSTRAINT account_sections_default_normal_balance_side_id_fkey FOREIGN KEY (default_normal_balance_side_id) REFERENCES public.normal_balance_sides(id);


--
-- Name: account_sections account_sections_default_semantic_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_sections
    ADD CONSTRAINT account_sections_default_semantic_type_id_fkey FOREIGN KEY (default_semantic_type_id) REFERENCES public.account_semantic_types(id);


--
-- Name: account_sections account_sections_parent_section_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_sections
    ADD CONSTRAINT account_sections_parent_section_id_fkey FOREIGN KEY (parent_section_id) REFERENCES public.account_sections(id);


--
-- Name: accounting_periods accounting_periods_closed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounting_periods
    ADD CONSTRAINT accounting_periods_closed_by_fkey FOREIGN KEY (closed_by) REFERENCES public.users(id);


--
-- Name: accounting_periods accounting_periods_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounting_periods
    ADD CONSTRAINT accounting_periods_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: accounting_periods accounting_periods_locked_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounting_periods
    ADD CONSTRAINT accounting_periods_locked_by_fkey FOREIGN KEY (locked_by) REFERENCES public.users(id);


--
-- Name: activity_vat_tags activity_vat_tags_activity_code_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_vat_tags
    ADD CONSTRAINT activity_vat_tags_activity_code_id_fkey FOREIGN KEY (activity_code_id) REFERENCES public.economic_activity_codes(id);


--
-- Name: activity_vat_tags activity_vat_tags_vat_activity_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_vat_tags
    ADD CONSTRAINT activity_vat_tags_vat_activity_tag_id_fkey FOREIGN KEY (vat_activity_tag_id) REFERENCES public.vat_activity_tags(id);


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
-- Name: analytic_dimension_values analytic_dimension_values_dimension_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytic_dimension_values
    ADD CONSTRAINT analytic_dimension_values_dimension_id_fkey FOREIGN KEY (dimension_id) REFERENCES public.analytic_dimensions(id);


--
-- Name: analytic_dimension_values analytic_dimension_values_firm_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytic_dimension_values
    ADD CONSTRAINT analytic_dimension_values_firm_group_id_fkey FOREIGN KEY (firm_group_id) REFERENCES public.firm_groups(id);


--
-- Name: analytic_dimension_values analytic_dimension_values_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytic_dimension_values
    ADD CONSTRAINT analytic_dimension_values_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: analytic_dimension_values analytic_dimension_values_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytic_dimension_values
    ADD CONSTRAINT analytic_dimension_values_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.analytic_dimension_values(id);


--
-- Name: chart_of_accounts chart_of_accounts_account_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chart_of_accounts
    ADD CONSTRAINT chart_of_accounts_account_type_id_fkey FOREIGN KEY (account_type_id) REFERENCES public.account_types(id);


--
-- Name: chart_of_accounts chart_of_accounts_normal_balance_side_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chart_of_accounts
    ADD CONSTRAINT chart_of_accounts_normal_balance_side_id_fkey FOREIGN KEY (normal_balance_side_id) REFERENCES public.normal_balance_sides(id);


--
-- Name: chart_of_accounts chart_of_accounts_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chart_of_accounts
    ADD CONSTRAINT chart_of_accounts_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.chart_of_accounts(id);


--
-- Name: chart_of_accounts chart_of_accounts_section_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chart_of_accounts
    ADD CONSTRAINT chart_of_accounts_section_id_fkey FOREIGN KEY (section_id) REFERENCES public.account_sections(id);


--
-- Name: chart_of_accounts chart_of_accounts_semantic_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chart_of_accounts
    ADD CONSTRAINT chart_of_accounts_semantic_type_id_fkey FOREIGN KEY (semantic_type_id) REFERENCES public.account_semantic_types(id);


--
-- Name: cost_centers cost_centers_firm_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cost_centers
    ADD CONSTRAINT cost_centers_firm_group_id_fkey FOREIGN KEY (firm_group_id) REFERENCES public.firm_groups(id);


--
-- Name: cost_centers cost_centers_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cost_centers
    ADD CONSTRAINT cost_centers_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: cost_centers cost_centers_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cost_centers
    ADD CONSTRAINT cost_centers_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.cost_centers(id);


--
-- Name: counterparties counterparties_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.counterparties
    ADD CONSTRAINT counterparties_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.ref_countries(id);


--
-- Name: counterparty_addresses counterparty_addresses_address_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.counterparty_addresses
    ADD CONSTRAINT counterparty_addresses_address_id_fkey FOREIGN KEY (address_id) REFERENCES public.addresses(id);


--
-- Name: counterparty_addresses counterparty_addresses_counterparty_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.counterparty_addresses
    ADD CONSTRAINT counterparty_addresses_counterparty_id_fkey FOREIGN KEY (counterparty_id) REFERENCES public.counterparties(id);


--
-- Name: counterparty_bank_accounts counterparty_bank_accounts_bank_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.counterparty_bank_accounts
    ADD CONSTRAINT counterparty_bank_accounts_bank_id_fkey FOREIGN KEY (bank_id) REFERENCES public.ref_banks(id);


--
-- Name: counterparty_bank_accounts counterparty_bank_accounts_counterparty_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.counterparty_bank_accounts
    ADD CONSTRAINT counterparty_bank_accounts_counterparty_id_fkey FOREIGN KEY (counterparty_id) REFERENCES public.counterparties(id);


--
-- Name: counterparty_bank_accounts counterparty_bank_accounts_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.counterparty_bank_accounts
    ADD CONSTRAINT counterparty_bank_accounts_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES public.ref_currencies(id);


--
-- Name: counterparty_role_assignments counterparty_role_assignments_counterparty_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.counterparty_role_assignments
    ADD CONSTRAINT counterparty_role_assignments_counterparty_id_fkey FOREIGN KEY (counterparty_id) REFERENCES public.counterparties(id);


--
-- Name: counterparty_role_assignments counterparty_role_assignments_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.counterparty_role_assignments
    ADD CONSTRAINT counterparty_role_assignments_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.counterparty_roles(id);


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
-- Name: document_line_journal_lines document_line_journal_lines_document_line_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_line_journal_lines
    ADD CONSTRAINT document_line_journal_lines_document_line_id_fkey FOREIGN KEY (document_line_id) REFERENCES public.document_lines(id);


--
-- Name: document_line_journal_lines document_line_journal_lines_journal_entry_line_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_line_journal_lines
    ADD CONSTRAINT document_line_journal_lines_journal_entry_line_id_fkey FOREIGN KEY (journal_entry_line_id) REFERENCES public.journal_entry_lines(id);


--
-- Name: document_lines document_lines_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_lines
    ADD CONSTRAINT document_lines_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.documents(id);


--
-- Name: document_lines document_lines_firm_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_lines
    ADD CONSTRAINT document_lines_firm_item_id_fkey FOREIGN KEY (firm_item_id) REFERENCES public.firm_items(id);


--
-- Name: document_lines document_lines_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_lines
    ADD CONSTRAINT document_lines_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.ref_units_of_measure(id);


--
-- Name: document_lines document_lines_vat_tax_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_lines
    ADD CONSTRAINT document_lines_vat_tax_category_id_fkey FOREIGN KEY (vat_tax_category_id) REFERENCES public.vat_tax_categories(id);


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
-- Name: economic_activity_codes economic_activity_codes_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economic_activity_codes
    ADD CONSTRAINT economic_activity_codes_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.economic_activity_codes(id);


--
-- Name: economic_activity_codes economic_activity_codes_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.economic_activity_codes
    ADD CONSTRAINT economic_activity_codes_version_id_fkey FOREIGN KEY (version_id) REFERENCES public.economic_activity_versions(id);


--
-- Name: firm_account_dimension_bindings firm_account_dimension_bindings_dimension_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_account_dimension_bindings
    ADD CONSTRAINT firm_account_dimension_bindings_dimension_id_fkey FOREIGN KEY (dimension_id) REFERENCES public.analytic_dimensions(id);


--
-- Name: firm_account_dimension_bindings firm_account_dimension_bindings_firm_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_account_dimension_bindings
    ADD CONSTRAINT firm_account_dimension_bindings_firm_account_id_fkey FOREIGN KEY (firm_account_id) REFERENCES public.firm_chart_accounts(id);


--
-- Name: firm_account_dimension_rules firm_account_dimension_rules_dimension_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_account_dimension_rules
    ADD CONSTRAINT firm_account_dimension_rules_dimension_id_fkey FOREIGN KEY (dimension_id) REFERENCES public.analytic_dimensions(id);


--
-- Name: firm_account_dimension_rules firm_account_dimension_rules_firm_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_account_dimension_rules
    ADD CONSTRAINT firm_account_dimension_rules_firm_account_id_fkey FOREIGN KEY (firm_account_id) REFERENCES public.firm_chart_accounts(id);


--
-- Name: firm_account_transition_events firm_account_transition_events_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_account_transition_events
    ADD CONSTRAINT firm_account_transition_events_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: firm_account_transition_events firm_account_transition_events_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_account_transition_events
    ADD CONSTRAINT firm_account_transition_events_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: firm_account_transition_sources firm_account_transition_sources_firm_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_account_transition_sources
    ADD CONSTRAINT firm_account_transition_sources_firm_account_id_fkey FOREIGN KEY (firm_account_id) REFERENCES public.firm_chart_accounts(id);


--
-- Name: firm_account_transition_sources firm_account_transition_sources_transition_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_account_transition_sources
    ADD CONSTRAINT firm_account_transition_sources_transition_event_id_fkey FOREIGN KEY (transition_event_id) REFERENCES public.firm_account_transition_events(id);


--
-- Name: firm_account_transition_targets firm_account_transition_targets_firm_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_account_transition_targets
    ADD CONSTRAINT firm_account_transition_targets_firm_account_id_fkey FOREIGN KEY (firm_account_id) REFERENCES public.firm_chart_accounts(id);


--
-- Name: firm_account_transition_targets firm_account_transition_targets_transition_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_account_transition_targets
    ADD CONSTRAINT firm_account_transition_targets_transition_event_id_fkey FOREIGN KEY (transition_event_id) REFERENCES public.firm_account_transition_events(id);


--
-- Name: firm_accounting_locks firm_accounting_locks_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_accounting_locks
    ADD CONSTRAINT firm_accounting_locks_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: firm_accounting_locks firm_accounting_locks_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_accounting_locks
    ADD CONSTRAINT firm_accounting_locks_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: firm_activities firm_activities_activity_code_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_activities
    ADD CONSTRAINT firm_activities_activity_code_id_fkey FOREIGN KEY (activity_code_id) REFERENCES public.economic_activity_codes(id);


--
-- Name: firm_activities firm_activities_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_activities
    ADD CONSTRAINT firm_activities_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: firm_addresses firm_addresses_address_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_addresses
    ADD CONSTRAINT firm_addresses_address_id_fkey FOREIGN KEY (address_id) REFERENCES public.addresses(id);


--
-- Name: firm_addresses firm_addresses_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_addresses
    ADD CONSTRAINT firm_addresses_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: firm_bank_account_ledger_accounts firm_bank_account_ledger_accounts_firm_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_bank_account_ledger_accounts
    ADD CONSTRAINT firm_bank_account_ledger_accounts_firm_account_id_fkey FOREIGN KEY (firm_account_id) REFERENCES public.firm_chart_accounts(id);


--
-- Name: firm_bank_account_ledger_accounts firm_bank_account_ledger_accounts_firm_bank_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_bank_account_ledger_accounts
    ADD CONSTRAINT firm_bank_account_ledger_accounts_firm_bank_account_id_fkey FOREIGN KEY (firm_bank_account_id) REFERENCES public.firm_bank_accounts(id);


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
-- Name: firm_chart_accounts firm_chart_accounts_account_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_chart_accounts
    ADD CONSTRAINT firm_chart_accounts_account_type_id_fkey FOREIGN KEY (account_type_id) REFERENCES public.account_types(id);


--
-- Name: firm_chart_accounts firm_chart_accounts_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_chart_accounts
    ADD CONSTRAINT firm_chart_accounts_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: firm_chart_accounts firm_chart_accounts_master_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_chart_accounts
    ADD CONSTRAINT firm_chart_accounts_master_account_id_fkey FOREIGN KEY (master_account_id) REFERENCES public.chart_of_accounts(id);


--
-- Name: firm_chart_accounts firm_chart_accounts_normal_balance_side_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_chart_accounts
    ADD CONSTRAINT firm_chart_accounts_normal_balance_side_id_fkey FOREIGN KEY (normal_balance_side_id) REFERENCES public.normal_balance_sides(id);


--
-- Name: firm_chart_accounts firm_chart_accounts_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_chart_accounts
    ADD CONSTRAINT firm_chart_accounts_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.firm_chart_accounts(id);


--
-- Name: firm_chart_accounts firm_chart_accounts_section_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_chart_accounts
    ADD CONSTRAINT firm_chart_accounts_section_id_fkey FOREIGN KEY (section_id) REFERENCES public.account_sections(id);


--
-- Name: firm_chart_accounts firm_chart_accounts_semantic_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_chart_accounts
    ADD CONSTRAINT firm_chart_accounts_semantic_type_id_fkey FOREIGN KEY (semantic_type_id) REFERENCES public.account_semantic_types(id);


--
-- Name: firm_counterparties firm_counterparties_counterparty_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_counterparties
    ADD CONSTRAINT firm_counterparties_counterparty_id_fkey FOREIGN KEY (counterparty_id) REFERENCES public.counterparties(id);


--
-- Name: firm_counterparties firm_counterparties_default_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_counterparties
    ADD CONSTRAINT firm_counterparties_default_currency_id_fkey FOREIGN KEY (default_currency_id) REFERENCES public.ref_currencies(id);


--
-- Name: firm_counterparties firm_counterparties_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_counterparties
    ADD CONSTRAINT firm_counterparties_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: firm_counterparty_accounts firm_counterparty_accounts_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_counterparty_accounts
    ADD CONSTRAINT firm_counterparty_accounts_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES public.ref_currencies(id);


--
-- Name: firm_counterparty_accounts firm_counterparty_accounts_firm_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_counterparty_accounts
    ADD CONSTRAINT firm_counterparty_accounts_firm_account_id_fkey FOREIGN KEY (firm_account_id) REFERENCES public.firm_chart_accounts(id);


--
-- Name: firm_counterparty_accounts firm_counterparty_accounts_firm_counterparty_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_counterparty_accounts
    ADD CONSTRAINT firm_counterparty_accounts_firm_counterparty_id_fkey FOREIGN KEY (firm_counterparty_id) REFERENCES public.firm_counterparties(id);


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
-- Name: firm_foreign_vat_registrations firm_foreign_vat_registrations_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_foreign_vat_registrations
    ADD CONSTRAINT firm_foreign_vat_registrations_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.ref_countries(id);


--
-- Name: firm_foreign_vat_registrations firm_foreign_vat_registrations_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_foreign_vat_registrations
    ADD CONSTRAINT firm_foreign_vat_registrations_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


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
-- Name: firm_item_aliases firm_item_aliases_counterparty_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_item_aliases
    ADD CONSTRAINT firm_item_aliases_counterparty_id_fkey FOREIGN KEY (counterparty_id) REFERENCES public.counterparties(id);


--
-- Name: firm_item_aliases firm_item_aliases_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_item_aliases
    ADD CONSTRAINT firm_item_aliases_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: firm_item_aliases firm_item_aliases_firm_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_item_aliases
    ADD CONSTRAINT firm_item_aliases_firm_item_id_fkey FOREIGN KEY (firm_item_id) REFERENCES public.firm_items(id) ON DELETE CASCADE;


--
-- Name: firm_item_match_decisions firm_item_match_decisions_counterparty_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_item_match_decisions
    ADD CONSTRAINT firm_item_match_decisions_counterparty_id_fkey FOREIGN KEY (counterparty_id) REFERENCES public.counterparties(id);


--
-- Name: firm_item_match_decisions firm_item_match_decisions_decided_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_item_match_decisions
    ADD CONSTRAINT firm_item_match_decisions_decided_by_fkey FOREIGN KEY (decided_by) REFERENCES public.users(id);


--
-- Name: firm_item_match_decisions firm_item_match_decisions_document_line_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_item_match_decisions
    ADD CONSTRAINT firm_item_match_decisions_document_line_id_fkey FOREIGN KEY (document_line_id) REFERENCES public.document_lines(id) ON DELETE SET NULL;


--
-- Name: firm_item_match_decisions firm_item_match_decisions_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_item_match_decisions
    ADD CONSTRAINT firm_item_match_decisions_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: firm_item_match_decisions firm_item_match_decisions_selected_firm_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_item_match_decisions
    ADD CONSTRAINT firm_item_match_decisions_selected_firm_item_id_fkey FOREIGN KEY (selected_firm_item_id) REFERENCES public.firm_items(id);


--
-- Name: firm_item_match_decisions firm_item_match_decisions_suggested_firm_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_item_match_decisions
    ADD CONSTRAINT firm_item_match_decisions_suggested_firm_item_id_fkey FOREIGN KEY (suggested_firm_item_id) REFERENCES public.firm_items(id);


--
-- Name: firm_items firm_items_default_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_items
    ADD CONSTRAINT firm_items_default_unit_id_fkey FOREIGN KEY (default_unit_id) REFERENCES public.ref_units_of_measure(id);


--
-- Name: firm_items firm_items_expense_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_items
    ADD CONSTRAINT firm_items_expense_account_id_fkey FOREIGN KEY (expense_account_id) REFERENCES public.firm_chart_accounts(id);


--
-- Name: firm_items firm_items_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_items
    ADD CONSTRAINT firm_items_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: firm_items firm_items_inventory_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_items
    ADD CONSTRAINT firm_items_inventory_account_id_fkey FOREIGN KEY (inventory_account_id) REFERENCES public.firm_chart_accounts(id);


--
-- Name: firm_items firm_items_revenue_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_items
    ADD CONSTRAINT firm_items_revenue_account_id_fkey FOREIGN KEY (revenue_account_id) REFERENCES public.firm_chart_accounts(id);


--
-- Name: firm_items firm_items_vat_tax_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_items
    ADD CONSTRAINT firm_items_vat_tax_category_id_fkey FOREIGN KEY (vat_tax_category_id) REFERENCES public.vat_tax_categories(id);


--
-- Name: firm_report_account_rules firm_report_account_rules_corresponding_firm_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_report_account_rules
    ADD CONSTRAINT firm_report_account_rules_corresponding_firm_account_id_fkey FOREIGN KEY (corresponding_firm_account_id) REFERENCES public.firm_chart_accounts(id);


--
-- Name: firm_report_account_rules firm_report_account_rules_firm_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_report_account_rules
    ADD CONSTRAINT firm_report_account_rules_firm_account_id_fkey FOREIGN KEY (firm_account_id) REFERENCES public.firm_chart_accounts(id);


--
-- Name: firm_report_account_rules firm_report_account_rules_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_report_account_rules
    ADD CONSTRAINT firm_report_account_rules_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: firm_report_account_rules firm_report_account_rules_master_report_account_rule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_report_account_rules
    ADD CONSTRAINT firm_report_account_rules_master_report_account_rule_id_fkey FOREIGN KEY (master_report_account_rule_id) REFERENCES public.report_account_rules(id);


--
-- Name: firm_report_account_rules firm_report_account_rules_report_line_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_report_account_rules
    ADD CONSTRAINT firm_report_account_rules_report_line_id_fkey FOREIGN KEY (report_line_id) REFERENCES public.report_lines(id);


--
-- Name: firm_vat_credit_coefficients firm_vat_credit_coefficients_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_vat_credit_coefficients
    ADD CONSTRAINT firm_vat_credit_coefficients_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: firm_vat_registrations firm_vat_registrations_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_vat_registrations
    ADD CONSTRAINT firm_vat_registrations_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: firm_vat_registrations firm_vat_registrations_type_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_vat_registrations
    ADD CONSTRAINT firm_vat_registrations_type_fkey FOREIGN KEY (vat_registration_type_id) REFERENCES public.vat_registration_types(id);


--
-- Name: firm_vat_rules firm_vat_rules_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_vat_rules
    ADD CONSTRAINT firm_vat_rules_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: firm_vat_rules firm_vat_rules_master_vat_rule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_vat_rules
    ADD CONSTRAINT firm_vat_rules_master_vat_rule_id_fkey FOREIGN KEY (master_vat_rule_id) REFERENCES public.vat_rules(id);


--
-- Name: firm_vat_rules firm_vat_rules_vat_activity_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_vat_rules
    ADD CONSTRAINT firm_vat_rules_vat_activity_tag_id_fkey FOREIGN KEY (vat_activity_tag_id) REFERENCES public.vat_activity_tags(id);


--
-- Name: firm_vat_rules firm_vat_rules_vat_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_vat_rules
    ADD CONSTRAINT firm_vat_rules_vat_article_id_fkey FOREIGN KEY (vat_article_id) REFERENCES public.vat_articles(id);


--
-- Name: firm_vat_rules firm_vat_rules_vat_special_regime_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_vat_rules
    ADD CONSTRAINT firm_vat_rules_vat_special_regime_id_fkey FOREIGN KEY (vat_special_regime_id) REFERENCES public.vat_special_regimes(id);


--
-- Name: firm_vat_rules firm_vat_rules_vat_term_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_vat_rules
    ADD CONSTRAINT firm_vat_rules_vat_term_id_fkey FOREIGN KEY (vat_term_id) REFERENCES public.vat_terms(id);


--
-- Name: firm_vat_rules firm_vat_rules_vies_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_vat_rules
    ADD CONSTRAINT firm_vat_rules_vies_type_id_fkey FOREIGN KEY (vies_type_id) REFERENCES public.vies_types(id);


--
-- Name: firm_vat_settings firm_vat_settings_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_vat_settings
    ADD CONSTRAINT firm_vat_settings_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: firm_vat_settings firm_vat_settings_nondeductible_vat_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.firm_vat_settings
    ADD CONSTRAINT firm_vat_settings_nondeductible_vat_account_id_fkey FOREIGN KEY (nondeductible_vat_account_id) REFERENCES public.firm_chart_accounts(id);


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
-- Name: import_batches import_batches_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_batches
    ADD CONSTRAINT import_batches_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: import_batches import_batches_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_batches
    ADD CONSTRAINT import_batches_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


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
-- Name: journal_entries journal_entries_accounting_period_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entries
    ADD CONSTRAINT journal_entries_accounting_period_id_fkey FOREIGN KEY (accounting_period_id) REFERENCES public.accounting_periods(id);


--
-- Name: journal_entries journal_entries_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entries
    ADD CONSTRAINT journal_entries_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: journal_entries journal_entries_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entries
    ADD CONSTRAINT journal_entries_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: journal_entries journal_entries_import_batch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entries
    ADD CONSTRAINT journal_entries_import_batch_id_fkey FOREIGN KEY (import_batch_id) REFERENCES public.import_batches(id);


--
-- Name: journal_entries journal_entries_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entries
    ADD CONSTRAINT journal_entries_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- Name: journal_entry_documents journal_entry_documents_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entry_documents
    ADD CONSTRAINT journal_entry_documents_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.documents(id);


--
-- Name: journal_entry_documents journal_entry_documents_journal_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entry_documents
    ADD CONSTRAINT journal_entry_documents_journal_entry_id_fkey FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id);


--
-- Name: journal_entry_lines journal_entry_lines_counterparty_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entry_lines
    ADD CONSTRAINT journal_entry_lines_counterparty_id_fkey FOREIGN KEY (counterparty_id) REFERENCES public.counterparties(id);


--
-- Name: journal_entry_lines journal_entry_lines_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entry_lines
    ADD CONSTRAINT journal_entry_lines_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES public.ref_currencies(id);


--
-- Name: journal_entry_lines journal_entry_lines_firm_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entry_lines
    ADD CONSTRAINT journal_entry_lines_firm_account_id_fkey FOREIGN KEY (firm_account_id) REFERENCES public.firm_chart_accounts(id);


--
-- Name: journal_entry_lines journal_entry_lines_journal_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entry_lines
    ADD CONSTRAINT journal_entry_lines_journal_entry_id_fkey FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id);


--
-- Name: journal_entry_lines journal_entry_lines_vat_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entry_lines
    ADD CONSTRAINT journal_entry_lines_vat_article_id_fkey FOREIGN KEY (vat_article_id) REFERENCES public.vat_articles(id);


--
-- Name: journal_entry_lines journal_entry_lines_vat_assessment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entry_lines
    ADD CONSTRAINT journal_entry_lines_vat_assessment_id_fkey FOREIGN KEY (vat_assessment_id) REFERENCES public.vat_assessments(id);


--
-- Name: journal_entry_lines journal_entry_lines_vat_special_regime_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entry_lines
    ADD CONSTRAINT journal_entry_lines_vat_special_regime_id_fkey FOREIGN KEY (vat_special_regime_id) REFERENCES public.vat_special_regimes(id);


--
-- Name: journal_entry_lines journal_entry_lines_vat_term_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entry_lines
    ADD CONSTRAINT journal_entry_lines_vat_term_id_fkey FOREIGN KEY (vat_term_id) REFERENCES public.vat_terms(id);


--
-- Name: journal_entry_lines journal_entry_lines_vies_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entry_lines
    ADD CONSTRAINT journal_entry_lines_vies_type_id_fkey FOREIGN KEY (vies_type_id) REFERENCES public.vies_types(id);


--
-- Name: journal_line_analytics journal_line_analytics_dimension_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_line_analytics
    ADD CONSTRAINT journal_line_analytics_dimension_id_fkey FOREIGN KEY (dimension_id) REFERENCES public.analytic_dimensions(id);


--
-- Name: journal_line_analytics journal_line_analytics_journal_entry_line_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_line_analytics
    ADD CONSTRAINT journal_line_analytics_journal_entry_line_id_fkey FOREIGN KEY (journal_entry_line_id) REFERENCES public.journal_entry_lines(id);


--
-- Name: open_items open_items_counterparty_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.open_items
    ADD CONSTRAINT open_items_counterparty_id_fkey FOREIGN KEY (counterparty_id) REFERENCES public.counterparties(id);


--
-- Name: open_items open_items_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.open_items
    ADD CONSTRAINT open_items_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES public.ref_currencies(id);


--
-- Name: open_items open_items_firm_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.open_items
    ADD CONSTRAINT open_items_firm_account_id_fkey FOREIGN KEY (firm_account_id) REFERENCES public.firm_chart_accounts(id);


--
-- Name: open_items open_items_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.open_items
    ADD CONSTRAINT open_items_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: open_items open_items_source_journal_entry_line_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.open_items
    ADD CONSTRAINT open_items_source_journal_entry_line_id_fkey FOREIGN KEY (source_journal_entry_line_id) REFERENCES public.journal_entry_lines(id);


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
-- Name: projects projects_firm_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_firm_group_id_fkey FOREIGN KEY (firm_group_id) REFERENCES public.firm_groups(id);


--
-- Name: projects projects_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: projects projects_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.projects(id);


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
-- Name: ref_post_offices ref_post_offices_district_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_post_offices
    ADD CONSTRAINT ref_post_offices_district_id_fkey FOREIGN KEY (district_id) REFERENCES public.ref_districts(id);


--
-- Name: ref_post_offices ref_post_offices_postal_code_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ref_post_offices
    ADD CONSTRAINT ref_post_offices_postal_code_id_fkey FOREIGN KEY (postal_code_id) REFERENCES public.ref_postal_codes(id);


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
-- Name: report_account_rules report_account_rules_corresponding_master_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_account_rules
    ADD CONSTRAINT report_account_rules_corresponding_master_account_id_fkey FOREIGN KEY (corresponding_master_account_id) REFERENCES public.chart_of_accounts(id);


--
-- Name: report_account_rules report_account_rules_corresponding_section_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_account_rules
    ADD CONSTRAINT report_account_rules_corresponding_section_id_fkey FOREIGN KEY (corresponding_section_id) REFERENCES public.account_sections(id);


--
-- Name: report_account_rules report_account_rules_master_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_account_rules
    ADD CONSTRAINT report_account_rules_master_account_id_fkey FOREIGN KEY (master_account_id) REFERENCES public.chart_of_accounts(id);


--
-- Name: report_account_rules report_account_rules_master_section_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_account_rules
    ADD CONSTRAINT report_account_rules_master_section_id_fkey FOREIGN KEY (master_section_id) REFERENCES public.account_sections(id);


--
-- Name: report_account_rules report_account_rules_report_line_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_account_rules
    ADD CONSTRAINT report_account_rules_report_line_id_fkey FOREIGN KEY (report_line_id) REFERENCES public.report_lines(id);


--
-- Name: report_lines report_lines_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_lines
    ADD CONSTRAINT report_lines_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.report_lines(id);


--
-- Name: report_lines report_lines_report_definition_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_lines
    ADD CONSTRAINT report_lines_report_definition_id_fkey FOREIGN KEY (report_definition_id) REFERENCES public.report_definitions(id);


--
-- Name: report_rule_filters report_rule_filters_dimension_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_rule_filters
    ADD CONSTRAINT report_rule_filters_dimension_id_fkey FOREIGN KEY (dimension_id) REFERENCES public.analytic_dimensions(id);


--
-- Name: report_rule_filters report_rule_filters_excluded_master_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_rule_filters
    ADD CONSTRAINT report_rule_filters_excluded_master_account_id_fkey FOREIGN KEY (excluded_master_account_id) REFERENCES public.chart_of_accounts(id);


--
-- Name: report_rule_filters report_rule_filters_report_account_rule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_rule_filters
    ADD CONSTRAINT report_rule_filters_report_account_rule_id_fkey FOREIGN KEY (report_account_rule_id) REFERENCES public.report_account_rules(id);


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
-- Name: settlement_allocations settlement_allocations_journal_entry_line_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settlement_allocations
    ADD CONSTRAINT settlement_allocations_journal_entry_line_id_fkey FOREIGN KEY (journal_entry_line_id) REFERENCES public.journal_entry_lines(id);


--
-- Name: settlement_allocations settlement_allocations_open_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settlement_allocations
    ADD CONSTRAINT settlement_allocations_open_item_id_fkey FOREIGN KEY (open_item_id) REFERENCES public.open_items(id);


--
-- Name: settlement_allocations settlement_allocations_settlement_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settlement_allocations
    ADD CONSTRAINT settlement_allocations_settlement_id_fkey FOREIGN KEY (settlement_id) REFERENCES public.settlements(id);


--
-- Name: settlements settlements_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settlements
    ADD CONSTRAINT settlements_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: settlements settlements_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settlements
    ADD CONSTRAINT settlements_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.documents(id);


--
-- Name: settlements settlements_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settlements
    ADD CONSTRAINT settlements_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: settlements settlements_journal_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settlements
    ADD CONSTRAINT settlements_journal_entry_id_fkey FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id);


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
-- Name: vat_article_groups vat_article_groups_vat_activity_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_article_groups
    ADD CONSTRAINT vat_article_groups_vat_activity_tag_id_fkey FOREIGN KEY (vat_activity_tag_id) REFERENCES public.vat_activity_tags(id);


--
-- Name: vat_articles vat_articles_vat_article_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_articles
    ADD CONSTRAINT vat_articles_vat_article_group_id_fkey FOREIGN KEY (vat_article_group_id) REFERENCES public.vat_article_groups(id);


--
-- Name: vat_assessments vat_assessments_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_assessments
    ADD CONSTRAINT vat_assessments_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: vat_assessments vat_assessments_input_claim_vat_period_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_assessments
    ADD CONSTRAINT vat_assessments_input_claim_vat_period_id_fkey FOREIGN KEY (input_claim_vat_period_id) REFERENCES public.vat_periods(id);


--
-- Name: vat_assessments vat_assessments_input_vat_term_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_assessments
    ADD CONSTRAINT vat_assessments_input_vat_term_id_fkey FOREIGN KEY (input_vat_term_id) REFERENCES public.vat_terms(id);


--
-- Name: vat_assessments vat_assessments_journal_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_assessments
    ADD CONSTRAINT vat_assessments_journal_entry_id_fkey FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id);


--
-- Name: vat_assessments vat_assessments_output_vat_term_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_assessments
    ADD CONSTRAINT vat_assessments_output_vat_term_id_fkey FOREIGN KEY (output_vat_term_id) REFERENCES public.vat_terms(id);


--
-- Name: vat_assessments vat_assessments_protocol_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_assessments
    ADD CONSTRAINT vat_assessments_protocol_document_id_fkey FOREIGN KEY (protocol_document_id) REFERENCES public.documents(id);


--
-- Name: vat_assessments vat_assessments_source_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_assessments
    ADD CONSTRAINT vat_assessments_source_document_id_fkey FOREIGN KEY (source_document_id) REFERENCES public.documents(id);


--
-- Name: vat_assessments vat_assessments_vat_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_assessments
    ADD CONSTRAINT vat_assessments_vat_article_id_fkey FOREIGN KEY (vat_article_id) REFERENCES public.vat_articles(id);


--
-- Name: vat_assessments vat_assessments_vat_rule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_assessments
    ADD CONSTRAINT vat_assessments_vat_rule_id_fkey FOREIGN KEY (vat_rule_id) REFERENCES public.vat_rules(id);


--
-- Name: vat_assessments vat_assessments_vat_special_regime_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_assessments
    ADD CONSTRAINT vat_assessments_vat_special_regime_id_fkey FOREIGN KEY (vat_special_regime_id) REFERENCES public.vat_special_regimes(id);


--
-- Name: vat_assessments vat_assessments_vies_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_assessments
    ADD CONSTRAINT vat_assessments_vies_type_id_fkey FOREIGN KEY (vies_type_id) REFERENCES public.vies_types(id);


--
-- Name: vat_b2c_destination_policies vat_b2c_destination_policies_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_b2c_destination_policies
    ADD CONSTRAINT vat_b2c_destination_policies_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: vat_country_rate_applicability vat_country_rate_applicability_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_country_rate_applicability
    ADD CONSTRAINT vat_country_rate_applicability_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.ref_countries(id);


--
-- Name: vat_country_rate_applicability vat_country_rate_applicability_vat_rate_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_country_rate_applicability
    ADD CONSTRAINT vat_country_rate_applicability_vat_rate_type_id_fkey FOREIGN KEY (vat_rate_type_id) REFERENCES public.vat_rate_types(id);


--
-- Name: vat_country_rate_applicability vat_country_rate_applicability_vat_tax_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_country_rate_applicability
    ADD CONSTRAINT vat_country_rate_applicability_vat_tax_category_id_fkey FOREIGN KEY (vat_tax_category_id) REFERENCES public.vat_tax_categories(id);


--
-- Name: vat_country_rates vat_country_rates_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_country_rates
    ADD CONSTRAINT vat_country_rates_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.ref_countries(id);


--
-- Name: vat_country_rates vat_country_rates_vat_rate_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_country_rates
    ADD CONSTRAINT vat_country_rates_vat_rate_type_id_fkey FOREIGN KEY (vat_rate_type_id) REFERENCES public.vat_rate_types(id);


--
-- Name: vat_ledger_snapshot_entries vat_ledger_snapshot_entries_counterparty_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_ledger_snapshot_entries
    ADD CONSTRAINT vat_ledger_snapshot_entries_counterparty_id_fkey FOREIGN KEY (counterparty_id) REFERENCES public.counterparties(id);


--
-- Name: vat_ledger_snapshot_entries vat_ledger_snapshot_entries_document_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_ledger_snapshot_entries
    ADD CONSTRAINT vat_ledger_snapshot_entries_document_id_fkey FOREIGN KEY (document_id) REFERENCES public.documents(id);


--
-- Name: vat_ledger_snapshot_entries vat_ledger_snapshot_entries_snapshot_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_ledger_snapshot_entries
    ADD CONSTRAINT vat_ledger_snapshot_entries_snapshot_id_fkey FOREIGN KEY (snapshot_id) REFERENCES public.vat_ledger_snapshots(id);


--
-- Name: vat_ledger_snapshot_lines vat_ledger_snapshot_lines_snapshot_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_ledger_snapshot_lines
    ADD CONSTRAINT vat_ledger_snapshot_lines_snapshot_entry_id_fkey FOREIGN KEY (snapshot_entry_id) REFERENCES public.vat_ledger_snapshot_entries(id);


--
-- Name: vat_ledger_snapshot_lines vat_ledger_snapshot_lines_vat_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_ledger_snapshot_lines
    ADD CONSTRAINT vat_ledger_snapshot_lines_vat_article_id_fkey FOREIGN KEY (vat_article_id) REFERENCES public.vat_articles(id);


--
-- Name: vat_ledger_snapshot_lines vat_ledger_snapshot_lines_vat_special_regime_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_ledger_snapshot_lines
    ADD CONSTRAINT vat_ledger_snapshot_lines_vat_special_regime_id_fkey FOREIGN KEY (vat_special_regime_id) REFERENCES public.vat_special_regimes(id);


--
-- Name: vat_ledger_snapshot_lines vat_ledger_snapshot_lines_vat_term_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_ledger_snapshot_lines
    ADD CONSTRAINT vat_ledger_snapshot_lines_vat_term_id_fkey FOREIGN KEY (vat_term_id) REFERENCES public.vat_terms(id);


--
-- Name: vat_ledger_snapshot_lines vat_ledger_snapshot_lines_vies_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_ledger_snapshot_lines
    ADD CONSTRAINT vat_ledger_snapshot_lines_vies_type_id_fkey FOREIGN KEY (vies_type_id) REFERENCES public.vies_types(id);


--
-- Name: vat_ledger_snapshots vat_ledger_snapshots_generated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_ledger_snapshots
    ADD CONSTRAINT vat_ledger_snapshots_generated_by_fkey FOREIGN KEY (generated_by) REFERENCES public.users(id);


--
-- Name: vat_ledger_snapshots vat_ledger_snapshots_vat_period_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_ledger_snapshots
    ADD CONSTRAINT vat_ledger_snapshots_vat_period_id_fkey FOREIGN KEY (vat_period_id) REFERENCES public.vat_periods(id);


--
-- Name: vat_periods vat_periods_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_periods
    ADD CONSTRAINT vat_periods_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: vat_periods vat_periods_firm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_periods
    ADD CONSTRAINT vat_periods_firm_id_fkey FOREIGN KEY (firm_id) REFERENCES public.firms(id);


--
-- Name: vat_periods vat_periods_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_periods
    ADD CONSTRAINT vat_periods_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- Name: vat_registration_compatibility vat_registration_compatibility_type_a_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_registration_compatibility
    ADD CONSTRAINT vat_registration_compatibility_type_a_id_fkey FOREIGN KEY (type_a_id) REFERENCES public.vat_registration_types(id);


--
-- Name: vat_registration_compatibility vat_registration_compatibility_type_b_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_registration_compatibility
    ADD CONSTRAINT vat_registration_compatibility_type_b_id_fkey FOREIGN KEY (type_b_id) REFERENCES public.vat_registration_types(id);


--
-- Name: vat_registration_trigger_conditions vat_registration_trigger_conditio_vat_registration_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_registration_trigger_conditions
    ADD CONSTRAINT vat_registration_trigger_conditio_vat_registration_type_id_fkey FOREIGN KEY (vat_registration_type_id) REFERENCES public.vat_registration_types(id);


--
-- Name: vat_registration_trigger_conditions vat_registration_trigger_conditions_trigger_rule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_registration_trigger_conditions
    ADD CONSTRAINT vat_registration_trigger_conditions_trigger_rule_id_fkey FOREIGN KEY (trigger_rule_id) REFERENCES public.vat_registration_trigger_rules(id) ON DELETE CASCADE;


--
-- Name: vat_registration_trigger_rules vat_registration_trigger_rules_target_registration_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_registration_trigger_rules
    ADD CONSTRAINT vat_registration_trigger_rules_target_registration_type_id_fkey FOREIGN KEY (target_registration_type_id) REFERENCES public.vat_registration_types(id);


--
-- Name: vat_registration_trigger_rules vat_registration_trigger_rules_turnover_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_registration_trigger_rules
    ADD CONSTRAINT vat_registration_trigger_rules_turnover_type_id_fkey FOREIGN KEY (turnover_type_id) REFERENCES public.vat_turnover_types(id);


--
-- Name: vat_rule_registration_requirements vat_rule_registration_requirement_vat_registration_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_rule_registration_requirements
    ADD CONSTRAINT vat_rule_registration_requirement_vat_registration_type_id_fkey FOREIGN KEY (vat_registration_type_id) REFERENCES public.vat_registration_types(id);


--
-- Name: vat_rule_registration_requirements vat_rule_registration_requirements_vat_rule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_rule_registration_requirements
    ADD CONSTRAINT vat_rule_registration_requirements_vat_rule_id_fkey FOREIGN KEY (vat_rule_id) REFERENCES public.vat_rules(id) ON DELETE CASCADE;


--
-- Name: vat_rule_turnover_effects vat_rule_turnover_effects_turnover_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_rule_turnover_effects
    ADD CONSTRAINT vat_rule_turnover_effects_turnover_type_id_fkey FOREIGN KEY (turnover_type_id) REFERENCES public.vat_turnover_types(id);


--
-- Name: vat_rule_turnover_effects vat_rule_turnover_effects_vat_rule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_rule_turnover_effects
    ADD CONSTRAINT vat_rule_turnover_effects_vat_rule_id_fkey FOREIGN KEY (vat_rule_id) REFERENCES public.vat_rules(id) ON DELETE CASCADE;


--
-- Name: vat_rules vat_rules_input_vat_term_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_rules
    ADD CONSTRAINT vat_rules_input_vat_term_id_fkey FOREIGN KEY (input_vat_term_id) REFERENCES public.vat_terms(id);


--
-- Name: vat_rules vat_rules_output_vat_term_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_rules
    ADD CONSTRAINT vat_rules_output_vat_term_id_fkey FOREIGN KEY (output_vat_term_id) REFERENCES public.vat_terms(id);


--
-- Name: vat_rules vat_rules_vat_activity_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_rules
    ADD CONSTRAINT vat_rules_vat_activity_tag_id_fkey FOREIGN KEY (vat_activity_tag_id) REFERENCES public.vat_activity_tags(id);


--
-- Name: vat_rules vat_rules_vat_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_rules
    ADD CONSTRAINT vat_rules_vat_article_id_fkey FOREIGN KEY (vat_article_id) REFERENCES public.vat_articles(id);


--
-- Name: vat_rules vat_rules_vat_special_regime_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_rules
    ADD CONSTRAINT vat_rules_vat_special_regime_id_fkey FOREIGN KEY (vat_special_regime_id) REFERENCES public.vat_special_regimes(id);


--
-- Name: vat_rules vat_rules_vat_term_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_rules
    ADD CONSTRAINT vat_rules_vat_term_id_fkey FOREIGN KEY (vat_term_id) REFERENCES public.vat_terms(id);


--
-- Name: vat_rules vat_rules_vies_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_rules
    ADD CONSTRAINT vat_rules_vies_type_id_fkey FOREIGN KEY (vies_type_id) REFERENCES public.vies_types(id);


--
-- Name: vat_tax_categories vat_tax_categories_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_tax_categories
    ADD CONSTRAINT vat_tax_categories_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.vat_tax_categories(id);


--
-- Name: vat_terms vat_terms_default_vies_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_terms
    ADD CONSTRAINT vat_terms_default_vies_type_id_fkey FOREIGN KEY (default_vies_type_id) REFERENCES public.vies_types(id);


--
-- Name: vat_terms vat_terms_transaction_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_terms
    ADD CONSTRAINT vat_terms_transaction_type_id_fkey FOREIGN KEY (transaction_type_id) REFERENCES public.vat_transaction_types(id);


--
-- Name: vat_territories vat_territories_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_territories
    ADD CONSTRAINT vat_territories_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.ref_countries(id);


--
-- Name: vat_territories vat_territories_treated_as_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_territories
    ADD CONSTRAINT vat_territories_treated_as_country_id_fkey FOREIGN KEY (treated_as_country_id) REFERENCES public.ref_countries(id);


--
-- Name: vat_turnover_override_rules vat_turnover_override_rules_turnover_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_turnover_override_rules
    ADD CONSTRAINT vat_turnover_override_rules_turnover_type_id_fkey FOREIGN KEY (turnover_type_id) REFERENCES public.vat_turnover_types(id);


--
-- Name: vat_turnover_override_rules vat_turnover_override_rules_vat_activity_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_turnover_override_rules
    ADD CONSTRAINT vat_turnover_override_rules_vat_activity_tag_id_fkey FOREIGN KEY (vat_activity_tag_id) REFERENCES public.vat_activity_tags(id);


--
-- Name: vat_turnover_thresholds vat_turnover_thresholds_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_turnover_thresholds
    ADD CONSTRAINT vat_turnover_thresholds_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.ref_countries(id);


--
-- Name: vat_turnover_thresholds vat_turnover_thresholds_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_turnover_thresholds
    ADD CONSTRAINT vat_turnover_thresholds_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES public.ref_currencies(id);


--
-- Name: vat_turnover_thresholds vat_turnover_thresholds_turnover_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vat_turnover_thresholds
    ADD CONSTRAINT vat_turnover_thresholds_turnover_type_id_fkey FOREIGN KEY (turnover_type_id) REFERENCES public.vat_turnover_types(id);


--
-- PostgreSQL database dump complete
--

\unrestrict C97bQSnaPMkXnNcCnDMG5Ai31Kq3imhME25bfeYZMmcGAO982fyfLr6AO8hWyui

