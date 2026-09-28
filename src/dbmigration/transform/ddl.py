"""Generate Postgres DDL for a source table, targeting a specific schema.

Everything emitted here is meant to execute cleanly against real production
metadata: anything that cannot be reproduced safely (untranslatable defaults,
xml/spatial indexes, foreign keys to tables outside the database) is left out
and explained in a note instead of failing the statement.
"""

from __future__ import annotations

import re
from collections.abc import Callable
from dataclasses import dataclass, field

from ..model import Column, Index, SourceKind, Table
from ..naming import quote_ident, sanitize_identifier
from .types import map_column_type, translate_default

# Postgres indexes accept at most 32 columns (INDEX_MAX_KEYS).
MAX_INDEX_COLUMNS = 32

_INTEGER_TYPES = {"smallint", "integer", "bigint", "int", "int2", "int4", "int8"}
_NUMERIC_SCALE0 = re.compile(r"^(?:numeric|decimal)\(\s*\d+\s*,\s*0\s*\)$")
# MS SQL large-object types can never be index KEY columns, so when one shows up
# in an index's column list it is an INCLUDE column and can be left out.
_MSSQL_LOB_TYPES = {"text", "ntext", "image"}
_MSSQL_MAX_TYPES = {"varchar", "nvarchar", "varbinary"}
_MSSQL_SPATIAL_TYPES = {"geography", "geometry"}
_FK_ACTIONS = {"NO ACTION", "RESTRICT", "CASCADE", "SET NULL", "SET DEFAULT"}

# (source schema, source table) -> {source column name: forced Postgres type}
TypeOverrides = dict[tuple[str, str], dict[str, str]]
TableLookup = Callable[[str, str], "Table | None"]


@dataclass
class ColumnSpec:
    """The resolved target definition of one source column."""

    column: Column
    name: str  # sanitized target column name
    pg_type: str
    identity: bool = False
    default: str | None = None
    notes: list[str] = field(default_factory=list)


def table_key(schema: str, name: str) -> tuple[str, str]:
    """Case-insensitive lookup key for a source table."""
    return schema.casefold(), name.casefold()


def unique_name(base: str, used: set[str]) -> str:
    """Return *base*, or *base*_2, _3 ... (sanitized), unused in *used*; record it."""
    name, n = base, 2
    while name in used:
        name = sanitize_identifier(f"{base}_{n}")
        n += 1
    used.add(name)
    return name


def _base_type(pg_type: str) -> str:
    return pg_type.split("(", 1)[0].strip().lower()


def _sql_literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def _qualified(schema: str, table: Table) -> str:
    return f"{quote_ident(schema)}.{quote_ident(sanitize_identifier(table.name))}"


def _find_column(table: Table, name: str) -> Column | None:
    folded = name.casefold()
    return next((c for c in table.columns if c.name.casefold() == folded), None)


def create_schema_ddl(schema: str) -> str:
    return f"CREATE SCHEMA IF NOT EXISTS {quote_ident(schema)};"


def plan_columns(
    table: Table, source_kind: SourceKind, type_overrides: dict[str, str] | None = None
) -> list[ColumnSpec]:
    """Resolve type, identity and default for every column, in ordinal order."""
    source_is_pg = source_kind == SourceKind.AZURE_POSTGRES
    overrides = type_overrides or {}
    specs: list[ColumnSpec] = []
    for col in sorted(table.columns, key=lambda c: c.ordinal):
        mapped = map_column_type(col, source_is_pg)
        spec = ColumnSpec(col, sanitize_identifier(col.name), mapped.postgres_type)
        if mapped.note:
            spec.notes.append(mapped.note)
        if getattr(col, "is_computed", False):
            spec.notes.append("computed column created as a plain column (values copied)")
        forced = overrides.get(col.name)
        if forced and forced != spec.pg_type:
            spec.notes.append(
                f"{spec.pg_type} -> {forced} to match a bigint identity across a foreign key"
            )
            spec.pg_type = forced

        if col.is_identity:
            if _base_type(spec.pg_type) in _INTEGER_TYPES:
                spec.identity = True
            elif _NUMERIC_SCALE0.match(spec.pg_type):
                spec.notes.append(
                    f"identity {spec.pg_type} -> bigint (Postgres identity needs an integer type)"
                )
                spec.pg_type = "bigint"
                spec.identity = True
            else:
                spec.notes.append(
                    f"identity on {spec.pg_type} not supported; created without identity"
                )

        if not spec.identity:
            translated = translate_default(col.default, source_is_pg, spec.pg_type)
            spec.default = translated.expr
            if translated.note:
                spec.notes.append(translated.note)
        specs.append(spec)
    return specs


