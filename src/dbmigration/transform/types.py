"""Map source column types to Postgres (Supabase) types.

Covers the SQL Server type system (the harder case) plus a light pass-through
for Azure PostgreSQL sources, which are already Postgres types.
"""

from __future__ import annotations

from dataclasses import dataclass

from ..model import Column

# SQL Server base type -> Postgres type. Length/precision handled below.
_MSSQL_SCALAR: dict[str, str] = {
    "bigint": "bigint",
    "int": "integer",
    "smallint": "smallint",
    "tinyint": "smallint",  # PG has no unsigned 1-byte int; smallint is safe
    "bit": "boolean",
    "decimal": "numeric",
    "numeric": "numeric",
    "money": "numeric(19,4)",
    "smallmoney": "numeric(10,4)",
    "float": "double precision",
    "real": "real",
    "date": "date",
    "datetime": "timestamp",
    "datetime2": "timestamp",
    "smalldatetime": "timestamp",
    "datetimeoffset": "timestamptz",
    "time": "time",
    "char": "char",
    "varchar": "varchar",
    "text": "text",
    "nchar": "char",
    "nvarchar": "varchar",
    "ntext": "text",
    "binary": "bytea",
    "varbinary": "bytea",
    "image": "bytea",
    "uniqueidentifier": "uuid",
    "xml": "xml",
    "sql_variant": "text",
    "hierarchyid": "text",
    "geography": "text",
    "geometry": "text",
    "rowversion": "bytea",
    "timestamp": "bytea",  # SQL Server 'timestamp' is a row-version, not a time
}


@dataclass
class MappedType:
    postgres_type: str
    note: str | None = None  # populated when the mapping is lossy/approximate


def _mssql_type(col: Column) -> MappedType:
    base = col.source_type.lower().strip()
    if base not in _MSSQL_SCALAR:
        return MappedType("text", note=f"unknown MS SQL type '{col.source_type}' -> text")

    pg = _MSSQL_SCALAR[base]
    note = None

    if base in {"char", "nchar", "varchar", "nvarchar"}:
        length = col.char_length
        if length is None or length < 0:  # -1 == MAX
            pg = "text"
        else:
            pg = f"{pg}({length})"
    elif base in {"decimal", "numeric"}:
        precision = col.numeric_precision or 18
        scale = col.numeric_scale if col.numeric_scale is not None else 0
        pg = f"numeric({precision},{scale})"
    elif base in {"binary", "varbinary"}:
        note = "binary length not preserved (bytea is variable length)"
    elif base in {"tinyint"}:
        note = "tinyint widened to smallint"
    elif base in {"datetime", "datetime2", "smalldatetime"}:
        note = "mapped to timestamp (no time zone); use datetimeoffset for tz"

    return MappedType(pg, note=note)


def map_column_type(col: Column, source_is_postgres: bool) -> MappedType:
    """Return the Postgres type for *col*.

    For Postgres sources the type is already valid Postgres and passes through;
    length/precision are assumed to be embedded in ``source_type`` by the
    extractor (e.g. ``character varying(50)``, ``numeric(10,2)``).
    """
    if source_is_postgres:
        return MappedType(col.source_type)
    return _mssql_type(col)


def map_default(default: str | None, source_is_postgres: bool) -> str | None:
    """Translate common column DEFAULT expressions to Postgres equivalents."""
    if default is None:
        return None
    if source_is_postgres:
        return default

    expr = default.strip()
    # SQL Server wraps defaults in extra parens: ((0)) / (getdate()).
    while expr.startswith("(") and expr.endswith(")"):
        expr = expr[1:-1].strip()

    lowered = expr.lower()
    replacements = {
        "getdate()": "now()",
        "sysdatetime()": "now()",
        "getutcdate()": "(now() at time zone 'utc')",
        "sysutcdatetime()": "(now() at time zone 'utc')",
        "newid()": "gen_random_uuid()",
        "newsequentialid()": "gen_random_uuid()",
    }
    if lowered in replacements:
        return replacements[lowered]
    return expr
