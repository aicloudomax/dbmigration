"""Load transformed objects into the single target Supabase Postgres database.

All sources land in one database; each source database occupies its own schema.
Data is loaded with COPY (fast) by default, or batched INSERT for portability.
"""

from __future__ import annotations

from collections.abc import Iterator

from ..model import SourceKind, Table
from ..naming import quote_ident, sanitize_identifier


class SupabaseLoader:
    def __init__(self, connection_url: str, *, load_method: str = "copy"):
        self._url = connection_url
        self._load_method = load_method
        self._conn = None

    def __enter__(self) -> SupabaseLoader:
        import psycopg

        self._conn = psycopg.connect(self._url, autocommit=False)
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        if self._conn is not None:
            if exc_type is None:
                self._conn.commit()
            else:
                self._conn.rollback()
            self._conn.close()

    # -- schema lifecycle -----------------------------------------------------

    def schema_exists(self, schema: str) -> bool:
        with self._conn.cursor() as cur:
            cur.execute(
                "SELECT 1 FROM information_schema.schemata WHERE schema_name = %s",
                (schema,),
            )
            return cur.fetchone() is not None

    def drop_schema(self, schema: str) -> None:
        with self._conn.cursor() as cur:
            cur.execute(f"DROP SCHEMA IF EXISTS {quote_ident(schema)} CASCADE;")
        self._conn.commit()

    def execute(self, ddl: str) -> None:
        """Run a single DDL/SQL statement, committing on success."""
        with self._conn.cursor() as cur:
            cur.execute(ddl)
        self._conn.commit()

    def execute_all(self, statements: list[str]) -> None:
        with self._conn.cursor() as cur:
            for stmt in statements:
                cur.execute(stmt)
        self._conn.commit()

    # -- data -----------------------------------------------------------------

    def load_table_data(
        self,
        table: Table,
        target_schema: str,
        row_batches: Iterator[list[tuple]],
        source_kind: SourceKind,
    ) -> int:
        """Load all row batches into the target table. Returns rows written."""
        target_table = sanitize_identifier(table.name)
        ordered_cols = sorted(table.columns, key=lambda c: c.ordinal)
        col_idents = [quote_ident(sanitize_identifier(c.name)) for c in ordered_cols]
        qualified = f"{quote_ident(target_schema)}.{quote_ident(target_table)}"

        if self._load_method == "copy":
            return self._load_copy(qualified, col_idents, row_batches)
        return self._load_insert(qualified, col_idents, row_batches)

    def _load_copy(self, qualified: str, col_idents: list[str], batches) -> int:
        written = 0
        col_list = ", ".join(col_idents)
        copy_sql = f"COPY {qualified} ({col_list}) FROM STDIN"
        with self._conn.cursor() as cur, cur.copy(copy_sql) as copy:
            for batch in batches:
                for row in batch:
                    copy.write_row(row)
                    written += 1
        self._conn.commit()
        return written

    def _load_insert(self, qualified: str, col_idents: list[str], batches) -> int:
        written = 0
        col_list = ", ".join(col_idents)
        with self._conn.cursor() as cur:
            for batch in batches:
                if not batch:
                    continue
                placeholders = ", ".join(["(" + ", ".join(["%s"] * len(col_idents)) + ")"] * len(batch))
                flat: list = []
                for row in batch:
                    flat.extend(row)
                cur.execute(
                    f"INSERT INTO {qualified} ({col_list}) VALUES {placeholders}",
                    flat,
                )
                written += len(batch)
        self._conn.commit()
        return written
