# Operational runbook

A step-by-step procedure for running a real migration into the Supabase project
`mmbxootqppuvriodzetb`.

## 0. Before you start

- [ ] Confirm you have a **recent backup** of every source database (this tool
      only reads sources, but you want a restore point regardless).
- [ ] Confirm the Supabase project is the intended target and that a
      **maintenance window** is agreed if apps point at it.
- [ ] Decide `on_existing_schema`: `error` (default, first run) vs `drop`
      (re-run/refresh).

## 1. Prepare access

- [ ] Azure: `az login`, or set the service-principal env vars. The identity
      needs `Reader` on the subscriptions in scope.
- [ ] Source logins: read-only login present on each SQL/PG server.
- [ ] Supabase: `SUPABASE_DB_PASSWORD` set; the role can `CREATE SCHEMA`.

## 2. Scope check

```bash
dbmigrate discover
```

- [ ] Review the list. Are all expected databases present? Any that should be
      excluded? Update `discovery.exclude_databases` or
      `discovery.subscriptions` accordingly.

## 3. Dry run

```bash
dbmigrate plan
```

- [ ] Open `output/plan_*.md`.
- [ ] Verify target schema names look right (no unexpected collisions).
- [ ] Scan the routine review counts — this is your conversion workload.
- [ ] Investigate any `error` rows now, before the real run.

## 4. Pilot one database (recommended)

Migrate a single, non-critical database first to validate end to end:

- [ ] Temporarily set `discovery.exclude_databases` to everything except one, or
      point `discovery.subscriptions` at a test subscription.
- [ ] `dbmigrate migrate`
- [ ] In Supabase SQL editor, confirm the schema, a few tables, row counts, and
      one converted function.

## 5. Full migration

```bash
dbmigrate migrate            # prompts for confirmation
# or, non-interactive:
dbmigrate migrate --yes
```

- [ ] Watch the log; the run reports each database as it goes.
- [ ] On completion, open `output/migrate_*.md`.

## 6. Verify

- [ ] **Row counts:** compare `approx_source_rows` vs `rows_copied` in the
      report. Spot-check exact counts on the largest / most critical tables.
- [ ] **Constraints:** confirm foreign keys applied (report `errors` empty).
- [ ] **Routines:** work the `converted_with_review` / `inventoried` list; finish
      each flagged procedure using
      [the conversion guide](06-stored-procedure-conversion.md).

## 7. Cut over

- [ ] Repoint applications at Supabase, schema by schema, using the new schema
      names (`<db>_<schema>`).
- [ ] Keep the JSON reports as the migration audit record.

## Re-running

The migration is re-runnable. To refresh a schema that already exists, set
`migration.on_existing_schema: drop` (destructive — it `DROP SCHEMA … CASCADE`
first). To add newly-discovered databases without touching existing ones, use
`skip`.

## Rollback

Because each source database lives in its own target schema, rolling back one
database is a single `DROP SCHEMA "<name>" CASCADE;` in Supabase — it does not
affect the others. Sources are never modified, so there is nothing to roll back
on the Azure side.