def create_table_ddl(
    table: Table,
    target_schema: str,
    source_kind: SourceKind,
    *,
    type_overrides: dict[str, str] | None = None,
    notes: list[str] | None = None,
) -> str:
    """Return a CREATE TABLE statement for *table* inside *target_schema*.

    Column-level notes (lossy types, dropped defaults, identity changes) are
    appended to *notes* when given.
    """
    lines: list[str] = []
    for spec in plan_columns(table, source_kind, type_overrides):
        pieces = [f"  {quote_ident(spec.name)} {spec.pg_type}"]
        if spec.identity:
            # Preserve auto-increment semantics; BY DEFAULT lets the load insert ids.
            pieces.append("GENERATED BY DEFAULT AS IDENTITY")
        elif spec.default is not None:
            pieces.append(f"DEFAULT {spec.default}")
        if not spec.column.nullable:
            pieces.append("NOT NULL")
        lines.append(" ".join(pieces))
        if notes is not None:
            notes.extend(f"column {spec.column.name}: {n}" for n in spec.notes)

    if table.primary_key and table.primary_key.columns:
        pk_cols = ", ".join(quote_ident(sanitize_identifier(c)) for c in table.primary_key.columns)
        lines.append(f"  PRIMARY KEY ({pk_cols})")

    body = ",\n".join(lines)
    return f"CREATE TABLE IF NOT EXISTS {_qualified(target_schema, table)} (\n{body}\n);"


def identity_reset_ddls(
    table: Table,
    target_schema: str,
    source_kind: SourceKind,
    *,
    type_overrides: dict[str, str] | None = None,
) -> list[str]:
    """Return one ``SELECT setval(...)`` per identity column (run after the data load)."""
    qualified = _qualified(target_schema, table)
    ddls: list[str] = []
    for spec in plan_columns(table, source_kind, type_overrides):
        if not spec.identity:
            continue
        col = quote_ident(spec.name)
        ddls.append(
            f"SELECT setval(pg_get_serial_sequence({_sql_literal(qualified)}, "
            f"{_sql_literal(spec.name)}), COALESCE(MAX({col}), 1), MAX({col}) IS NOT NULL) "
            f"FROM {qualified};"
        )
    return ddls


def plan_index_columns(
    idx: Index, specs: list[ColumnSpec], source_kind: SourceKind
) -> tuple[list[str] | None, str | None]:
    """Return (target key columns or None if the index is skipped, note)."""
    by_name = {s.column.name.casefold(): s for s in specs}
    mssql = source_kind == SourceKind.AZURE_SQL
    cols: list[str] = []
    left_out: list[str] = []
    for name in idx.columns:
        spec = by_name.get(name.casefold())
        if spec is None:
            return None, f"index {idx.name} skipped: column {name} not found"
        if _base_type(spec.pg_type) == "xml":
            return None, f"index {idx.name} skipped: column {name} is xml (no btree operator class)"
        source_type = spec.column.source_type.lower().strip()
        if mssql and source_type in _MSSQL_SPATIAL_TYPES:
            return None, f"index {idx.name} skipped: spatial column {name} has no btree equivalent"
        if mssql and (
            source_type in _MSSQL_LOB_TYPES
            or (source_type in _MSSQL_MAX_TYPES and spec.column.char_length == -1)
        ):
            left_out.append(name)
            continue
        cols.append(spec.name)

    if not cols:
        return None, f"index {idx.name} skipped: no indexable key columns"
    if len(cols) > MAX_INDEX_COLUMNS:
        return None, (
            f"index {idx.name} skipped: {len(cols)} columns exceeds the Postgres limit "
            f"of {MAX_INDEX_COLUMNS}"
        )
    note = None
    if left_out:
        note = (
            f"index {idx.name}: large-object column(s) {', '.join(left_out)} left out "
            "(INCLUDE-only in MS SQL)"
        )
    return cols, note


