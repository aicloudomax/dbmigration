# Stored-procedure conversion (T-SQL → PL/pgSQL)

Stored procedures and functions are converted **inline during the migration**.
The converter (`transform/tsql_to_plpgsql.py`) is *mechanical and conservative*:
it rewrites what maps cleanly and **flags** everything else rather than guessing.
The guiding rule is **never silently produce wrong logic**.

## How it works

For each T-SQL routine the converter:

1. Parses the `CREATE PROC/FUNCTION` header and its parameters.
2. Maps parameter types (see below) and drops the `@` sigil (`@Id` → `id`).
3. Rewrites known scalar constructs (see the substitution table).
4. Scans for constructs it cannot safely translate and records a
   **manual review flag** for each, embedding it as a `-- REVIEW:` comment at the
   top of the function body.
5. Emits `CREATE OR REPLACE FUNCTION "<schema>"."<name>"(…) RETURNS void
   LANGUAGE plpgsql AS $function$ … $function$;`

Postgres source routines are re-emitted into the target schema unchanged (only
the function's schema-qualified name is rewritten).

## Automatic substitutions

| T-SQL | PL/pgSQL |
| --- | --- |
| `GETDATE()`, `SYSDATETIME()` | `now()` |
| `GETUTCDATE()` | `(now() at time zone 'utc')` |
| `NEWID()` | `gen_random_uuid()` |
| `ISNULL(a, b)` | `COALESCE(a, b)` |
| `LEN(x)` | `length(x)` |
| `DATALENGTH(x)` | `octet_length(x)` |
| `SCOPE_IDENTITY()` | `lastval()` |
| `@@ROWCOUNT` | `row_count` (via `GET DIAGNOSTICS`) |
| `@var` | `var` |

### Parameter type mapping

`int`→`integer`, `bigint`→`bigint`, `bit`→`boolean`,
`varchar/nvarchar/char/nchar/text`→`text`, `datetime/datetime2`→`timestamp`,
`decimal/numeric`→`numeric`, `money`→`numeric(19,4)`,
`uniqueidentifier`→`uuid`, `varbinary`→`bytea`, `xml`→`xml`. `OUTPUT`
parameters become `INOUT` and are flagged.

## Flagged for manual review

These constructs are detected and reported; the surrounding code is still
emitted so you have a starting point, but the flagged part needs a human:

| Detected | Why it needs review | Postgres direction |
| --- | --- | --- |
| `MERGE` | No direct equivalent | `INSERT … ON CONFLICT` |
| `EXEC(...)` / `sp_executesql` | Dynamic SQL | `EXECUTE … USING` |
| Cursors (`OPEN` / `FETCH NEXT`) | Different cursor model | `FOR … LOOP` or PL/pgSQL cursor |
| Temp tables (`#tmp`) | No `#` temp tables | `TEMP TABLE` or a CTE |
| `PIVOT` / `UNPIVOT` | Not in Postgres | `crosstab` or `CASE` aggregation |
| `TRY` / `CATCH` | Different error model | `BEGIN … EXCEPTION WHEN OTHERS` |
| `TOP n` | Different syntax | `LIMIT n` |
| `IDENTITY(...)` in a query | Sequence semantics differ | verify sequences |
| String `+` concatenation | `+` is numeric in PG | `\|\|` |

## Two modes

Set `routines.mode` in config:

- **`convert`** (default) — attempt conversion and create the function in the
  target. Functions with manual flags are still created (so the mechanical parts
  are in place) and marked `converted_with_review` in the report.
- **`report`** — do not create any functions; only inventory them and record
  conversion notes. Use this for an assessment pass before committing.

## Reading the outcome

In the [migration report](07-migration-report.md), each routine has a status:

| Status | Meaning |
| --- | --- |
| `converted` | Fully mechanical; no review items |
| `converted_with_review` | Created, but has `-- REVIEW:` items to finish |
| `inventoried` | Could not parse/convert; original preserved for manual port |
| `error` | Conversion succeeded but applying the DDL to the target failed |

## Example

Input:

```sql
CREATE PROCEDURE dbo.usp_UpsertCustomer
    @Id int, @Name nvarchar(100), @Email nvarchar(200) = NULL
AS
BEGIN
    IF @Id IS NULL SET @Id = SCOPE_IDENTITY();
    SELECT TOP 5 * FROM Customers WHERE Name = @Name;
    UPDATE Customers SET Email = ISNULL(@Email, Email), UpdatedAt = GETDATE() WHERE Id = @Id;
END
```

Output (abridged):

```sql
CREATE OR REPLACE FUNCTION "sales_dbo"."usp_upsertcustomer"(id integer, name text, email text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $function$
BEGIN
    -- REVIEW (manual): TOP n — rewrite as LIMIT n  [TOP 5]
    IF id IS NULL THEN id := lastval(); END IF;
    SELECT * FROM Customers WHERE Name = name;   -- TOP removed, add LIMIT 5
    UPDATE Customers SET Email = COALESCE(email, Email), UpdatedAt = now() WHERE Id = id;
END;
$function$;
```

`GETDATE`, `ISNULL`, `SCOPE_IDENTITY`, and the `@` sigils are handled
automatically; `TOP 5` is flagged for you to turn into `LIMIT 5`.
