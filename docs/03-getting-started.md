# Getting started

## Prerequisites

- Python 3.10+
- Network access from where you run the tool to:
  - Azure Resource Manager (for discovery)
  - Each source SQL Server (port 1433) and PostgreSQL server (port 5432)
  - The Supabase database host (port 5432)
- Credentials (see below)

## Install

```bash
python -m pip install -e ".[dev]"
```

This installs the `dbmigrate` command plus the drivers (`pymssql`, `psycopg`)
and the Azure management SDKs.

> **Driver note.** `pymssql` needs FreeTDS available on the host. On Debian/Ubuntu:
> `apt-get install freetds-dev`. On macOS: `brew install freetds`.

## Credentials

Copy `.env.example` to `.env` and fill it in. Nothing here is committed —
`.env` is git-ignored.

### Azure discovery

Discovery uses `DefaultAzureCredential`, so any of these work:

- **Interactive / dev:** run `az login` and leave the `AZURE_*` vars blank.
- **Service principal (CI):** set `AZURE_TENANT_ID`, `AZURE_CLIENT_ID`,
  `AZURE_CLIENT_SECRET`. The principal needs `Reader` on the subscriptions.

### Source databases

- `SRC_MSSQL_USER` / `SRC_MSSQL_PASSWORD` — a login that exists on the Azure SQL
  servers, with `db_datareader` and `VIEW DEFINITION` on each database.
- `SRC_PG_USER` / `SRC_PG_PASSWORD` — a Postgres login with read access and
  `USAGE` on the schemas.

You can override credentials per server in `migration.yaml` under `servers:`.

### Target Supabase

- `SUPABASE_DB_PASSWORD` — the database password from
  **Supabase → Project Settings → Database**.
- The host is assembled from the project ref in config
  (`db.mmbxootqppuvriodzetb.supabase.co`). To override entirely, set
  `SUPABASE_DB_URL`.

The target login must be able to `CREATE SCHEMA` — use the `postgres` role or a
role with equivalent privileges.

## Configure

```bash
cp config/migration.example.yaml config/migration.yaml
```

At minimum, confirm:

- `target.supabase_project_ref` is `mmbxootqppuvriodzetb`.
- `naming.schema_template` is how you want source databases named
  (default `{db}_{schema}`).
- `discovery.subscriptions` is empty (all subscriptions) or a specific list.

See the [Configuration reference](04-configuration.md) for every option.

## First run

Work up the ladder of commitment:

```bash
# 1. What is in scope? (Azure read-only)
dbmigrate discover

# 2. What would happen? (reads sources, writes nothing to Supabase)
dbmigrate plan

# 3. Do it.
dbmigrate migrate
```

After step 2 or 3, open the report in `output/` to see exactly what was (or
would be) transferred. See [The migration report](07-migration-report.md).

## Verifying a converted stored procedure quickly

You can convert a single `.sql` file with no connections at all — handy for
spot-checking the converter before a full run:

```bash
dbmigrate convert ./some_proc.sql --schema sales_dbo
```