def create_index_ddls(
    table: Table,
    target_schema: str,
    source_kind: SourceKind = SourceKind.AZURE_SQL,
    *,
    used_names: set[str] | None = None,
    type_overrides: dict[str, str] | None = None,
    notes: list[str] | None = None,
) -> list[str]:
    """Return CREATE [UNIQUE] INDEX statements for non-primary indexes.

    *used_names* holds the relation names already taken in the target schema;
    index names are made unique against it (and added to it), because a clash
    would make ``CREATE ... IF NOT EXISTS`` silently skip an object.
    """
    used = used_names if used_names is not None else set()
    specs = plan_columns(table, source_kind, type_overrides)
    qualified = _qualified(target_schema, table)
    ddls: list[str] = []
    for idx in table.indexes:
        if idx.is_primary:
            continue
        cols, note = plan_index_columns(idx, specs, source_kind)
        if note and notes is not None:
            notes.append(note)
        if cols is None:
            continue
        idx_name = unique_name(sanitize_identifier(f"{table.name}_{idx.name}"), used)
        unique = "UNIQUE " if idx.unique else ""
        col_list = ", ".join(quote_ident(c) for c in cols)
        ddls.append(
            f"CREATE {unique}INDEX IF NOT EXISTS {quote_ident(idx_name)} "
            f"ON {qualified} ({col_list});"
        )
    return ddls


def unique_keys(table: Table, source_kind: SourceKind) -> list[frozenset[str]]:
    """Column sets (target names) covered by the PK or an emitted unique index."""
    keys: list[frozenset[str]] = []
    if table.primary_key and table.primary_key.columns:
        keys.append(frozenset(sanitize_identifier(c) for c in table.primary_key.columns))
    specs = plan_columns(table, source_kind)
    for idx in table.indexes:
        if idx.unique and not idx.is_primary:
            cols, _ = plan_index_columns(idx, specs, source_kind)
            if cols:
                keys.append(frozenset(cols))
    return keys


def _fk_action(action: str | None) -> str | None:
    if not action:
        return None
    normalized = " ".join(action.replace("_", " ").upper().split())
    return normalized if normalized in _FK_ACTIONS else None


