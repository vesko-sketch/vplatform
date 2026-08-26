# V Platform — Coding Agent Contract

## 1. Project identity

This repository is the implementation workspace for V Platform.

V Platform is a multi-application business platform with shared identity and access, public and private applications, document workflows, accounting workflows, integrations, and future payroll/scheduling modules.

Current applications:

- V Office — PUBLIC
- V Accounting — PRIVATE
- V Invoices — PUBLIC
- V Payroll — PRIVATE / future
- V Schedules — PUBLIC / future

## 2. Current authoritative databases

Three PostgreSQL databases already exist:

- shared_core
- office
- accounting

### shared_core
Authoritative master for:
- users
- firms
- firm groups
- roles and permissions
- application enablement/access
- shared platform identity

The same platform UUIDs for `user_id` and `firm_id` must be preserved across applications.

### office
Authoritative for:
- document intake
- document files and metadata
- document facts
- document lifecycle and routing
- operational office workflows
- accounting proposals
- ingestion / OCR / AI staging
- Auto Send policy
- AI review state
- public-facing office processes

### accounting
Authoritative for:
- chart of accounts
- firm accounting accounts
- journal
- debit / credit accounting
- VAT logic
- accounting periods
- settlements
- open items
- accounting reports
- accounting-specific mappings

Accounting is PRIVATE.

## 3. Security zones

### PUBLIC
May be internet-facing:
- V Office
- V Invoices
- V Schedules
- authentication endpoints intended for public login
- explicitly public APIs

### PRIVATE
Must remain internal / VPN / protected network:
- V Accounting
- V Payroll
- private accounting workers
- private accounting APIs
- direct access to Accounting PostgreSQL

Public applications must never receive direct database credentials to the Accounting database.

UI hiding is not security.

Authorization must be enforced in backend APIs.

## 4. Firm isolation

Firm isolation is mandatory.

Every firm-owned entity must be scoped by `firm_id`, directly or through an unambiguous parent relation.

Every read and write must validate:
- authenticated user
- firm access
- application access
- role / permission
- resource scope where applicable

Never trust `firm_id` from the client without authorization validation.

AI, search, vector, cache and read-model layers must preserve firm scope.

## 5. Existing schema first

Do not redesign existing database structures without necessity.

General rule:

1. Reuse existing tables and fields when suitable.
2. Add only what is missing.
3. Avoid unnecessary renaming.
4. Avoid parallel duplicate models.
5. Use migrations for all schema changes.
6. Never patch production schema manually.

Existing naming must be preserved where practical:
- `firms`
- `users`
- `firm_groups`
- `firm_group_members`
- `user_firm_roles`
- `ref_legal_forms`
- etc.

## 6. Domain ownership

Shared Core owns identity.

Office owns document intake and operational document facts.

Accounting owns accounting truth.

A projection/read model is never a second master.

Cross-database PostgreSQL foreign keys must not be used.

Cross-domain references use stable UUIDs and events/API contracts.

## 7. Document principles

Documents are Office-owned.

Supported intake channels include:
- portal upload
- email
- watched folders
- API
- future local agent / external integrations

Each configured intake channel belongs to a specific firm whenever possible.

The firm should normally be known before document processing begins.

Document processing may include:
- file validation
- checksum / duplicate detection
- storage
- OCR / parser
- document classification
- fact extraction
- normalization
- file rename / archive classification
- accounting proposal
- AI review
- human review

Documents may be linked to tasks, but tasks are not required to have documents.

Accounting journal entries may exist without documents.

## 8. Document storage

Applications must use a storage abstraction.

Do not hardcode Synology/NAS paths into frontend or business logic.

Storage providers may later include:
- Synology / NAS
- MinIO
- S3-compatible storage
- Hetzner Object Storage
- Google Drive as secondary/archive copy

Document metadata should preserve:
- document UUID
- firm UUID
- source channel
- original filename
- storage provider
- storage path/key
- checksum
- MIME type
- size
- timestamps
- provenance

Files should not be unnecessarily duplicated between domain databases.

## 9. Accounting proposals

Office may generate accounting proposals.

Accounting proposals are suggestions, not accounting truth.

They may contain:
- account codes
- VAT hints
- analytic hints
- confidence
- evidence
- validation results

Accounting must resolve and validate proposals inside the private Accounting domain.

Current rule:
- Office Auto Send may be implemented
- Accounting Human Post is mandatory
- Accounting Auto Post is deferred

## 10. Integration model

Cross-database communication uses:
- APIs
- outbox/inbox events
- idempotent consumers
- version-aware projections

Do not use distributed SQL transactions across databases.

Standard integration concepts:
- event_id
- source application
- event_type
- entity_type
- entity_id
- entity_version
- firm_id when applicable
- correlation_id
- timestamp
- payload

Consumers must be idempotent.

Older stale events must never overwrite newer local projections.

## 11. n8n usage

n8n is an integration/orchestration tool, not the business core.

