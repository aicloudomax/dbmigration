# The migration report

Every run writes a record of **what was transferred** to the `output/`
directory, in two formats:

- `output/<prefix>_<timestamp>.md` — human-readable
- `output/<prefix>_<timestamp>.json` — machine-readable

`<prefix>` is `plan` for a dry run and `migrate` for a real run. This report is
the deliverable that documents the migration: it answers, without re-querying
any database, exactly what moved, where it went, how much data, and what still
needs a human.

## Markdown report

Structure:

```
# Database Migration Report
- Target, Mode (Applied / DRY RUN), Started, Finished

## Summary          ← counts: databases, tables, rows copied, routines, need-review

## <database>  →  schema `<target_schema>`
- Subscription, Server (kind)
### Tables          ← Source | Target table | Cols | Src rows | Rows copied | Status
### Routines        ← Source | Target function | Kind | Status | Review items
```

### Table statuses

| Status | Meaning |
| --- | --- |
| `migrated` | Schema created and rows copied |
| `schema_only` | Structure created; data disabled or deferred |
| `planned` | Dry run — would be migrated |
| `error` | Failed; the `notes` column/JSON carries the message |

### Routine statuses

See [Stored-procedure conversion](06-stored-procedure-conversion.md#reading-the-outcome):
`converted`, `converted_with_review`, `inventoried`, `error`.

## JSON report

The JSON is the full `MigrationRecord` serialized. Top-level shape:

```json
{
  "target": "db.mmbxootqppuvriodzetb.supabase.co/postgres",
  "started_at": "2026-09-05T21:00:00+00:00",
  "finished_at": "2026-09-05T21:12:33+00:00",
  "dry_run": false,
  "databases": [
    {
      "subscription": "Prod",
      "server": "sql-prod-01",
      "kind": "azure_sql",
      "database": "Sales",
      "target_schema": "sales_dbo",
      "tables": [
        {
          "source": "dbo.Customer",
          "target_schema": "sales_dbo",
          "target_table": "customer",
          "columns": 12,
          "approx_source_rows": 48213,
          "rows_copied": 48213,
          "status": "migrated",
          "notes": []
        }
      ],
      "routines": [
        {
          "source": "dbo.usp_UpsertCustomer",
          "target_schema": "sales_dbo",
          "target_function": "usp_upsertcustomer",
          "kind": "procedure",
          "status": "converted_with_review",
          "review_items": ["manual: TOP n — rewrite as LIMIT n"]
        }
      ],
      "errors": []
    }
  ]
}
```

## Using the report

- **Reconciliation.** Compare `approx_source_rows` to `rows_copied` per table.
  (Source counts are catalog estimates; treat small deltas as expected and
  re-count exact figures where it matters.)
- **Review queue.** Filter routines to `converted_with_review` / `inventoried`
  to get the exact list of procedures a human must finish, with the specific
  constructs named in `review_items`.
- **Audit trail.** Keep the JSON per run; it is a durable record of what the
  migration did and when.

## Programmatic access

```python
import json
from pathlib import Path

record = json.loads(Path("output/migrate_20260905T2100.json").read_text())
need_review = [
    (db["database"], r["source"], r["review_items"])
    for db in record["databases"]
    for r in db["routines"]
    if r["status"] in ("converted_with_review", "inventoried")
]
```
