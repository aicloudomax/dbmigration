# Export-first workflow (schema + data into the repo, then load)

This is the recommended two-phase workflow: **first extract everything from the
source database into files committed in the repo, then load those files into
Supabase.** It decouples the two halves so extraction can run wherever the
database is reachable, and gives you a reviewable, version-controlled snapshot of
exactly what will be loaded.

```
 SOURCE (Azure SQL, reachable from your network)         TARGET (Supabase)
 ┌───────────────────────────┐   commit    ┌───────────┐   load    ┌──────────┐
 │ dbmigrate export          │────────────►│  export/  │──────────►│ Supabase │
 │ tables+views+procs+funcs  │   to repo   │  *.sql    │ load-dump │  schemas │
 │ + data (COPY text)        │             │  *.tsv    │           │          │
 └───────────────────────────┘             └───────────┘           └──────────┘
```

## What gets exported

For each source database, `export/<db>/`:

| File | Contents |
| --- | --- |
| `manifest.json` | What was exported: target schemas, counts, per-table detail, review items |
| `01_schema.sql` | `CREATE SCHEMA` + `CREATE TABLE` + indexes for every source schema |
| `02_views.sql` | Views converted to Postgres `CREATE OR REPLACE VIEW` |
| `03_routines.sql` | Stored procedures + functions converted to PL/pgSQL |
| `04_foreign_keys.sql` | Foreign keys (applied last, after data) |
| `data/<schema>__<table>.tsv` | Table rows in Postgres `COPY` text format (`\N` = NULL) |

Every source database becomes its own set of target schemas named
`{db}_{schema}` — so `LiveBit`'s `dbo`, `aidd`, `diva`, `divaconfig`,
`divadim`, `Sandbox`, `zora` schemas become `livebit_dbo`, `livebit_aidd`,
`livebit_diva`, `livebit_divaconfig`, `livebit_divadim`, `livebit_sandbox`,
`livebit_zora`. Cross-schema references inside views are automatically
re-pointed at the matching target schema.

See a complete generated example in
[`examples/example-export/`](../examples/example-export/).

## Phase 1 — export (run where the database is reachable)

The `export` command needs **only the source DB credentials** — no Azure
discovery, no Supabase. Run it from your network, a jump box, or an Azure VM that
can reach `coe-index-db-server.database.windows.net:1433`.

```bash
# One-time
python -m pip install -e .
cp config/migration.example.yaml config/migration.yaml

# Credentials in the environment (NOT committed)
export SRC_MSSQL_USER='sadmin'
export SRC_MSSQL_PASSWORD='********'      # use a real, least-privilege login

# Export LiveBit (schema + data) into ./export/livebit/
dbmigrate export \
  --database LiveBit \
  --server-host coe-index-db-server.database.windows.net \
  --kind mssql \
  --out export

# Or schema/views/procs only, no data:
dbmigrate export -d LiveBit --server-host coe-index-db-server.database.windows.net --schema-only
```

Then commit the snapshot:

```bash
git add export/livebit
git commit -m "Export LiveBit schema + data"
git push
```

> **Firewall.** Azure SQL blocks connections by default. Add the IP of the
> machine running `export` under the server's **Networking → Firewall rules**.
>
> **Driver.** `export` uses `pymssql` (FreeTDS) with SQL authentication. If your
> org requires Entra ID / "Active Directory Default" auth instead of the
> `sadmin` SQL login, create a contained SQL user for the migration, or run from
> a host with an Azure identity and we can add an ODBC/AAD connection path.

## Phase 2 — load into Supabase

Once `export/livebit/` is in the repo, load it into the target project
(`mmbxootqppuvriodzetb`). Two ways:

**A. From a machine with Postgres (5432) access to Supabase:**

```bash
export SUPABASE_DB_PASSWORD='********'
dbmigrate load-dump export/livebit
```

`load-dump` applies `01_schema.sql`, streams each `.tsv` with `COPY`, then
applies `02_views.sql`, `03_routines.sql`, and `04_foreign_keys.sql`.

**B. Via the Supabase connector (no direct DB port needed):**
the DDL files (`01`–`04`) can be applied through the Supabase MCP tools
(`apply_migration` / `execute_sql`). Data in the `.tsv` files still needs a
`COPY`-capable path (method A) or conversion to `INSERT`s for smaller tables.

## Reviewing before load

Open `manifest.json` → `review_items` for anything the converter flagged
(e.g. a view using `TOP`, a procedure using a cursor). Fix those in the
`.sql` files before loading, or load and fix in Supabase afterward — the
flagged items are annotated inline with `-- REVIEW:` comments. See
[Stored-procedure conversion](06-stored-procedure-conversion.md).

## A note on data size in git

`.tsv` data files are committed to the repo, which is fine for small/medium
tables and gives you a reviewable snapshot. For very large tables, prefer
`--schema-only` for the committed snapshot and move data out-of-band (run the
full `migrate`/`load-dump` against a live target), or use Git LFS for the
`data/` directory.
