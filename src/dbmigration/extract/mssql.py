"""Extract schema, routines, and data from an Azure SQL / MS SQL database.

Requires ``pymssql``. Connections are read-only in intent; the login supplied
should have no more than ``db_datareader`` + ``VIEW DEFINITION``.
"""

from __future__ import annotations

from collections.abc import Iterator
from typing import Any

from ..model import (
    Column,
    Database,
    ForeignKey,
    Index,
    Routine,
    SourceKind,
    Table,
)

# Reads column metadata for every user table in the database.
_COLUMNS_SQL = """
SELECT
    s.name  AS schema_name,
    t.name  AS table_name,
    c.name  AS column_name,
    ty.name AS data_type,
    c.is_nullable,
    c.max_length,
    c.precision,
    c.scale,
    c.is_identity,
    c.column_id,
    dc.definition AS default_definition
FROM sys.columns c
JOIN sys.tables t   ON t.object_id = c.object_id
JOIN sys.schemas s  ON s.schema_id = t.schema_id
JOIN sys.types ty   ON ty.user_type_id = c.user_type_id
LEFT JOIN sys.default_constraints dc ON dc.object_id = c.default_object_id
WHERE t.is_ms_shipped = 0
ORDER BY s.name, t.name, c.column_id;
"""

_PK_SQL = """
SELECT s.name AS schema_name, t.name AS table_name,
       i.name AS index_name, col.name AS column_name, ic.key_ordinal
FROM sys.indexes i
JOIN sys.tables t  ON t.object_id = i.object_id
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
JOIN sys.columns col ON col.object_id = ic.object_id AND col.column_id = ic.column_id
WHERE i.is_primary_key = 1 AND t.is_ms_shipped = 0
ORDER BY s.name, t.name, ic.key_ordinal;
"""

_INDEX_SQL = """
SELECT s.name AS schema_name, t.name AS table_name, i.name AS index_name,
       i.is_unique, col.name AS column_name, ic.key_ordinal
FROM sys.indexes i
JOIN sys.tables t  ON t.object_id = i.object_id
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
JOIN sys.columns col ON col.object_id = ic.object_id AND col.column_id = ic.column_id
WHERE i.is_primary_key = 0 AND i.type > 0 AND t.is_ms_shipped = 0
ORDER BY s.name, t.name, i.name, ic.key_ordinal;
"""

_FK_SQL = """
SELECT fk.name AS fk_name,
       ps.name AS schema_name, pt.name AS table_name, pc.name AS column_name,
       rs.name AS ref_schema, rt.name AS ref_table, rc.name AS ref_column,
       fk.delete_referential_action_desc AS on_delete
FROM sys.foreign_keys fk
JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id
JOIN sys.tables pt  ON pt.object_id = fk.parent_object_id
JOIN sys.schemas ps ON ps.schema_id = pt.schema_id
JOIN sys.columns pc ON pc.object_id = fkc.parent_object_id AND pc.column_id = fkc.parent_column_id
JOIN sys.tables rt  ON rt.object_id = fk.referenced_object_id
JOIN sys.schemas rs ON rs.schema_id = rt.schema_id
JOIN sys.columns rc ON rc.object_id = fkc.referenced_object_id AND rc.column_id = fkc.referenced_column_id
ORDER BY fk.name, fkc.constraint_column_id;
"""

_ROWCOUNT_SQL = """
SELECT s.name AS schema_name, t.name AS table_name, SUM(p.rows) AS row_count
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
WHERE t.is_ms_shipped = 0
GROUP BY s.name, t.name;
"""

_ROUTINES_SQL = """
SELECT s.name AS schema_name, o.name AS routine_name, o.type_desc AS kind,
       m.definition
FROM sys.sql_modules m
JOIN sys.objects o  ON o.object_id = m.object_id
JOIN sys.schemas s  ON s.schema_id = o.schema_id
WHERE o.type IN ('P', 'FN', 'IF', 'TF')  -- proc, scalar fn, inline/table fn
ORDER BY s.name, o.name;
"""


def connect(host: str, database: str, user: str, password: str, port: int = 1433):
    import pymssql  # imported lazily so the package installs without a live driver

    return pymssql.connect(
        server=host, user=user, password=password, database=database, port=port
    )


def _rows(cursor) -> Iterator[dict[str, Any]]:
    columns = [d[0] for d in cursor.description]
    for row in cursor:
        yield dict(zip(columns, row))