def foreign_key_ddls(
    table: Table,
    target_schema: str,
    ref_schema_for: Callable[[str], str],
    *,
    lookup_table: TableLookup | None = None,
    source_kind: SourceKind = SourceKind.AZURE_SQL,
    notes: list[str] | None = None,
) -> list[str]:
    """Return single-line ``ALTER TABLE ... ADD CONSTRAINT ... FOREIGN KEY`` statements.

    Foreign keys are applied after every table exists. The referenced table is
    placed in its *own* target schema via ``ref_schema_for(fk.ref_schema)``, so
    cross-schema references (dbo -> divadim) are preserved. With *lookup_table*
    (source schema, table -> Table or None) an FK whose referenced table is not
    migrated, or whose referenced columns lack a PK/unique index in the target,
    is skipped and noted instead of failing.
    """
    qualified = _qualified(target_schema, table)
    used: set[str] = set()
    ddls: list[str] = []

    def skip(fk_name: str, reason: str) -> None:
        if notes is not None:
            notes.append(f"foreign key {fk_name} skipped: {reason}")

    for fk in table.foreign_keys:
        ref_label = f"{fk.ref_schema}.{fk.ref_table}"
        if not fk.columns or len(fk.columns) != len(fk.ref_columns):
            skip(fk.name, "column lists are empty or of different lengths")
            continue
        missing = [c for c in fk.columns if _find_column(table, c) is None]
        if missing:
            skip(fk.name, f"column(s) {', '.join(missing)} not found")
            continue
        ref_name = fk.ref_table
        if lookup_table is not None:
            ref_table = lookup_table(fk.ref_schema, fk.ref_table)
            if ref_table is None:
                skip(fk.name, f"referenced table {ref_label} is not migrated with this database")
                continue
            ref_missing = [c for c in fk.ref_columns if _find_column(ref_table, c) is None]
            if ref_missing:
                skip(fk.name, f"column(s) {', '.join(ref_missing)} not found in {ref_label}")
                continue
            ref_set = frozenset(sanitize_identifier(c) for c in fk.ref_columns)
            if ref_set not in unique_keys(ref_table, source_kind):
                skip(fk.name, f"referenced columns of {ref_label} have no PK/unique index")
                continue
            ref_name = ref_table.name

        cols = ", ".join(quote_ident(sanitize_identifier(c)) for c in fk.columns)
        ref_cols = ", ".join(quote_ident(sanitize_identifier(c)) for c in fk.ref_columns)
        ref_qualified = (
            f"{quote_ident(ref_schema_for(fk.ref_schema))}."
            f"{quote_ident(sanitize_identifier(ref_name))}"
        )
        fk_name = unique_name(sanitize_identifier(f"{table.name}_{fk.name}"), used)
        clause = (
            f"ALTER TABLE {qualified} ADD CONSTRAINT {quote_ident(fk_name)} "
            f"FOREIGN KEY ({cols}) REFERENCES {ref_qualified} ({ref_cols})"
        )
        for verb, raw in (("DELETE", fk.on_delete), ("UPDATE", fk.on_update)):
            action = _fk_action(raw)
            if action:
                clause += f" ON {verb} {action}"
            elif raw and notes is not None:
                notes.append(f"foreign key {fk.name}: unknown ON {verb} action {raw!r} ignored")
        if getattr(fk, "not_valid", False):
            # Untrusted/disabled at the source: existing rows may violate it.
            clause += " NOT VALID"
            if notes is not None:
                notes.append(
                    f"foreign key {fk.name} was untrusted/disabled at the source; "
                    "created NOT VALID (enforced for new rows only)"
                )
        ddls.append(clause + ";")
    return ddls


def bigint_overrides(tables: list[Table], source_kind: SourceKind) -> TypeOverrides:
    """Columns that must become bigint so foreign keys stay type-compatible.

    An MS SQL ``decimal(p,0)`` identity becomes ``bigint``; Postgres refuses an FK
    between ``numeric`` and ``bigint``, so every ``numeric(p,0)`` column linked to
    it through foreign keys (in either direction, transitively) is widened too.
    """
    if source_kind == SourceKind.AZURE_POSTGRES:
        return {}
    by_key = {table_key(t.schema, t.name): t for t in tables}

    def scale0(col: Column) -> bool:
        return bool(_NUMERIC_SCALE0.match(map_column_type(col, False).postgres_type))

    promoted: set[tuple[str, str, str]] = {
        (*table_key(t.schema, t.name), c.name.casefold())
        for t in tables
        for c in t.columns
        if c.is_identity and scale0(c)
    }
    if not promoted:
        return {}

    edges: list[tuple[tuple[Table, str], tuple[Table, str]]] = []
    for t in tables:
        for fk in t.foreign_keys:
            ref = by_key.get(table_key(fk.ref_schema, fk.ref_table))
            if ref is not None:
                edges.extend(((t, a), (ref, b)) for a, b in zip(fk.columns, fk.ref_columns))

    overrides: TypeOverrides = {}
    changed = True
    while changed:
        changed = False
        for end_a, end_b in edges:
            for (src_t, src_c), (dst_t, dst_c) in ((end_a, end_b), (end_b, end_a)):
                src = (*table_key(src_t.schema, src_t.name), src_c.casefold())
                dst = (*table_key(dst_t.schema, dst_t.name), dst_c.casefold())
                col = _find_column(dst_t, dst_c)
                if src in promoted and dst not in promoted and col and scale0(col):
                    promoted.add(dst)
                    overrides.setdefault((dst_t.schema, dst_t.name), {})[col.name] = "bigint"
                    changed = True
    return overrides
