# ADR-001: Domain ownership after the database split

- Status: Accepted
- Date: 2026-08-26

## Context

V Platform has three existing PostgreSQL databases. The Accounting database is the historical source database from which Shared Core and Office were split. Its duplicated identity, access, document, ingestion, and operational tables predate the current domain boundary.

## Decision

`shared_core` is authoritative for platform users, firms, firm groups, application enablement, firm access, roles, permissions, and authorization data.

`office` is authoritative for document intake, stored-file metadata, document facts, document lifecycle and routing, ingestion/OCR/AI staging, accounting proposals, Auto Send policy, and AI/human review state.

`accounting` is authoritative for chart and firm accounts, accounting periods, journal and debit/credit truth, VAT, settlements, open items, accounting reports, and accounting-specific mappings.

Duplicated Shared Core and Office tables remaining in Accounting are **legacy/unclassified duplicates**. Phase 1 does not classify them as active projections, synchronize them, or expose them as new masters. Each duplicate must receive an explicit keep/project/retire decision based on a concrete Accounting use case before application code relies on it.

Cross-database references use stable UUIDs and API/event contracts. Cross-database foreign keys and distributed SQL transactions are prohibited. A local projection never becomes a second master.

## Consequences

- Phase 1 contains no synchronization consumers or domain writes.
- Accounting will eventually receive only the minimum Shared Core and Office data required by the private domain.
- Existing schema names and structures remain unchanged until a concrete defect or requirement justifies a migration.
