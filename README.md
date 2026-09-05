# dbmigration

Migrate **all** databases from **all your Azure subscriptions** — Azure SQL
(MS SQL) and Azure Database for PostgreSQL, including **stored procedures** — into
a **single Supabase Postgres database**, and produce a complete record of
everything that was transferred.

- **One target database, many schemas.** Every source database becomes its own
  schema in Supabase, named from a template (default `{db}_{schema}`, e.g. the
  `dbo` schema of a `Sales` database lands as `sales_dbo`).
- **Stored procedures converted inline.** T-SQL procedures/functions are
  converted to PL/pgSQL *as they transfer*, and anything non-mechanical is
  flagged for review — never silently mis-translated.
- **Everything is documented.** Each run writes a Markdown + JSON migration
  report: which subscription, which database, which schema, how many rows, and
  every conversion decision.

Target Supabase project: **`mmbxootqppuvriodzetb`**
(`https://supabase.com/dashboard/project/mmbxootqppuvriodzetb`).

---

## Quick start

```bash
# 1. Install
python -m pip install -e ".[dev]"

# 2. Configure
cp config/migration.example.yaml config/migration.yaml   # edit as needed
cp .env.example .env                                      # fill in secrets

# 3. See what would be migrated (no Azure writes, no Supabase writes)
dbmigrate discover

# 4. Dry run: extract structure + print the target plan, write a report
dbmigrate plan

# 5. Migrate for real
dbmigrate migrate
```

Convert a single stored procedure offline, without connecting to anything:

```bash
dbmigrate convert path/to/proc.sql --schema sales_dbo
```

## How it works

```
Azure subscriptions ──► discover ──► extract ──► transform ──► load ──► Supabase
   (SQL + Postgres)                   (schema,    (types +      (one DB,
                                       data,       T-SQL→        schema per
                                       routines)   PL/pgSQL)     source DB)
                                                        │
                                                        └──► migration report
                                                             (what was moved)
```

| Stage | Module | What it does |
| --- | --- | --- |
| Discover | `azure/discovery.py` | Enumerate subscriptions and their SQL/PG databases |
| Extract | `extract/mssql.py`, `extract/postgres.py` | Read schema, routines, and data into a neutral IR |
| Transform | `transform/` | Map types, generate DDL, convert T-SQL → PL/pgSQL |
| Load | `load/supabase_loader.py` | Create schemas/tables, COPY data, apply functions |
| Record | `report/record.py` | Write the Markdown + JSON migration report |

## Documentation

Full docs live in [`docs/`](docs/README.md):

- [Overview](docs/01-overview.md)
- [Architecture](docs/02-architecture.md)
- [Getting started](docs/03-getting-started.md)
- [Configuration reference](docs/04-configuration.md)
- [Schema & type mapping](docs/05-schema-mapping.md)
- [Stored-procedure conversion](docs/06-stored-procedure-conversion.md)
- [The migration report](docs/07-migration-report.md)
- [Operational runbook](docs/08-runbook.md)
- [Troubleshooting](docs/09-troubleshooting.md)

## Safety notes

- Discovery and extraction use **read-only** intent; grant the source logins the
  minimum (`db_datareader` + `VIEW DEFINITION` on MS SQL; read + `USAGE` on PG).
- Secrets come from `.env` / environment only. Nothing secret is written to the
  repo or the report.
- `migration.on_existing_schema` defaults to `error`, so a re-run never
  silently overwrites an already-migrated schema.

## Development

```bash
python -m pytest      # run the test suite
python -m ruff check  # lint
```
