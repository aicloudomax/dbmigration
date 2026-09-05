# Architecture

## Pipeline stages

```
 ┌───────────┐   ┌──────────┐   ┌────────────┐   ┌────────┐   ┌──────────┐
 │  discover │──►│  extract │──►│ transform  │──►│  load  │──►│  record  │
 └───────────┘   └──────────┘   └────────────┘   └────────┘   └──────────┘
   Azure ARM       source          types +          Supabase     Markdown +
   subscriptions   catalogs        DDL + T-SQL       (one DB)     JSON report
   + databases     → neutral IR    → PL/pgSQL
```

Each stage is a separate module so it can be tested and reasoned about in
isolation. Planning logic (pure, deterministic) is kept apart from the
network-bound execution.

## Modules

| Module | Responsibility |
| --- | --- |
| `config.py` | Parse and validate `migration.yaml` + environment into a `Plan` |
| `model.py` | The provider-neutral intermediate representation (IR) |
| `naming.py` | Derive and sanitize target schema/identifier names |
| `azure/discovery.py` | Enumerate subscriptions, servers, and databases |
| `extract/mssql.py` | Read MS SQL catalogs + rows into the IR |
| `extract/postgres.py` | Read Postgres catalogs + rows into the IR |
| `transform/types.py` | Map source column types → Postgres types |
| `transform/ddl.py` | Generate `CREATE SCHEMA/TABLE/INDEX` + FK DDL |
| `transform/tsql_to_plpgsql.py` | Convert T-SQL routines → PL/pgSQL |
| `load/supabase_loader.py` | Apply DDL, COPY/INSERT data, create functions |
| `pipeline.py` | Pure planning: map sources → schemas, build statements |
| `runner.py` | Live execution: connect, extract, load, record |
| `report/record.py` | Accumulate and serialize the migration record |
| `cli.py` | `discover` / `plan` / `migrate` / `convert` commands |

## The intermediate representation (IR)

Both extractors populate the same dataclasses in `model.py`:

```
Database
 ├─ subscription, server, kind (azure_sql | azure_postgres), name
 ├─ tables: [ Table(schema, name, columns[], primary_key, indexes[], foreign_keys[], approx_row_count) ]
 └─ routines: [ Routine(schema, name, kind, language, definition) ]
```

Because everything downstream of extraction consumes the IR, the transform and
load layers contain **no** provider-specific branching beyond a single
`source_is_postgres` flag. Adding a new source engine means writing one new
extractor, not touching the rest of the pipeline.

## Pure planning vs. live execution

- `pipeline.py` contains functions that take a `Plan` + IR and return statements
  and outcome records **without any I/O**. These are covered by unit tests
  (`tests/test_pipeline_and_report.py`) and drive the `plan` (dry-run) command.
- `runner.py` is the only place that opens connections and executes statements.
  A dry run calls the planning functions and skips `runner`'s write paths.

This split is why `dbmigrate plan` can show you a faithful preview: it runs the
exact same schema/routine planning code that `migrate` runs, minus the writes.

## Ordering guarantees

Within a database, statements are applied in a safe order:

1. `CREATE SCHEMA IF NOT EXISTS`
2. `CREATE TABLE` + `CREATE INDEX` for every table
3. Data load (COPY or batched INSERT)
4. `ALTER TABLE … ADD FOREIGN KEY` — applied only after all tables exist, so
   referenced tables are already present
5. `CREATE OR REPLACE FUNCTION` for each converted routine

Foreign keys that reference a *different* source database are not expressible in
the single-schema model and are skipped and noted in the report.
