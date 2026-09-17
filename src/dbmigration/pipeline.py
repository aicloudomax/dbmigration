"""Orchestrate the migration: discover → extract → transform → load → record.

The pipeline is credential- and network-bound at run time, but its control flow
is fully deterministic and unit-testable via the planning helpers. Each source
database is migrated into its own target schema in the single Supabase database.
"""

from __future__ import annotations

import os
from dataclasses import dataclass

from .config import Plan
from .logging_utils import get_logger
from .model import Database, SourceKind
from .naming import sanitize_identifier, target_schema_name
from .report.record import (
    DatabaseOutcome,
    MigrationRecord,
    RoutineOutcome,
    TableOutcome,
)
from .transform import ddl as ddlgen
from .transform.tsql_to_plpgsql import convert_routine
from .transform.views import convert_view

log = get_logger()


@dataclass
class SourceTarget:
    """A resolved (source database) → (target schema) mapping before extraction."""

    subscription: str
    server: str
    server_host: str
    kind: SourceKind
    database: str


def plan_schema_names(
    plan: Plan, sources: list[SourceTarget]
) -> dict[tuple[str, str, str], str]:
    """Compute the target schema name for each source, aborting on collisions.

    Keyed by (subscription, server, database). Note: because the default
    template is ``{db}_{schema}`` and a source database may contain several
    schemas (dbo, etc.), the *final* per-schema name is derived at extraction
    time; here we validate the database-level portion for early collision
    detection using the literal database name.
    """
    seen: dict[str, tuple[str, str, str]] = {}
    result: dict[tuple[str, str, str], str] = {}
    for s in sources:
        # Database-level base name (schema placeholder left as the source's own).
        base = sanitize_identifier(s.database)
        key = (s.subscription, s.server, s.database)
        if base in seen and seen[base] != key and not plan.naming.auto_disambiguate:
            raise ValueError(
                f"Target schema base '{base}' collides between "
                f"{seen[base]} and {key}. Set naming.auto_disambiguate: true "
                f"or adjust naming.schema_template."
            )
        seen[base] = key
        result[key] = base
    return result


def resolve_schema_for(plan: Plan, db: Database, source_schema: str) -> str:
    return target_schema_name(
        plan.naming.schema_template,
        subscription=db.subscription,
        server=db.server,
        db=db.name,
        schema=source_schema,
    )


def schema_map_for(plan: Plan, db: Database) -> dict[str, str]:
    """Map every source schema in the database to its target schema name."""
    schemas = {t.schema for t in db.tables}
    schemas |= {v.schema for v in db.views}
    schemas |= {r.schema for r in db.routines}
    return {s: resolve_schema_for(plan, db, s) for s in schemas}


def build_view_conversions(plan: Plan, db: Database):
    """Yield (ViewOutcome, ddl_or_none) for each view in the database."""
    from .report.record import ViewOutcome

    smap = schema_map_for(plan, db)
    for view in db.views:
        tschema = smap[view.schema]
        conv = convert_view(view, tschema, smap, db.kind)
        review_items = [f"{f.severity}: {f.message}" for f in conv.flags]
        status = "created_with_review" if conv.needs_review else "created"
        outcome = ViewOutcome(
            source=view.qualified,
            target_schema=tschema,
            target_view=conv.view_name,
            status=status,
            review_items=review_items,
        )
        yield outcome, conv.ddl


def build_schema_statements(
    plan: Plan, db: Database
) -> tuple[list[str], list[str], dict[str, str]]:
    """Return (create_statements, fk_statements, table_target_schema_map).

    Tables and indexes are created first; foreign keys are returned separately so
    they can be applied after all tables exist.
    """
    create_stmts: list[str] = []
    fk_stmts: list[str] = []
    table_schema: dict[str, str] = {}
    schemas_created: set[str] = set()

    for table in db.tables:
        tschema = resolve_schema_for(plan, db, table.schema)
        table_schema[table.qualified] = tschema
        if tschema not in schemas_created:
            create_stmts.append(ddlgen.create_schema_ddl(tschema))
            schemas_created.add(tschema)
        create_stmts.append(ddlgen.create_table_ddl(table, tschema, db.kind))
        create_stmts.extend(ddlgen.create_index_ddls(table, tschema))

        for fk in table.foreign_keys:
            # Single-schema model: references must resolve within the same DB.
            fk_stmts.extend(ddlgen.foreign_key_ddls(table, tschema))
            break

    return create_stmts, fk_stmts, table_schema


def build_routine_conversions(plan: Plan, db: Database):
    """Yield (RoutineOutcome, ddl_or_none) for each routine in the database."""
    for routine in db.routines:
        tschema = resolve_schema_for(plan, db, routine.schema)
        result = convert_routine(routine, tschema)
        review_items = [f"{f.severity}: {f.message}" for f in result.flags]

        if not result.converted:
            status = "inventoried"
        elif result.needs_review:
            status = "converted_with_review"
        else:
            status = "converted"

        outcome = RoutineOutcome(
            source=f"{routine.schema}.{routine.name}",
            target_schema=tschema,
            target_function=result.routine_name,
            kind=routine.kind,
            status=status,
            review_items=review_items,
        )
        emit = result.ddl if (plan.routines.mode == "convert" and result.converted) else None
        yield outcome, emit


def migrate_database_plan(plan: Plan, db: Database) -> DatabaseOutcome:
    """Produce the DatabaseOutcome record for a database (no I/O to target).

    This is the deterministic core used by both dry runs and real runs; the real
    run additionally executes the statements and copies rows.
    """
    primary_schema = resolve_schema_for(plan, db, db.tables[0].schema) if db.tables else \
        sanitize_identifier(db.name)
    outcome = DatabaseOutcome(
        subscription=db.subscription,
        server=db.server,
        kind=db.kind.value,
        database=db.name,
        target_schema=primary_schema,
    )

    _, _, table_schema = build_schema_statements(plan, db)
    for table in db.tables:
        tschema = table_schema[table.qualified]
        outcome.tables.append(
            TableOutcome(
                source=table.qualified,
                target_schema=tschema,
                target_table=sanitize_identifier(table.name),
                columns=len(table.columns),
                approx_source_rows=table.approx_row_count,
                rows_copied=None,
                status="schema_only" if not plan.migration.data else "planned",
                notes=[],
            )
        )

    for view_outcome, _ in build_view_conversions(plan, db):
        outcome.views.append(view_outcome)

    if plan.migration.routines:
        for routine_outcome, _ in build_routine_conversions(plan, db):
            outcome.routines.append(routine_outcome)

    return outcome


def new_record(plan: Plan, *, dry_run: bool) -> MigrationRecord:
    return MigrationRecord(target=plan.target.safe_summary(), dry_run=dry_run)


def resolve_source_credentials(kind: SourceKind) -> tuple[str, str]:
    """Return (user, password) for a source kind from the environment."""
    if kind == SourceKind.AZURE_SQL:
        return os.environ.get("SRC_MSSQL_USER", ""), os.environ.get("SRC_MSSQL_PASSWORD", "")
    return os.environ.get("SRC_PG_USER", ""), os.environ.get("SRC_PG_PASSWORD", "")
