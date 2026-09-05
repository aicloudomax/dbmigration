# Troubleshooting

## Install / drivers

**`pymssql` fails to build or import.**
It needs FreeTDS. Debian/Ubuntu: `apt-get install freetds-dev`. macOS:
`brew install freetds`. Then reinstall: `pip install --force-reinstall pymssql`.

**`psycopg` import error.**
Install the binary build: it is already pinned as `psycopg[binary]`. If you use
a source build, ensure `libpq` is present.

## Discovery

**`dbmigrate discover` returns nothing.**
- The credential can't see any subscriptions. Run `az account list` to confirm,
  or check the service principal has `Reader`.
- `discovery.subscriptions` may list ids/names that don't match. Leave it empty
  to scan everything.

**`DefaultAzureCredential` authentication errors.**
Either run `az login`, or set `AZURE_TENANT_ID` / `AZURE_CLIENT_ID` /
`AZURE_CLIENT_SECRET`. In CI, the interactive browser credential is disabled.

**A PostgreSQL server isn't listed.**
Discovery targets Azure Database for PostgreSQL **Flexible Server**. Single
Server (legacy) is retired; migrate it to Flexible Server or extract it via a
manual `servers:` entry.

## Source connection

**Login timeout / cannot connect to a source server.**
- Add your runner's IP to the server firewall (Azure SQL: "Networking"; PG:
  firewall rules).
- Azure SQL requires an encrypted connection; `pymssql` negotiates TLS via
  FreeTDS — ensure FreeTDS is recent.

**`Missing source credentials for azure_sql`.**
Set `SRC_MSSQL_USER` / `SRC_MSSQL_PASSWORD` (or the PG pair) in `.env`.

**Permission denied reading definitions.**
The login needs `VIEW DEFINITION` (MS SQL) to read stored-procedure bodies, and
read access to the catalogs.

## Target (Supabase)

**`SUPABASE_DB_PASSWORD is not set`.**
Set it in `.env`, or set `SUPABASE_DB_URL` to a full connection string.

**`permission denied for database` / cannot `CREATE SCHEMA`.**
Use the `postgres` role or a role granted `CREATE` on the database.

**`Target schema '<x>' already exists`.**
Expected with `on_existing_schema: error`. Choose `skip` (leave it) or `drop`
(recreate — destructive) for a re-run.

**SSL required.**
Supabase requires SSL; the tool sets `sslmode=require` by default. Don't
override it to `disable`.

## Data load

**`COPY` fails on a specific type.**
Switch that run to `migration.load_method: insert` for more permissive type
handling, or check the column's mapping in
[Schema & type mapping](05-schema-mapping.md). The failing table is recorded
with `status: error` and the message in `notes` — the rest of the run continues
unless `fail_fast: true`.

**Row counts don't match exactly.**
`approx_source_rows` comes from catalog statistics and can lag reality. Re-count
exactly (`SELECT count(*)`) on both sides for tables where precision matters.

## Foreign keys

**A foreign key didn't apply (listed under `errors`).**
Usually a cross-database reference, which the single-schema model can't express,
or a referenced row that violates the constraint. Reconcile the data, then add
the constraint manually.

## Routines

**A procedure is `converted_with_review`.**
That's by design — open the created function in Supabase and resolve each
`-- REVIEW:` comment. See
[Stored-procedure conversion](06-stored-procedure-conversion.md).

**A procedure is `inventoried` (not converted).**
The converter couldn't parse the header. The original T-SQL is preserved as a
comment; port it manually.

## Getting more detail

Reports are the source of truth: `output/*.md` for humans, `output/*.json` for
scripts. For live logs, the CLI prints per-database progress; failures are
logged with the table/routine name.
