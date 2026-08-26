# ADR-005: External identity persistence and actor references

- Status: Proposed for live migration approval
- Date: 2026-08-26

## Decision

Shared Core will store durable OIDC links in `user_external_identities`. A platform user may have multiple links. `(issuer, subject)` is unconditionally unique, including disabled and unlinked historical records. Only `user_id` is a relational ownership reference and has a foreign key to `users.id`.

`linked_by` and `status_changed_by` are nullable UUID actor snapshots without foreign keys. This matches the existing `audit_log.user_id` convention and ensures historical actor identity remains recorded even if actor lifecycle or future retention rules change. Application code validates a current actor before a privileged action; the database does not reinterpret these historical UUIDs as current authorization.

The three-state `status` column replaces an `is_active` boolean because `disabled` and `unlinked` must remain distinguishable. Runtime code exposes no physical-delete workflow. Every create or lifecycle transition must insert an `audit_log` record in the same transaction.

Email and username are never link keys. Unknown identities do not create platform users or links. Invitation and linking endpoints remain deferred.

## Consequences

- Actor UUIDs can remain after the actor is no longer present, preserving historical evidence.
- Actor existence is enforced by application command validation and audit context, not by a restrictive foreign key.
- Reporting that needs current actor display data must tolerate an unresolved historical UUID.
- The migration is additive but may not be applied to live Shared Core without separate approval.
