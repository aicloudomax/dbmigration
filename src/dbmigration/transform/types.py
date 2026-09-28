"""Map source column types to Postgres (Supabase) types.

Covers the SQL Server type system (the harder case) plus a light pass-through
for Azure PostgreSQL sources, which are already Postgres types.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import date as _date
from decimal import Decimal

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
    "sysname": "varchar",  # built-in alias of nvarchar(128)
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

    if base in {"char", "nchar", "varchar", "nvarchar", "sysname"}:
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
    elif base == "datetimeoffset":
        note = "datetimeoffset -> timestamptz: instant kept, original UTC offset not kept"
    elif base in {"sql_variant", "hierarchyid", "geography", "geometry"}:
        note = f"{base} has no Postgres equivalent; stored as text (review)"

    # datetime2/time/datetimeoffset default to 7 fractional digits (100ns); PG keeps 6.
    if base in {"datetime2", "time", "datetimeoffset"} and (
        col.numeric_scale is None or col.numeric_scale > 6
    ):
        rounding = "fractional seconds rounded to microseconds"
        note = f"{note}; {rounding}" if note else rounding

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


# --- column DEFAULT translation ---------------------------------------------

@dataclass
class DefaultTranslation:
    expr: str | None  # Postgres DEFAULT expression, or None for "no default"
    note: str | None = None  # set when the source default was dropped


_NUMERIC_LITERAL = re.compile(r"^(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$")
_STRING_LITERAL = re.compile(r"^[Nn]?'((?:[^']|'')*)'$", re.DOTALL)
_UUID_LITERAL = re.compile(
    r"^\{?[0-9a-fA-F]{8}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{12}\}?$"
)
_DATE_PART = r"(\d{4})-?(\d{2})-?(\d{2})"
_TIME_PART = r"(\d{1,2}):(\d{2})(?::(\d{2})(?:\.\d{1,7})?)?"
_OFFSET_PART = r"(?:\s?(?:Z|[+-]\d{2}(?::?\d{2})?))?"
_DATETIME_LITERAL = re.compile(rf"^{_DATE_PART}(?:[ T]{_TIME_PART}{_OFFSET_PART})?$")
_TIME_LITERAL = re.compile(rf"^{_TIME_PART}$")
_TYPE_LENGTH = re.compile(r"\((\d+)")

_NOW = "now()"
_UTC_NOW = "(now() at time zone 'utc')"
_UUID_FN = "gen_random_uuid()"
_MSSQL_FUNCTIONS: dict[str, str] = {
    "getdate()": _NOW,
    "sysdatetime()": _NOW,
    "sysdatetimeoffset()": _NOW,
    "current_timestamp": _NOW,
    "getutcdate()": _UTC_NOW,
    "sysutcdatetime()": _UTC_NOW,
    "newid()": _UUID_FN,
    "newsequentialid()": _UUID_FN,
}

# Postgres type -> coarse category used to decide whether a default is valid.
_CATEGORIES: dict[str, str] = {
    "boolean": "bool", "bool": "bool",
    "smallint": "number", "integer": "number", "int": "number", "bigint": "number",
    "int2": "number", "int4": "number", "int8": "number",
    "numeric": "number", "decimal": "number", "real": "number",
    "double precision": "number", "float4": "number", "float8": "number",
    "text": "string", "varchar": "string", "char": "string", "bpchar": "string",
    "character varying": "string", "character": "string",
    "uuid": "uuid",
    "date": "date",
    "time": "time", "time without time zone": "time",
    "timestamp": "timestamp", "timestamptz": "timestamp",
    "timestamp without time zone": "timestamp", "timestamp with time zone": "timestamp",
}


def _type_category(pg_type: str) -> str:
    base = re.sub(r"\(.*?\)", "", pg_type.lower()).strip()
    return _CATEGORIES.get(base, "other")


def _type_length(pg_type: str) -> int | None:
    m = _TYPE_LENGTH.search(pg_type)
    return int(m.group(1)) if m else None


def _matching_paren(expr: str) -> int:
    """Index of the ``)`` closing the ``(`` at position 0 (quote-aware), or -1."""
    depth = 0
    in_quote = False
    i = 0
    while i < len(expr):
        ch = expr[i]
        if in_quote:
            if ch == "'":
                if i + 1 < len(expr) and expr[i + 1] == "'":
                    i += 1  # doubled quote inside a literal
                else:
                    in_quote = False
        elif ch == "'":
            in_quote = True
        elif ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def strip_wrapping_parens(expr: str) -> str:
    """Remove any depth of parentheses that wrap the *whole* expression.

    ``((0))`` -> ``0`` but ``(a)+(b)`` is left alone (its outer parens are not
    a matched pair).
    """
    expr = expr.strip()
    while expr.startswith("(") and _matching_paren(expr) == len(expr) - 1:
        expr = expr[1:-1].strip()
    return expr


def _numeric_literal(expr: str) -> str | None:
    """Return a normalized signed numeric literal, or None. Handles ``-(1)``."""
    sign = ""
    if expr and expr[0] in "+-":
        sign = "-" if expr[0] == "-" else ""
        expr = strip_wrapping_parens(expr[1:])
    if _NUMERIC_LITERAL.match(expr):
        return f"{sign}{expr}"
    return None


def _valid_datetime(text: str, category: str) -> bool:
    if category == "time":
        m = _TIME_LITERAL.match(text)
        return bool(m) and _valid_time(m.group(1), m.group(2), m.group(3))
    m = _DATETIME_LITERAL.match(text)
    if not m:
        return False
    try:
        _date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
    except ValueError:
        return False
    return m.group(4) is None or _valid_time(m.group(4), m.group(5), m.group(6))


def _valid_time(hh: str, mm: str, ss: str | None) -> bool:
    return int(hh) < 24 and int(mm) < 60 and (ss is None or int(ss) < 60)


def _from_number(literal: str, category: str | None) -> str | None:
    if category in (None, "number"):
        return literal
    if category == "bool":  # SQL Server bit: 0 -> false, any other number -> true
        return "false" if Decimal(literal) == 0 else "true"
    if category == "string":
        return f"'{literal}'"
    return None


def _from_string(body: str, category: str | None) -> str | None:
    quoted = f"'{body}'"  # *body* keeps its doubled quotes, so this is valid SQL
    text = body.replace("''", "'").strip()
    if category in (None, "string"):
        return quoted
    if category == "bool":
        return {"1": "true", "true": "true", "0": "false", "false": "false"}.get(text.lower())
    if category == "number":
        return _numeric_literal(text)
    if category == "uuid":
        return quoted if _UUID_LITERAL.match(text) else None
    if category in ("date", "time", "timestamp"):
        return quoted if _valid_datetime(text, category) else None
    return None


def _from_function(expr: str, category: str | None, pg_type: str | None) -> str | None:
    if category is None:
        return expr
    if expr == _UUID_FN:
        if category == "uuid":
            return expr
        if category == "string":  # uuid -> text is an assignment cast; needs 36 chars
            length = _type_length(pg_type or "")
            return expr if length is None or length >= 36 else None
        return None
    return expr if category in ("date", "time", "timestamp") else None


def translate_default(
    default: str | None, source_is_postgres: bool, pg_type: str | None = None
) -> DefaultTranslation:
    """Translate a column DEFAULT to Postgres, checked against *pg_type*.

    Postgres sources pass through unchanged. For MS SQL only a known-safe subset
    is translated (literals, current-time and new-uuid functions); everything
    else, or anything that would not be valid for *pg_type*, is dropped with a
    note so that a ``CREATE TABLE`` can never fail because of a default. When
    *pg_type* is None the type-compatibility checks are skipped.
    """
    if default is None:
        return DefaultTranslation(None)
    if source_is_postgres:
        return DefaultTranslation(default)

    orig = default.strip()
    expr = strip_wrapping_parens(orig)
    category = _type_category(pg_type) if pg_type else None
    if not expr:
        return DefaultTranslation(None, f"default {orig} not translated; dropped")
    if expr.lower() == "null":
        return DefaultTranslation(None)

    translated: str | None
    number = _numeric_literal(expr)
    string = _STRING_LITERAL.match(expr)
    function = _MSSQL_FUNCTIONS.get(re.sub(r"\s+", "", expr.lower()))
    if number is not None:
        translated = _from_number(number, category)
    elif string is not None:
        translated = _from_string(string.group(1), category)
    elif function is not None:
        translated = _from_function(function, category, pg_type)
    else:
        return DefaultTranslation(None, f"default {orig} not translated; dropped")

    if translated is None:
        return DefaultTranslation(None, f"default {orig} not compatible with {pg_type}; dropped")
    return DefaultTranslation(translated)


def map_default(default: str | None, source_is_postgres: bool) -> str | None:
    """Translate a column DEFAULT to a Postgres expression (None = no default).

    Backward-compatible wrapper over :func:`translate_default` without a target
    type check; untranslatable MS SQL defaults yield None.
    """
    return translate_default(default, source_is_postgres, None).expr