Use n8n when it materially saves development time, for example:
- Gmail / Microsoft mail
- Google Drive
- notifications
- webhooks
- external APIs
- integration adapters

Keep critical business logic in application code:
- authentication
- authorization
- firm isolation
- document registration
- lifecycle/state
- accounting proposals
- audit
- domain validation
- canonical data updates

Core system operation must not depend on n8n being available.

## 12. AI / Dify / Qdrant

AI and vector systems are derived layers.

They are never authoritative accounting truth.

Current local AI stack may include:
- Dify
- Qdrant
- Ollama
- Open WebUI
- n8n

AI output must be traceable to:
- source application
- source entity
- firm
- source version
- confidence
- trust status

Useful trust states may include:
- proposed
- AI-reviewed
- human-verified
- accounting-confirmed

AI must not recursively treat its own unconfirmed output as trusted knowledge.

## 13. API design

Prefer stable REST APIs for MVP.

Requirements:
- UUID business identifiers
- consistent validation
- OpenAPI documentation
- explicit authorization
- optimistic concurrency where `row_version` applies
- typed request/response contracts
- predictable error responses
- audit context
- correlation/request IDs

Do not expose private Accounting internals through public APIs.

## 14. Preferred development stack

Current target stack:

Frontend:
- React
- TypeScript
- Next.js
- Tailwind CSS
- shadcn/ui

Backend:
- TypeScript
- NestJS
- REST / OpenAPI

Data:
- PostgreSQL
- Prisma initially unless an explicit architecture decision changes it

Background jobs:
- Redis
- BullMQ

Files:
- storage abstraction
- MinIO for development
- Synology integration later
- S3-compatible design

Tests:
- unit/integration tests
- Playwright for end-to-end UI tests

Package management:
- pnpm

Repository:
- monorepo

## 15. Repository structure

Expected high-level structure:

apps/
packages/
services/
infrastructure/
docs/

Likely applications:

apps/

- office-web
- office-api
- accounting-web
- accounting-api
- shared-core-api

Future:
- invoices-web/api
- payroll-web/api
- schedules-web/api

Shared packages may include:
- ui
- auth
- permissions
- api-contracts
- event-contracts
- database clients

Services may include:
- document-intake
- document-worker
- email-intake
- folder-watcher
- ai-processing

Do not create unnecessary microservices in the MVP.
Prefer a modular monorepo and split services only where operational boundaries justify it.

## 16. MVP priority

The first MVP must focus on:

### Identity and access
- authentication
- users
- firms
- firm groups
- roles
- permissions
- application access
- password/profile management

### V Office
- administrative firm/user management
- client portal foundation

### Document intake
- portal upload
- architecture for email intake
- architecture for watched folders
- API intake foundation

### Document processing
- safe storage
- checksum
- classification
- metadata
- rename/archive rules
- OCR / extraction pipeline
- accounting proposal
- review state
- ready-for-accounting boundary

### Accounting boundary
- receive Office-ready document package
- Accounting intake
- no automatic journal posting in MVP

## 17. Authentication

Do not invent a weak custom authentication implementation.

The platform is expected to support multiple applications and future SSO.

Prefer an established identity approach such as OIDC-compatible central authentication.

Final provider choice must be documented before implementation.

Passwords must never be stored in plain text.

Secrets must never be committed to Git.

## 18. Secrets and environments

Never commit:
- production DB passwords
- API keys
- OAuth secrets
- SMTP passwords
- NAS credentials
- VPN credentials
- production certificates
- real customer documents

Use `.env.example` only for variable names and safe placeholders.

Expected environments:
- DEV
- STAGING
- PRODUCTION

Development must use test/demo data.

## 19. Coding rules

Before changing schema or architecture:
1. inspect existing implementation;
2. reuse existing patterns;
3. document the proposed change;
4. add migration/tests;
5. preserve backward compatibility where practical.

Do not:
- silently change authoritative ownership
- add cross-database foreign keys
- expose private database credentials
- bypass authorization
- use vector data as accounting truth
- duplicate firm/user identity
- create a second master for shared entities
- hardcode firm-specific accounting rules
- build a permanent workaround when a clean domain boundary exists

## 20. Current infrastructure

Development host:
- Linux under WSL2
- Docker
- Docker Compose
- Git
- Node.js
- pnpm
- Codex CLI

Existing local services include:
- PostgreSQL
- n8n
- Dify
- Qdrant
- Open WebUI

Existing databases:
- shared_core
- office
- accounting

Do not modify existing databases or running infrastructure without an explicit task.

## 21. Agent workflow

For each substantial task:
1. Inspect relevant existing files/schema first.
2. State a short implementation plan.
3. Make the smallest coherent change.
4. Add/update tests.
5. Run relevant lint/test/build commands.
6. Report:
   - changed files
   - migrations
   - tests run
   - unresolved issues
   - security implications
7. Do not proceed into unrelated phases unless explicitly requested.

When architecture and code conflict with the documented V Platform architecture contract, stop and report the conflict rather than silently choosing a new design.
