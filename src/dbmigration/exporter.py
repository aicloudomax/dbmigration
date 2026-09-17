"""Export a source database to an on-disk dump that lives in the repo.

The dump is the "store schema and data in the repo first" step. It is:

  export/<db>/
    manifest.json            what was exported (counts, target schemas)
    01_schema.sql            CREATE SCHEMA + tables + indexes (all target schemas)
    02_views.sql             converted views
    03_routines.sql          converted procedures/functions
    04_foreign_keys.sql      foreign keys (applied last, after data)
    data/<target_schema>__<table>.tsv   table data in Postgres COPY text format

The SQL files are ordered so a reload is simply: run 01, load data, run 02/03,
then 04. `dbmigrate load-dump` replays exactly that.
"""

from __future__ import annotations

import json
from collections.abc import Callable, Iterator
from dataclasses import dataclass, field
from pathlib import Path

from .config import Plan
from .model import Database, Table
from .naming import sanitize_identifier
from .pipeline import build_schema_statements, schema_map_for
from .transform.tsql_to_plpgsql import convert_routine
from .transform.views import convert_view

# Callable that yields batches of rows for a table (wired to a live extractor by
# the CLI; a fake in tests). Returns an iterator of row-tuple lists.
DataReader = Callable[[Table], Iterator[list[tuple]]]


@dataclass
class ExportResult:
    database: str
    out_dir: Path
    schema_files: list[str] = field(default_factory=list)
    data_files: list[str] = field(default_factory=list)
    tables: int = 0
    views: int = 0
    routines: int = 0
    rows: int = 0
    review_items: list[str] = field(default_factory=list)


def encode_copy_value(value) -> str:
    r"""Encode one value into a Postgres COPY *text* field.

    NULL -> ``\N``; backslash/tab/newline/carriage-return are escaped; bytes are
    emitted as ``\x<hex>`` (then escaped). This round-trips through
    ``COPY ... FROM STDIN`` without an explicit format option.
    """
    if value is None:
        return r"\N"
    if isinstance(value, bool):
        return "t" if value else "f"
    if isinstance(value, (bytes, bytearray)):
        s = "\\x" + bytes(value).hex()
    else:
        s = str(value)
    return (
        s.replace("\\", "\\\\")
        .replace("\t", "\\t")
        .replace("\n", "\\n")
        .replace("\r", "\\r")
    )


def encode_copy_row(row: tuple) -> str:
    return "\t".join(encode_copy_value(v) for v in row) + "\n"


def export_database(
    plan: Plan,
    db: Database,
    out_root: Path,
    data_reader: DataReader | None = None,
) -> ExportResult:
    """Write the full on-disk dump for one database. Returns an ExportResult.

    ``data_reader`` yields row batches per table; pass ``None`` (or set
    ``plan.migration.data`` false) to export schema only.
    """
    db_dir = out_root / sanitize_identifier(db.name)
    (db_dir / "data").mkdir(parents=True, exist_ok=True)
    result = ExportResult(database=db.name, out_dir=db_dir)

    smap = schema_map_for(plan, db)

    # 01 — schema (CREATE SCHEMA + tables + indexes) and 04 — foreign keys.
    create_stmts, fk_stmts, table_schema = build_schema_statements(plan, db)
    _write_sql(db_dir / "01_schema.sql", create_stmts, header=f"Schema for {db.name}")
    result.schema_files.append("01_schema.sql")
    if fk_stmts:
        _write_sql(db_dir / "04_foreign_keys.sql", fk_stmts, header="Foreign keys (apply after data)")
        result.schema_files.append("04_foreign_keys.sql")
    result.tables = len(db.tables)

    # 02 — views.
    view_ddls: list[str] = []
    for view in db.views:
        tschema = smap[view.schema]
        conv = convert_view(view, tschema, smap, db.kind)
        view_ddls.append(conv.ddl)
        result.review_items += [f"view {view.qualified}: {f.message}" for f in conv.flags if f.severity == "manual"]
    if view_ddls:
        _write_sql(db_dir / "02_views.sql", view_ddls, header="Views")
        result.schema_files.append("02_views.sql")
    result.views = len(db.views)

    # 03 — routines.
    routine_ddls: list[str] = []
    for routine in db.routines:
        tschema = smap[routine.schema]
        conv = convert_routine(routine, tschema)
        routine_ddls.append(conv.ddl)
        result.review_items += [
            f"routine {routine.schema}.{routine.name}: {f.message}"
            for f in conv.flags
            if f.severity == "manual"
        ]
    if routine_ddls:
        _write_sql(db_dir / "03_routines.sql", routine_ddls, header="Procedures & functions")
        result.schema_files.append("03_routines.sql")
    result.routines = len(db.routines)

    # data — one COPY-text file per table.
    if plan.migration.data and data_reader is not None:
        for table in db.tables:
            tschema = table_schema[table.qualified]
            fname = f"{tschema}__{sanitize_identifier(table.name)}.tsv"
            path = db_dir / "data" / fname
            written = 0
            with path.open("w", encoding="utf-8", newline="") as fh:
                for batch in data_reader(table):
                    for row in batch:
                        fh.write(encode_copy_row(row))
                        written += 1
            result.data_files.append(f"data/{fname}")
            result.rows += written

    _write_manifest(db_dir / "manifest.json", plan, db, result, table_schema)
    return result


def _write_sql(path: Path, statements: list[str], *, header: str) -> None:
    lines = [
        "-- Generated by dbmigration. Do not edit by hand.",
        f"-- {header}",
        "",
    ]
    lines.extend(s if s.endswith(";") else s + ";" for s in statements)
    path.write_text("\n".join(lines) + "\n")


def _write_manifest(path: Path, plan: Plan, db: Database, result: ExportResult, table_schema) -> None:
    manifest = {
        "database": db.name,
        "subscription": db.subscription,
        "server": db.server,
        "kind": db.kind.value,
        "target_schemas": sorted(set(table_schema.values())),
        "counts": {
            "tables": result.tables,
            "views": result.views,
            "routines": result.routines,
            "rows": result.rows,
        },
        "tables": [
            {
                "source": t.qualified,
                "target_schema": table_schema.get(t.qualified),
                "target_table": sanitize_identifier(t.name),
                "columns": len(t.columns),
                "approx_rows": t.approx_row_count,
            }
            for t in db.tables
        ],
        "files": result.schema_files + result.data_files,
        "review_items": result.review_items,
    }
    path.write_text(json.dumps(manifest, indent=2) + "\n")
