# Configuration reference

Configuration is a YAML file (default `config/migration.yaml`) plus secrets from
the environment (`.env`). Start from `config/migration.example.yaml`.

## `target`

The single Supabase database everything migrates into.

| Key | Default | Meaning |
| --- | --- | --- |
| `supabase_project_ref` | — (required) | Project ref from the dashboard URL |
| `database` | `postgres` | Target database name |
| `port` | `5432` | Target port |
| `sslmode` | `require` | Postgres SSL mode |

The connection string is assembled as
`postgresql://postgres:<SUPABASE_DB_PASSWORD>@db.<ref>.supabase.co:5432/postgres`
unless `SUPABASE_DB_URL` is set in the environment, which overrides everything.

## `naming`

How a source database maps to a target schema.

| Key | Default | Meaning |
| --- | --- | --- |
| `schema_template` | `{db}_{schema}` | Template for the target schema name |
| `auto_disambiguate` | `false` | If two sources collide, hash-suffix instead of aborting |

Template placeholders: `{subscription}`, `{server}`, `{db}`, `{schema}`. The
result is sanitized to a legal, lower-case Postgres identifier (≤63 chars).

Examples:

| Template | `Sales`/`dbo` becomes |
| --- | --- |
| `{db}_{schema}` | `sales_dbo` |
| `{db}` | `sales` |
| `{subscription}_{db}_{schema}` | `prod_sales_dbo` |

## `discovery`

Which Azure resources to scan.

| Key | Default | Meaning |
| --- | --- | --- |
| `subscriptions` | `[]` | Subscription ids/names to scan; empty = all visible |
| `include.azure_sql` | `true` | Include Azure SQL / MS SQL |
| `include.azure_postgres` | `true` | Include Azure Database for PostgreSQL |
| `exclude_databases` | `[]` | Databases to never migrate |

System databases (`master`, `tempdb`, `model`, `msdb`, `postgres`,
`azure_maintenance`, `azure_sys`) are **always** excluded, regardless of config.

## `migration`

What to move and how.

| Key | Default | Meaning |
| --- | --- | --- |
| `schema` | `true` | Migrate tables/keys/indexes/constraints |
| `data` | `true` | Copy table rows |
| `routines` | `true` | Migrate stored procedures/functions |
| `batch_size` | `5000` | Rows per read/insert batch |
| `load_method` | `copy` | `copy` (fast, uses `COPY`) or `insert` (portable) |
| `on_existing_schema` | `error` | `error`, `skip`, or `drop` if target schema exists |
| `fail_fast` | `false` | Stop the whole run on the first error |

`on_existing_schema`:

- `error` — refuse to touch a schema that already exists (safest; default).
- `skip` — leave the existing schema alone, migrate the rest.
- `drop` — `DROP SCHEMA … CASCADE` then recreate (destructive; for re-runs).

## `routines`

Stored-procedure handling.

| Key | Default | Meaning |
| --- | --- | --- |
| `mode` | `convert` | `convert` (create functions) or `report` (inventory only) |
| `keep_original_as_comment` | `true` | Keep original T-SQL as a comment in the body |

## `servers` (optional)

Per-server overrides, e.g. a different read-only login on a specific server:

```yaml
servers:
  - name: my-sqlserver.database.windows.net
    kind: azure_sql
    user: readonly_login
    password_env: SRC_MSSQL_PASSWORD
```

## `output`

| Key | Default | Meaning |
| --- | --- | --- |
| `dir` | `output` | Where run reports are written |

## Environment variables

See [Getting started → Credentials](03-getting-started.md#credentials). Secrets
are **only** read from the environment, never from the YAML file.
