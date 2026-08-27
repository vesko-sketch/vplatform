\set ON_ERROR_STOP on

-- REVIEW ONLY in Phase 3A.6. Do not apply live without explicit execution approval.
-- Supply the LOGIN password through approved secret management; never append it here.
CREATE ROLE shared_core_user_writer
    LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;

GRANT CONNECT ON DATABASE shared_core TO shared_core_user_writer;
GRANT USAGE ON SCHEMA public TO shared_core_user_writer;

GRANT SELECT (id, code, is_active) ON public.applications TO shared_core_user_writer;
GRANT SELECT (id, email, is_active, lifecycle_status, row_version) ON public.users TO shared_core_user_writer;
GRANT SELECT (id, user_id, issuer, subject, status, row_version)
    ON public.user_external_identities TO shared_core_user_writer;
GRANT SELECT (id, user_id, application_id, role_id, valid_from, valid_to, is_active)
    ON public.user_application_roles TO shared_core_user_writer;
GRANT SELECT (id, code, is_active) ON public.roles TO shared_core_user_writer;
GRANT SELECT (role_id, permission_id, is_active) ON public.role_permissions TO shared_core_user_writer;
GRANT SELECT (id, application_id, code, is_active, scope_type)
    ON public.permissions TO shared_core_user_writer;

GRANT SELECT (
    id, user_id, application_id, invited_email, normalized_email, token_digest, status,
    expires_at, consumed_at, consumed_identity_id, cancelled_at, cancelled_by,
    cancellation_reason, created_by, request_id, correlation_id, row_version,
    created_at, updated_at
) ON public.user_invitations TO shared_core_user_writer;

GRANT INSERT (id, email, display_name, is_active, lifecycle_status)
    ON public.users TO shared_core_user_writer;
GRANT UPDATE (display_name, is_active, lifecycle_status)
    ON public.users TO shared_core_user_writer;
GRANT INSERT (
    id, user_id, application_id, invited_email, normalized_email, token_digest,
    status, expires_at, created_by, request_id, correlation_id
) ON public.user_invitations TO shared_core_user_writer;
GRANT UPDATE (
    status, expires_at, consumed_at, consumed_identity_id,
    cancelled_at, cancelled_by, cancellation_reason
) ON public.user_invitations TO shared_core_user_writer;
GRANT INSERT (
    id, user_id, issuer, subject, status, link_provenance, linked_by,
    linked_at, status_changed_by, status_changed_at, status_change_reason
) ON public.user_external_identities TO shared_core_user_writer;
GRANT INSERT (
    firm_id, user_id, entity_type, entity_id, action, old_values,
    new_values, reason, source_type, request_id, correlation_id
) ON public.audit_log TO shared_core_user_writer;
GRANT INSERT (
    id, firm_id, entity_type, entity_id, event_type, payload,
    correlation_id, entity_version, source_application_code
) ON public.integration_outbox TO shared_core_user_writer;

REVOKE CREATE ON SCHEMA public FROM shared_core_user_writer;
