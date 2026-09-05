# dbmigration documentation

The complete guide to migrating Azure MS SQL and Azure PostgreSQL databases into
a single Supabase Postgres database — and to the record the tool produces of
everything it moved.

## Contents

1. [Overview](01-overview.md) — what this is, the migration model, key decisions
2. [Architecture](02-architecture.md) — stages, modules, data flow, the IR
3. [Getting started](03-getting-started.md) — install, credentials, first run
4. [Configuration reference](04-configuration.md) — every key in `migration.yaml`
5. [Schema & type mapping](05-schema-mapping.md) — how types/DDL are translated
6. [Stored-procedure conversion](06-stored-procedure-conversion.md) — T-SQL → PL/pgSQL
7. [The migration report](07-migration-report.md) — the "what was transferred" record
8. [Operational runbook](08-runbook.md) — step-by-step for a real migration
9. [Troubleshooting](09-troubleshooting.md) — common failures and fixes

## The one-paragraph version

You point the tool at your Azure tenant. It finds every SQL Server and
PostgreSQL database across the subscriptions you allow, reads each one's
structure, data, and stored procedures, and rebuilds them inside **one**
Supabase database — with each source database placed in its **own schema**
(default naming `{db}_{schema}`). T-SQL procedures are converted to PL/pgSQL on
the way in, with anything risky flagged rather than guessed. When it finishes,
you get a report listing every database, schema, table, row count, and
conversion outcome.
