"""Live execution: connect to sources and the target and perform the migration.

Separated from :mod:`pipeline` (which holds the pure, testable planning logic)
so that the network-bound work is isolated. Everything here is driven by the
same :class:`Plan` and produces the same :class:`MigrationRecord`.
"""

from __future__ import annotations

from .config import Plan
from .extract import mssql, postgres
from .load.supabase_loader import SupabaseLoader
from .logging_utils import get_logger
from .model import Database, SourceKind
from .naming import sanitize_identifier
from .pipeline import (
    build_routine_conversions,
    build_schema_statements,
    build_view_conversions,
    new_record,
    resolve_schema_for,
    resolve_source_credentials,
)
from .report.record import DatabaseOutcome, MigrationRecord, TableOutcome

log = get_logger()


def _extractor(kind: SourceKind):
    return mssql if kind == SourceKind.AZURE_SQL else postgres


def connect_source(kind: SourceKind, host: str, database: str):
    user, password = resolve_source_credentials(kind)
    if not user or not password:
        raise RuntimeError(
            f"Missing source credentials for {kind.value}. Set the SRC_* env vars."
        )
    port = 1433 if kind == SourceKind.AZURE_SQL else 5432
    return _extractor(kind).connect(host, database, user, password, port)


def extract_source(kind: SourceKind, host: str, subscription: str, server: str, database: str) -> Database:
    conn = connect_source(kind, host, database)
    try:
        return _extractor(kind).extract_database(
            conn, subscription=subscription, server=server, database=database
        )
    finally:
        conn.close()


def migrate_one(
    plan: Plan,
    db: Database,
    host: str,
    loader: SupabaseLoader,
) -> DatabaseOutcome:
    """Apply schema, data, and routines for one already-extracted database."""
    primary_schema = (
        resolve_schema_for(plan, db, db.tables[0].schema)
        if db.tables
        else sanitize_identifier(db.name)
    )
    outcome = DatabaseOutcome(
        subscription=db.subscription,
        server=db.server,
        kind=db.kind.value,
        database=db.name,
        target_schema=primary_schema,
    )

    create_stmts, fk_stmts, table_schema = build_schema_statements(plan, db)

    # Handle pre-existing schemas per policy.
    for tschema in set(table_schema.values()):
        if loader.schema_exists(tschema):
            if plan.migration.on_existing_schema == "error":
                outcome.errors.append(f"Target schema '{tschema}' already exists.")
                return outcome
            if plan.migration.on_existing_schema == "drop":
                loader.drop_schema(tschema)

    if plan.migration.schema:
        loader.execute_all(create_stmts)

    # Data.
    for table in db.tables:
        tschema = table_schema[table.qualified]
        t_out = TableOutcome(
            source=table.qualified,
            target_schema=tschema,
            target_table=sanitize_identifier(table.name),
            columns=len(table.columns),
            approx_source_rows=table.approx_row_count,
            rows_copied=None,
            status="schema_only",
        )
        if plan.migration.data:
            try:
                conn = connect_source(db.kind, host, db.name)
                try:
                    batches = _extractor(db.kind).iter_table_rows(
                        conn, table, plan.migration.batch_size
                    )
                    written = loader.load_table_data(table, tschema, batches, db.kind)
                    t_out.rows_copied = written
                    t_out.status = "migrated"
                finally:
                    conn.close()
            except Exception as exc:  # noqa: BLE001 - recorded, not swallowed silently
                t_out.status = "error"
                t_out.notes.append(str(exc))
                log.error("Data load failed for %s: %s", table.qualified, exc)
                if plan.migration.fail_fast:
                    outcome.tables.append(t_out)
                    return outcome
        outcome.tables.append(t_out)

    # Views (after tables/data exist so they resolve).
    for view_outcome, ddl in build_view_conversions(plan, db):
        if plan.migration.schema and ddl is not None:
            try:
                loader.execute(ddl)
            except Exception as exc:  # noqa: BLE001
                view_outcome.status = "error"
                view_outcome.review_items.append(f"apply failed: {exc}")
        outcome.views.append(view_outcome)

    # Foreign keys after all tables exist.
    if plan.migration.schema and fk_stmts:
        try:
            loader.execute_all(fk_stmts)
        except Exception as exc:  # noqa: BLE001
            outcome.errors.append(f"Foreign keys: {exc}")

    # Routines.
    if plan.migration.routines:
        for routine_outcome, ddl in build_routine_conversions(plan, db):
            if ddl is not None:
                try:
                    loader.execute(ddl)
                except Exception as exc:  # noqa: BLE001
                    routine_outcome.status = "error"
                    routine_outcome.review_items.append(f"apply failed: {exc}")
            outcome.routines.append(routine_outcome)

    return outcome


def run_migration(plan: Plan, sources: list, *, dry_run: bool) -> MigrationRecord:
    """Execute the migration for a list of resolved sources.

    ``sources`` is a list of objects with attributes: subscription, server,
    server_host, kind, database (e.g. discovery.DiscoveredDatabase or
    pipeline.SourceTarget).
    """
    record = new_record(plan, dry_run=dry_run)

    if dry_run:
        from .pipeline import migrate_database_plan

        for s in sources:
            db = extract_source(s.kind, s.server_host, s.subscription, s.server, s.database)
            record.add_database(migrate_database_plan(plan, db))
        record.finish()
        return record

    with SupabaseLoader(plan.target.connection_url(), load_method=plan.migration.load_method) as loader:
        for s in sources:
            log.info("Migrating %s/%s/%s", s.subscription, s.server, s.database)
            db = extract_source(s.kind, s.server_host, s.subscription, s.server, s.database)
            record.add_database(migrate_one(plan, db, s.server_host, loader))
    record.finish()
    return record
