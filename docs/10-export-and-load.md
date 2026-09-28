# Export-first workflow (schema + data into the repo, then load)

This is the recommended two-phase workflow: **first extract everything from the
source database into files committed in the repo, then load those files into
Supabase.** It decouples the two halves so extraction can run wherever the
database is reachable (for LiveBit: a GitHub Actions runner), and gives you a
reviewable, version-controlled snapshot of exactly what will be loaded, **one
file per object** so it can be verified file by file.

```
 SOURCE (Azure SQL)                commit      REPO               load-dump       TARGET
 ┌──────────────────────────┐   ─────────►  ┌──────────────┐   ───────────►  ┌──────────┐
 │ dbmigrate export         │               │ export/<db>/ │  + report,      │ Supabase │
 │ tables, data, views,     │               │ one file per │    row-count    │ schemas  │
 │ procedures, functions    │               │ object       │    checks       │          │
 └──────────────────────────┘               └──────────────┘                 └──────────┘
```

## What gets exported

Each source database becomes `export/<db>/` (`<db>` lower-cased, e.g.
`export/livebit/`). In file names `<schema>` is always the **target** schema:

| Path | Contents |
| --- | --- |
| `manifest.json` | What was exported, counts, per-object details, warnings, review items and the exact **load order** |
| `00_schemas.sql` | `CREATE SCHEMA IF NOT EXISTS` for every target schema |
| `tables/<schema>__<table>.sql` | One per table: `CREATE TABLE` + its indexes, with `-- NOTE:` lines for lossy mappings |
| `data/<schema>__<table>.sql` | One per table: multi-row `INSERT` statements (`.tsv` with `--data-format copy`) |
| `data/<schema>__<table>.part0001.sql` … | The same, split into parts when a table's data would pass `--max-data-file-mb` |
| `sequences.sql` | Identity sequence resets (`SELECT setval(...)`), one statement per line, run after the data |
| `foreign_keys.sql` | Foreign keys (`ALTER TABLE ... ADD CONSTRAINT`), one statement per line, run after the data |
| `views/<schema>__<view>.sql` | One per view, converted to `CREATE OR REPLACE VIEW`, with `-- REVIEW` comments |
| `routines/<schema>__<name>.sql` | One per stored procedure **and** function, converted to PL/pgSQL, with `-- REVIEW` comments |
| `source/views/<schema>__<view>.sql` | The **original T-SQL** of each view, byte for byte (audit trail) |
| `source/routines/<schema>__<name>.sql` | The **original T-SQL** of each procedure/function, byte for byte |
| `.gitattributes` | `* -text`: git must never convert line endings in the dump (see [Data encoding](#data-encoding)) |

Every table has a data file, even an empty one (it then holds only a
`-- (no rows in ...)` comment; with `--data-format copy` it is an empty `.tsv`).
Output is sorted and deterministic: the same source produces the same files.

Every source schema becomes its own target schema named `{db}_{schema}`, so
LiveBit's `dbo`, `aidd`, `diva`, `divaconfig`, `divadim`, `Sandbox`, `zora`
schemas become `livebit_dbo`, `livebit_aidd`, `livebit_diva`,
`livebit_divaconfig`, `livebit_divadim`, `livebit_sandbox`, `livebit_zora`.
Cross-schema references in views and foreign keys are re-pointed at the
matching target schema.

A complete generated example (with a table split into parts) is in
[`examples/example-export/`](../examples/example-export/); regenerate it with
`python examples/generate_example.py`.

### manifest.json

```jsonc
{
  "database": "LiveBit", "server": "...", "kind": "azure_sql",
  "generated_at": "2026-09-28T18:00:00Z",          // UTC
  "data_format": "insert",                         // null for --schema-only
  "target_schemas": ["livebit_dbo", "livebit_divadim", "livebit_sandbox"],
  "counts": {"schemas": 3, "tables": 3, "views": 1, "procedures": 1, "functions": 0,
             "routines": 1, "rows": 44, "data_files": 4, "data_bytes": 2907},
  "tables": [{
    "source": "dbo.Customers", "target_schema": "livebit_dbo", "target_table": "customers",
    "columns": 10, "column_names": ["id", "name", "..."],
    "approx_source_rows": 4,        // from SQL Server's catalog, approximate
    "exported_rows": 4,             // rows actually written to the data files
    "table_file": "tables/livebit_dbo__customers.sql",
    "data_files": ["data/livebit_dbo__customers.sql"],
    "notes": ["column Photo: binary length not preserved (bytea is variable length)"]
  }],
  "views":    [{"source": "dbo.v_ActiveCustomers", "target": "livebit_dbo.v_activecustomers",
                "file": "views/...", "source_file": "source/views/...", "review_items": []}],
  "routines": [{"source": "dbo.usp_X", "target": "livebit_dbo.usp_x", "kind": "procedure",
                "converted": true, "file": "routines/...", "source_file": "source/routines/...",
                "review_items": ["manual: TOP n — rewrite as LIMIT n [TOP 10]"]}],
  "warnings": ["dbo.Customers: stripped 1 NUL character(s) from text values ..."],
  "review_items": ["routine dbo.usp_X: TOP n — rewrite as LIMIT n"],
  "load_order": ["00_schemas.sql", "tables/...", "data/...", "sequences.sql",
                 "foreign_keys.sql", "views/...", "routines/..."]
}
```

`load_order` lists every file in the order it must run: schemas, tables (with
indexes), all data (table by table, parts in order), sequence resets, foreign
keys, views (a view that reads another view comes after it), then routines.
`manifest.json` is written last, so if it exists the export completed.

## Data files and chunking

- **INSERT format** (`--data-format insert`, the default): each statement holds at
  most `migration.batch_size` rows (config, default 5000) **or** about 1 MB,
  whichever comes first. Easy to read, diff and run one file at a time.
- **COPY format** (`--data-format copy`): Postgres `COPY` text (`\N` = NULL);
  more compact and faster to load for very large tables.

Both formats are split with the same rule: a table's data goes to
`<schema>__<table>.sql` (or `.tsv`) while it fits under `--max-data-file-mb`
(default **45 MB**). A table that would pass the limit is written as
`.part0001`, `.part0002`, … and a new part starts before a file would pass the
limit, keeping every committed file far below GitHub's 100 MB per-file limit.
(A single INSERT statement is never split, so a file can only exceed the limit
when one row is larger than the limit.)

### Data encoding

Values are written so they load back **exactly**:

| Source value | Written as (INSERT) |
| --- | --- |
| `NULL` | `NULL` |
| `bit` (bool) | `TRUE` / `FALSE` |
| integers | as is |
| `decimal`/`numeric`/`money` | plain digits, never exponent notation (`12500.00`) |
| `float`/`real` | shortest exact form; NaN/±infinity as `'NaN'::float8`, `'Infinity'::float8`, `'-Infinity'::float8` |
| `varbinary`/`binary`/`image`/`rowversion` | `'\x<hex>'::bytea` |
| text | quoted, `'` doubled; backslashes, tabs, CR/LF and Unicode (emoji included) kept as is |
| date/time/`datetimeoffset`/`uniqueidentifier`/xml | quoted ISO text (a `datetimeoffset` literal carries its UTC offset, so the stored `timestamptz` instant is exact; the offset itself is not kept, as the table's notes say) |

Two things **cannot** be kept, and each is reported in `manifest.json` →
`warnings` per table:

- **NUL characters** (`\0`) in text: PostgreSQL `text` cannot store them, so they
  are removed (same in COPY files).
- **Unpaired UTF-16 surrogates** (invalid Unicode sometimes found in `nvarchar`):
  replaced with U+FFFD.

Text values often contain CR/LF, and the `source/` files are verbatim, so the
export ships a `.gitattributes` with `* -text`. Without it, git settings such
as `core.autocrlf` or `text=auto` could rewrite line endings inside committed
values. `load-dump` also reads files as raw bytes for the same reason.

## Phase 1: export (run where the database is reachable)

The `export` command needs **only the source DB credentials** (no Azure
discovery, no Supabase). For LiveBit this runs in GitHub Actions
(`.github/workflows/export-livebit.yml`), which also loads the result into a
throwaway Postgres 16 with `load-dump` before committing it. To run it by hand:

```bash
# One-time
python -m pip install -e .
cp config/migration.example.yaml config/migration.yaml

# Credentials in the environment (NOT committed)
export SRC_MSSQL_USER='<sql-login>'
export SRC_MSSQL_PASSWORD='********'      # use a least-privilege login

# Export LiveBit (schema + data) into ./export/livebit/
dbmigrate export \
  --database LiveBit \
  --server-host coe-index-db-server.database.windows.net \
  --kind mssql \
  --out export \
  --data-format insert \
  --max-data-file-mb 45

# Or schema/views/procs only, no data:
dbmigrate export -d LiveBit --server-host coe-index-db-server.database.windows.net --schema-only
```

At the end it prints the counts: target schemas, tables, views, procedures,
functions, rows, data files, data size, warnings and review items. Re-running
the export into the same directory first removes the files a previous export
generated there (`tables/`, `data/`, `views/`, `routines/`, `source/`, the
top-level `.sql` files, `manifest.json`, `load_report.json`, and the old
`01_`–`04_` files), so no stale file survives. Other files are left alone.

> **Firewall.** Azure SQL blocks connections by default. Add the IP of the
> machine running `export` under the server's **Networking → Firewall rules**.
>
> **Driver.** `export` uses `pymssql` (FreeTDS) with SQL authentication. If your
> org requires Entra ID / "Active Directory Default" auth instead of a SQL
> login, create a contained SQL user for the migration.

## Phase 2: load and verify (`load-dump`)

```bash
dbmigrate load-dump export/livebit \
  [--target-url postgresql://...] [-c config/migration.yaml] \
  [--stop-on-error] [--report export/livebit/load_report.json]
```

**Target**, first match wins: `--target-url`, then the `SUPABASE_DB_URL`
environment variable (also read from `.env`), then the config's `target`
(`db.<project-ref>.supabase.co` with `SUPABASE_DB_PASSWORD`). The config file is
only needed for that last case. The password is never printed or written: the
report shows the target as `postgresql://postgres:***@host/...`.

What it does:

1. Reads `manifest.json` and runs the files in `load_order`.
2. **Each file runs in its own transaction**: if any statement in a file fails,
   that whole file is rolled back (a data part is either fully loaded or not at
   all). `sequences.sql` and `foreign_keys.sql` run **statement by statement**,
   each in its own transaction, so one bad foreign key does not block the rest.
3. Every file and statement outcome is recorded with its error. Loading
   **continues past failures** unless `--stop-on-error` is given.
4. A view or routine that fails is retried after everything else has loaded
   (it may use a function or view that loads later); only its final outcome is
   recorded, with `attempts`.
5. Counts the rows of every target table and compares them with
   `exported_rows` from the manifest.
6. Writes the JSON report and prints a summary per kind (schemas, tables, data,
   sequences, foreign_keys, views, routines) plus every failure and mismatch.

**Exit code 1** if anything failed or any row count differs; 0 otherwise.

Load into **empty** target schemas. Loading the same dump twice makes the
data files fail on duplicate keys (tables without a primary key would get
duplicate rows, which the row-count check reports). To reload, drop the target
schemas first (`DROP SCHEMA livebit_dbo CASCADE; ...`).

### The load report

`<dump_dir>/load_report.json` by default (`--report PATH` to change):

```jsonc
{
  "dump_dir": "export/livebit",
  "database": "LiveBit",
  "target": "postgresql://postgres:***@db.<ref>.supabase.co:5432/postgres",
  "started_at": "...", "finished_at": "...",
  "ok": false,                         // true only with no failures and no mismatches
  "stopped_early": false,              // --stop-on-error hit a failure
  "totals": {"ok": 1520, "failed": 2, "row_mismatches": 0, "rows_loaded": 1843211},
  "by_kind": {"schemas": {"ok": 1, "failed": 0}, "tables": {...}, "data": {...},
              "sequences": {...}, "foreign_keys": {...}, "views": {...}, "routines": {...}},
  "failures": [
    {"file": "views/livebit_dbo__v_top_customers.sql",
     "statement": "CREATE OR REPLACE VIEW ... SELECT TOP 10 ...",
     "error": "syntax error at or near \"10\" ..."},
    {"file": "foreign_keys.sql",
     "statement": "ALTER TABLE \"livebit_dbo\".\"orders\" ADD CONSTRAINT ...",
     "error": "insert or update on table \"orders\" violates foreign key constraint ..."}
  ],
  "row_checks": [{"table": "livebit_dbo.customers", "source": "dbo.Customers",
                  "expected": 1200, "actual": 1200, "match": true}],
  "results": [{"file": "data/livebit_dbo__customers.part0001.sql", "kind": "data",
               "ok": true, "statements": 12, "rows": 60000}, "..."]
}
```

`results` has one entry per file (per statement for `sequences.sql` and
`foreign_keys.sql`); failed entries include `error`, the failing `statement`
(shortened), its `statement_index` within the file and the PostgreSQL
`sqlstate`.

### Without direct database access

The DDL files can also be applied through the Supabase MCP tools
(`apply_migration` / `execute_sql`) in `load_order`. The INSERT data files are
plain SQL too, but large ones are better loaded with `load-dump` from a machine
that can reach the database on port 5432.

## Reviewing before load

Open `manifest.json` → `review_items` (and each view/routine's own
`review_items`) for anything the converter flagged, such as a view using `TOP`
or a procedure using a cursor. Flagged items are annotated inline with
`-- REVIEW` comments in `views/` and `routines/`; the untouched original is next
to it in `source/`. Fix those `.sql` files before loading, or load and fix in
Supabase afterward. See [Stored-procedure conversion](06-stored-procedure-conversion.md).

## Data size in git

Data files are committed to the repo, split into parts of at most
`--max-data-file-mb` (45 MB by default). For very large databases, prefer
`--schema-only` for the committed snapshot and move data out of band (run
`load-dump` from the export artifact, or `migrate` against a live target), or
use Git LFS for the `data/` directory.
