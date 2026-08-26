# Shared Core Prisma ownership

This directory belongs only to `shared-core-api` and models only the `shared_core` database.

The `00000000000000_legacy_baseline` migration is a normalized copy of the verified PostgreSQL 16.13 Shared Core schema snapshot. It removes the `pg_dump` `\\restrict` markers and its session-only empty `search_path` directive; leaving the latter active prevents Prisma from finding its own migration table after applying the baseline. All schema objects are explicitly qualified, so removing that directive does not change the recreated structure. The baseline includes PostgreSQL functions, triggers, checks, indexes, and foreign keys that Prisma cannot fully represent. It is authoritative for recreating the legacy structure; `schema.prisma` is an application mapping, not a complete database definition.

The `20260826140000_add_user_external_identities` migration was applied to live `shared_core` under the Phase 2B.2B-2 approval after a verified backup and zero-drift comparison. New migrations still require separate review and approval.

Never run `prisma db push` or `prisma migrate dev` against an existing Shared Core database. Runtime application credentials must not own DDL privileges.

`SHARED_CORE_DATABASE_URL` is the API's least-privilege runtime URL. Migration operations must receive the owner URL separately as `SHARED_CORE_MIGRATION_DATABASE_URL`; operators must explicitly map that value to Prisma's datasource variable for the duration of an approved migration command. Never expose the owner URL to the running API.
