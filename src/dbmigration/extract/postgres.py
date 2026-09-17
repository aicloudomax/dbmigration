"""Extract schema, routines, and data from an Azure Database for PostgreSQL.

Requires ``psycopg`` (v3). The login should have read access to the target
databases and ``USAGE`` on their schemas.
"""

from __future__ import annotations

from collections.abc import Iterator

from ..model import (
    Column,
    Database,
    ForeignKey,
    Index,
    Routine,
    SourceKind,
    Table,
    View,
)

_COLUMNS_SQL = """
SELECT table_schema, table_name, column_name,
       CASE
         WHEN data_type = 'character varying' AND character_maximum_length IS NOT NULL
              THEN 'varchar(' || character_maximum_length || ')'
         WHEN data_type = 'character' AND character_maximum_length IS NOT NULL
              THEN 'char(' || character_maximum_length || ')'
         WHEN data_type = 'numeric' AND numeric_precision IS NOT NULL
              THEN 'numeric(' || numeric_precision || ',' || COALESCE(numeric_scale, 0) || ')'
         ELSE data_type
       END AS full_type,
       is_nullable, column_default, ordinal_position,
       (column_default LIKE 'nextval(%%') AS is_identity
FROM information_schema.columns
WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY table_schema, table_name, ordinal_position;
"""

_PK_SQL = """
SELECT tc.table_schema, tc.table_name, tc.constraint_name, kcu.column_name,
       kcu.ordinal_position
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'PRIMARY KEY'
  AND tc.table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY tc.table_schema, tc.table_name, kcu.ordinal_position;
"""

_FK_SQL = """
SELECT tc.constraint_name, tc.table_schema, tc.table_name, kcu.column_name,
       ccu.table_schema AS ref_schema, ccu.table_name AS ref_table,
       ccu.column_name AS ref_column, rc.delete_rule
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON kcu.constraint_name = tc.constraint_name AND kcu.table_schema = tc.table_schema
JOIN information_schema.constraint_column_usage ccu
  ON ccu.constraint_name = tc.constraint_name
JOIN information_schema.referential_constraints rc
  ON rc.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY tc.constraint_name;
"""

_INDEX_SQL = """
SELECT schemaname, tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY schemaname, tablename, indexname;
"""

_ROUTINES_SQL = """
SELECT n.nspname AS schema_name, p.proname AS routine_name,
       CASE p.prokind WHEN 'p' THEN 'procedure' ELSE 'function' END AS kind,
       l.lanname AS language,
       pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
JOIN pg_language l  ON l.oid = p.prolang
WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY n.nspname, p.proname;
"""

_ROWCOUNT_SQL = """
SELECT schemaname, relname AS table_name, n_live_tup AS row_count
FROM pg_stat_user_tables;
"""

_VIEWS_SQL = """
SELECT schemaname, viewname, definition
FROM pg_views
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY schemaname, viewname;
"""


def connect(host: str, database: str, user: str, password: str, port: int = 5432):
    import psycopg  # imported lazily

    return psycopg.connect(
        host=host, dbname=database, user=user, password=password, port=port,
        sslmode="require",
    )


def extract_database(
    conn,
    *,
    subscription: str,
    server: str,
    database: str,
) -> Database:
    db = Database(
        subscription=subscription,
        server=server,
        kind=SourceKind.AZURE_POSTGRES,
        name=database,
    )
    tables: dict[tuple[str, str], Table] = {}

    with conn.cursor() as cur:
        cur.execute(_COLUMNS_SQL)
        for schema, table_name, col, full_type, nullable, default, ordinal, is_identity in cur:
            key = (schema, table_name)
            table = tables.setdefault(key, Table(schema=schema, name=table_name))
            table.columns.append(
                Column(
                    name=col,
                    source_type=full_type,
                    nullable=(nullable == "YES"),
                    default=None if is_identity else default,
                    is_identity=bool(is_identity),
                    ordinal=int(ordinal),
                )
            )

    _attach_primary_keys(conn, tables)
    _attach_foreign_keys(conn, tables)
    _attach_row_counts(conn, tables)

    db.tables = list(tables.values())
    db.views = _extract_views(conn)
    db.routines = _extract_routines(conn)
    return db


def _extract_views(conn) -> list[View]:
    out: list[View] = []
    with conn.cursor() as cur:
        cur.execute(_VIEWS_SQL)
        for schema, name, definition in cur:
            # pg_views.definition is the SELECT body; wrap into CREATE VIEW.
            body = definition or ""
            out.append(View(schema=schema, name=name, definition=body))
    return out


def _attach_primary_keys(conn, tables: dict[tuple[str, str], Table]) -> None:
    with conn.cursor() as cur:
        cur.execute(_PK_SQL)
        pk: dict[tuple[str, str], Index] = {}
        for schema, table_name, cname, col, _ in cur:
            key = (schema, table_name)
            idx = pk.setdefault(key, Index(name=cname, columns=[], unique=True, is_primary=True))
            idx.columns.append(col)
    for key, idx in pk.items():
        if key in tables:
            tables[key].primary_key = idx


def _attach_foreign_keys(conn, tables: dict[tuple[str, str], Table]) -> None:
    with conn.cursor() as cur:
        cur.execute(_FK_SQL)
        fks: dict[str, ForeignKey] = {}
        owner: dict[str, tuple[str, str]] = {}
        for cname, schema, table_name, col, ref_schema, ref_table, ref_col, del_rule in cur:
            fk = fks.get(cname)
            if fk is None:
                fk = ForeignKey(
                    name=cname, columns=[], ref_schema=ref_schema,
                    ref_table=ref_table, ref_columns=[],
                    on_delete=(del_rule if del_rule and del_rule != "NO ACTION" else None),
                )
                fks[cname] = fk
                owner[cname] = (schema, table_name)
            fk.columns.append(col)
            fk.ref_columns.append(ref_col)
    for name, fk in fks.items():
        tkey = owner[name]
        if tkey in tables:
            tables[tkey].foreign_keys.append(fk)


def _attach_row_counts(conn, tables: dict[tuple[str, str], Table]) -> None:
    with conn.cursor() as cur:
        cur.execute(_ROWCOUNT_SQL)
        for schema, table_name, count in cur:
            key = (schema, table_name)
            if key in tables:
                tables[key].approx_row_count = int(count or 0)


def _extract_routines(conn) -> list[Routine]:
    out: list[Routine] = []
    with conn.cursor() as cur:
        cur.execute(_ROUTINES_SQL)
        for schema, name, kind, language, definition in cur:
            out.append(
                Routine(
                    schema=schema, name=name, kind=kind,
                    language=language, definition=definition or "",
                )
            )
    return out


def iter_table_rows(conn, table: Table, batch_size: int) -> Iterator[list[tuple]]:
    ordered_cols = sorted(table.columns, key=lambda c: c.ordinal)
    col_list = ", ".join(f'"{c.name}"' for c in ordered_cols)
    with conn.cursor(name=f"read_{table.schema}_{table.name}") as cur:
        cur.itersize = batch_size
        cur.execute(f'SELECT {col_list} FROM "{table.schema}"."{table.name}"')
        batch: list[tuple] = []
        for row in cur:
            batch.append(tuple(row))
            if len(batch) >= batch_size:
                yield batch
                batch = []
        if batch:
            yield batch
