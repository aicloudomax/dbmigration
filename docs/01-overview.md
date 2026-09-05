# Overview

## What dbmigration does

`dbmigration` consolidates database estates that are spread across Azure into a
single Supabase Postgres database. It handles two source engines:

- **Azure SQL / SQL Managed Instance** (Microsoft SQL Server / T-SQL)
- **Azure Database for PostgreSQL** (Flexible Server)

For every in-scope database it migrates:

- **Schema** — tables, columns, primary keys, indexes, foreign keys, defaults,
  identity/auto-increment columns.
- **Data** — all table rows, streamed in batches.
- **Routines** — stored procedures and functions, converted to PL/pgSQL.

## The migration model: one database, one schema per source

This is the most important design decision, and it is deliberate.

> Every source database is migrated into **one** target Supabase database.
> Each source database becomes a **schema** in that database.

Why:

- Supabase gives you a single Postgres database per project. Rather than needing
  one project per source database, all sources coexist in one project, isolated
  by schema.
- Schema names are derived from the source so they are predictable and
  collision-checked. The default template is `{db}_{schema}`:

  | Source database | Source schema | Target schema in Supabase |
  | --- | --- | --- |
  | `Sales` | `dbo` | `sales_dbo` |
  | `Inventory` | `dbo` | `inventory_dbo` |
  | `analytics` (PG) | `public` | `analytics_public` |

- If two different sources would produce the same target schema name, the run
  **aborts** by default (`naming.auto_disambiguate: false`) rather than silently
  merging two databases into one schema.

The template is configurable — see [Configuration](04-configuration.md#naming).

## What "convert as we transfer" means

Stored procedures are not dumped to a file for later. During the same run that
moves your tables and data, each T-SQL routine is parsed, mechanically rewritten
to PL/pgSQL, and (in `convert` mode) created in the target schema. Constructs
that cannot be translated safely — cursors, dynamic SQL, `MERGE`, temp tables,
`TRY/CATCH`, `TOP`, and so on — are **flagged** in the report and annotated
inline in the function body as `-- REVIEW:` comments, so a human finishes them
without hunting for what changed.

See [Stored-procedure conversion](06-stored-procedure-conversion.md).

## What you get at the end

Every run (including a dry run) writes a **migration report** in two formats:

- `output/<run>.md` — human-readable: tables of databases, schemas, row counts,
  and review items.
- `output/<run>.json` — machine-readable: the same data for auditing or
  dashboards.

This is the "documentation of what was transferred and the data" — the record
that answers, after the fact, exactly what moved and what still needs a human.

## What it does not do

- It does not migrate server-level objects (logins, jobs, linked servers).
- It does not migrate SQL Server Agent jobs or Azure-specific features.
- It does not attempt to run application-level data validation — it reports row
  counts, not business-rule equivalence.
- It is not a continuous-replication tool; it performs a one-time (re-runnable)
  bulk migration.