def extract_database(
    conn,
    *,
    subscription: str,
    server: str,
    database: str,
) -> Database:
    """Read the full structure (not data) of one MS SQL database into the IR."""
    db = Database(
        subscription=subscription,
        server=server,
        kind=SourceKind.AZURE_SQL,
        name=database,
    )
    tables: dict[tuple[str, str], Table] = {}

    cur = conn.cursor()
    cur.execute(_COLUMNS_SQL)
    for r in _rows(cur):
        key = (r["schema_name"], r["table_name"])
        table = tables.setdefault(key, Table(schema=r["schema_name"], name=r["table_name"]))
        table.columns.append(
            Column(
                name=r["column_name"],
                source_type=r["data_type"],
                nullable=bool(r["is_nullable"]),
                default=r["default_definition"],
                char_length=r["max_length"],
                numeric_precision=r["precision"],
                numeric_scale=r["scale"],
                is_identity=bool(r["is_identity"]),
                ordinal=int(r["column_id"]),
            )
        )

    _attach_primary_keys(conn, tables)
    _attach_indexes(conn, tables)
    _attach_foreign_keys(conn, tables)
    _attach_row_counts(conn, tables)

    db.tables = list(tables.values())
    db.routines = _extract_routines(conn)
    return db


def _attach_primary_keys(conn, tables: dict[tuple[str, str], Table]) -> None:
    cur = conn.cursor()
    cur.execute(_PK_SQL)
    pk: dict[tuple[str, str], Index] = {}
    for r in _rows(cur):
        key = (r["schema_name"], r["table_name"])
        idx = pk.setdefault(key, Index(name=r["index_name"], columns=[], unique=True, is_primary=True))
        idx.columns.append(r["column_name"])
    for key, idx in pk.items():
        if key in tables:
            tables[key].primary_key = idx


def _attach_indexes(conn, tables: dict[tuple[str, str], Table]) -> None:
    cur = conn.cursor()
    cur.execute(_INDEX_SQL)
    idxs: dict[tuple[str, str, str], Index] = {}
    for r in _rows(cur):
        ikey = (r["schema_name"], r["table_name"], r["index_name"])
        idx = idxs.setdefault(ikey, Index(name=r["index_name"], columns=[], unique=bool(r["is_unique"])))
        idx.columns.append(r["column_name"])
    for (schema, table, _), idx in idxs.items():
        tkey = (schema, table)
        if tkey in tables:
            tables[tkey].indexes.append(idx)


def _attach_foreign_keys(conn, tables: dict[tuple[str, str], Table]) -> None:
    cur = conn.cursor()
    cur.execute(_FK_SQL)
    fks: dict[str, ForeignKey] = {}
    owner: dict[str, tuple[str, str]] = {}
    for r in _rows(cur):
        fk = fks.get(r["fk_name"])
        if fk is None:
            fk = ForeignKey(
                name=r["fk_name"],
                columns=[],
                ref_schema=r["ref_schema"],
                ref_table=r["ref_table"],
                ref_columns=[],
                on_delete=_normalize_action(r["on_delete"]),
            )
            fks[r["fk_name"]] = fk
            owner[r["fk_name"]] = (r["schema_name"], r["table_name"])
        fk.columns.append(r["column_name"])
        fk.ref_columns.append(r["ref_column"])
    for name, fk in fks.items():
        tkey = owner[name]
        if tkey in tables:
            tables[tkey].foreign_keys.append(fk)


def _attach_row_counts(conn, tables: dict[tuple[str, str], Table]) -> None:
    cur = conn.cursor()
    cur.execute(_ROWCOUNT_SQL)
    for r in _rows(cur):
        key = (r["schema_name"], r["table_name"])
        if key in tables:
            tables[key].approx_row_count = int(r["row_count"] or 0)


def _extract_routines(conn) -> list[Routine]:
    cur = conn.cursor()
    cur.execute(_ROUTINES_SQL)
    out: list[Routine] = []
    for r in _rows(cur):
        kind = "procedure" if r["kind"] == "SQL_STORED_PROCEDURE" else "function"
        out.append(
            Routine(
                schema=r["schema_name"],
                name=r["routine_name"],
                kind=kind,
                language="tsql",
                definition=r["definition"] or "",
            )
        )
    return out


def _normalize_action(desc: str | None) -> str | None:
    if not desc:
        return None
    mapping = {
        "NO_ACTION": "NO ACTION",
        "CASCADE": "CASCADE",
        "SET_NULL": "SET NULL",
        "SET_DEFAULT": "SET DEFAULT",
    }
    return mapping.get(desc.upper())


def iter_table_rows(conn, table: Table, batch_size: int) -> Iterator[list[tuple]]:
    """Yield batches of rows for a table, in column-ordinal order."""
    ordered_cols = sorted(table.columns, key=lambda c: c.ordinal)
    col_list = ", ".join(f"[{c.name}]" for c in ordered_cols)
    cur = conn.cursor()
    cur.execute(f"SELECT {col_list} FROM [{table.schema}].[{table.name}]")
    while True:
        rows = cur.fetchmany(batch_size)
        if not rows:
            break
        yield [tuple(row) for row in rows]
