# ADR-003: Prisma strategy for pre-existing databases

- Status: Accepted
- Date: 2026-08-26

## Context

The three PostgreSQL databases already exist and include checks, partial indexes, functions, triggers, and a view that a Prisma schema cannot represent completely.

## Decision

Phase 1 adds no Prisma dependency, schema, generated client, introspection, baseline, or migration.

When database work is separately approved:

1. Inspect each database independently using a read-only account or disposable restored copy.
2. Introspect one database into one reviewed Prisma schema/client owned by its application.
3. Preserve table and column names with Prisma mappings.
4. Locate any historical migration records before adopting migration ownership.
5. Create a separate reviewed baseline for each database, including raw SQL for objects Prisma cannot model.
6. Mark a baseline as applied only through an approved operational procedure.
7. Keep future migrations domain-specific and test them against disposable databases.

`prisma db push` and `prisma migrate dev` are prohibited against existing authoritative databases. A single multi-database client package is prohibited. An Office-only database package may later be justified because both `office-api` and `document-worker` need scoped access.

## Consequences

- Prisma is an application data-access tool, not the complete database definition.
- Live schemas and the reference snapshots remain untouched in Phase 1.
- Migration ownership must be established before Phase 2 performs database-backed work.
