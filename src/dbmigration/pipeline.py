"""Orchestrate the migration: discover → extract → transform → load → record.

The pipeline is credential- and network-bound at run time, but its control flow
is fully deterministic and unit-testable via the planning helpers. Each source
database is migrated into its own target schema in the single Supabase database.
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field

from .config import Plan
from .logging_utils import get_logger
from .model import Database, SourceKind, Table
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


@dataclass
class TableDDL:
    """Everything needed to create one table in the target, in apply order.

    ``create_sql`` and ``index_sqls`` run before the data load; ``fk_sqls`` and
    ``identity_reset_sqls`` (one line each) run after all data is loaded.
    """

    table: Table
    target_schema: str
    target_table: str
    create_sql: str  # one CREATE TABLE ... ; statement
    index_sqls: list[str] = field(default_factory=list)  # CREATE [UNIQUE] INDEX ... ;
    fk_sqls: list[str] = field(default_factory=list)  # ALTER TABLE ... FOREIGN KEY ... ;
    identity_reset_sqls: list[str] = field(default_factory=list)  # SELECT setval(...) ... ;
    notes: list[str] = field(default_factory=list)  # lossy mappings, dropped/skipped items


def schema_create_statements(plan: Plan, db: Database) -> list[str]:
    """CREATE SCHEMA for every target schema used by tables, views and routines."""
    schemas = sorted(set(schema_map_for(plan, db).values()))
    return [ddlgen.create_schema_ddl(s) for s in schemas]


def _reserved_relation_names(db: Database, smap: dict[str, str]) -> dict[str, set[str]]:
    """Relation names each target schema will hold besides our explicit indexes.

    Index names must avoid these: with ``IF NOT EXISTS`` a clash silently skips
    the later CREATE (possibly a whole table), instead of failing.
    """
    used: dict[str, set[str]] = {s: set() for s in smap.values()}
    for table in db.tables:
        names = used[smap[table.schema]]
        tname = sanitize_identifier(table.name)
        names.add(tname)
        if table.primary_key and table.primary_key.columns:
            names.add(sanitize_identifier(f"{tname}_pkey"))
        for col in table.columns:
            if col.is_identity:
                names.add(sanitize_identifier(f"{tname}_{sanitize_identifier(col.name)}_seq"))
    for view in db.views:
        used[smap[view.schema]].add(sanitize_identifier(view.name))
    return used


def build_table_statements(plan: Plan, db: Database) -> list[TableDDL]:
    """Return one :class:`TableDDL` per table, in ``db.tables`` order."""
    smap = schema_map_for(plan, db)
    by_key = {ddlgen.table_key(t.schema, t.name): t for t in db.tables}
    overrides = ddlgen.bigint_overrides(db.tables, db.kind)
    used_names = _reserved_relation_names(db, smap)
    owners: dict[tuple[str, str], str] = {}

    def ref_schema_for(source_schema: str) -> str:
        return resolve_schema_for(plan, db, source_schema)

    def lookup_table(schema: str, name: str) -> Table | None:
        return by_key.get(ddlgen.table_key(schema, name))

    result: list[TableDDL] = []
    for table in db.tables:
        tschema = smap[table.schema]
        ttable = sanitize_identifier(table.name)
        notes: list[str] = []
        owner = owners.setdefault((tschema, ttable), table.qualified)
        if owner != table.qualified:
            notes.append(
                f"target table {tschema}.{ttable} is also the target of {owner}; "
                "CREATE TABLE IF NOT EXISTS will skip this one (rename required)"
            )
        type_overrides = overrides.get((table.schema, table.name))
        create_sql = ddlgen.create_table_ddl(
            table, tschema, db.kind, type_overrides=type_overrides, notes=notes
        )
        index_sqls = ddlgen.create_index_ddls(
            table, tschema, db.kind,
            used_names=used_names[tschema], type_overrides=type_overrides, notes=notes,
        )
        fk_sqls = ddlgen.foreign_key_ddls(
            table, tschema, ref_schema_for,
            lookup_table=lookup_table, source_kind=db.kind, notes=notes,
        )
        identity_reset_sqls = ddlgen.identity_reset_ddls(
            table, tschema, db.kind, type_overrides=type_overrides
        )
        result.append(
            TableDDL(
                table=table,
                target_schema=tschema,
                target_table=ttable,
                create_sql=create_sql,
                index_sqls=index_sqls,
                fk_sqls=fk_sqls,
                identity_reset_sqls=identity_reset_sqls,
                notes=notes,
            )
        )
    return result


def build_schema_statements(
    plan: Plan, db: Database
) -> tuple[list[str], list[str], dict[str, str]]:
    """Return (create_statements, fk_statements, table_target_schema_map).

    ``create_statements`` is every CREATE SCHEMA, then each table's CREATE TABLE
    followed by its indexes. Foreign keys are returned separately so they can be
    applied after all tables (and their data) exist.
    """
    tables = build_table_statements(plan, db)
    create_stmts = schema_create_statements(plan, db)
    for t in tables:
        create_stmts.append(t.create_sql)
        create_stmts.extend(t.index_sqls)
    fk_stmts = [stmt for t in tables for stmt in t.fk_sqls]
    table_schema = {t.table.qualified: t.target_schema for t in tables}
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

    for tddl in build_table_statements(plan, db):
        table = tddl.table
        outcome.tables.append(
            TableOutcome(
                source=table.qualified,
                target_schema=tddl.target_schema,
                target_table=tddl.target_table,
                columns=len(table.columns),
                approx_source_rows=table.approx_row_count,
                rows_copied=None,
                status="schema_only" if not plan.migration.data else "planned",
                notes=list(tddl.notes),
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
