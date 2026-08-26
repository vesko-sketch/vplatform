# Shared Core Prisma ownership

This directory belongs only to `shared-core-api` and models only the `shared_core` database.

The `00000000000000_legacy_baseline` migration is a normalized copy of the verified PostgreSQL 16.13 Shared Core schema snapshot. It removes the `pg_dump` `\\restrict` markers and its session-only empty `search_path` directive; leaving the latter active prevents Prisma from finding its own migration table after applying the baseline. All schema objects are explicitly qualified, so removing that directive does not change the recreated structure. The baseline includes PostgreSQL functions, triggers, checks, indexes, and foreign keys that Prisma cannot fully represent. It is authoritative for recreating the legacy structure; `schema.prisma` is an application mapping, not a complete database definition.

The `20260826140000_add_user_external_identities` migration is additive and remains unapproved for the live database. It may be applied only to disposable databases until a separate live-migration approval.

Never run `prisma db push` or `prisma migrate dev` against an existing Shared Core database. Runtime application credentials must not own DDL privileges.
