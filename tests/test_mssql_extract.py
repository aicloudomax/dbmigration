"""MS SQL extractor tests against fake pymssql connection/cursor objects (no real DB)."""

from __future__ import annotations

import sys
import types

import pytest

from dbmigration.extract import mssql
from dbmigration.model import Column, Index, Table

# --- fakes -------------------------------------------------------------------

_COLUMN_FIELDS = (
    "schema_name", "table_name", "column_name", "data_type", "is_nullable", "max_length",
    "precision", "scale", "is_identity", "is_computed", "column_id", "default_definition",
)
_VIEW_COLUMN_FIELDS = (
    "schema_name", "view_name", "column_name", "data_type", "is_nullable", "max_length",
    "precision", "scale", "column_id",
)
_FK_FIELDS = (
    "fk_id", "fk_name", "schema_name", "table_name", "column_name", "ref_schema",
    "ref_table", "ref_column", "on_delete", "on_update", "not_trusted",
)


def _col_row(table, name, data_type, max_length, column_id, *, computed=0, identity=0):
    return ("dbo", table, name, data_type, 1, max_length, 0, 0, identity, computed, column_id, None)


class FakeCursor:
    def __init__(self, conn: FakeConnection):
        self._conn = conn
        self.description: list[tuple] | None = None
        self._rows: list[tuple] = []

    def execute(self, sql: str) -> None:
        self._conn.executed.append(sql)
        fields, rows = self._conn.dispatch(sql)
        self.description = [(f, None, None, None, None, None, None) for f in fields]
        self._rows = list(rows)

    def __iter__(self):
        while self._rows:
            yield self._rows.pop(0)

    def fetchmany(self, size: int) -> list[tuple]:
        batch, self._rows = self._rows[:size], self._rows[size:]
        return batch


class FakeConnection:
    """Answers each catalog query by matching the exact SQL text sent."""

    def __init__(
        self, columns=(), indexes=(), pks=(), view_columns=(), views=(), data_rows=(), fks=()
    ):
        self.executed: list[str] = []
        self._by_sql = {
            mssql._COLUMNS_SQL: (_COLUMN_FIELDS, columns),
            mssql._PK_SQL: (
                ("schema_name", "table_name", "index_name", "column_name", "key_ordinal"), pks
            ),
            mssql._INDEX_SQL: (
                ("schema_name", "table_name", "index_name", "is_unique", "column_name",
                 "key_ordinal"),
                indexes,
            ),
            mssql._FK_SQL: (_FK_FIELDS, fks),
            mssql._ROWCOUNT_SQL: (("schema_name", "table_name", "row_count"), ()),
            mssql._VIEW_COLUMNS_SQL: (_VIEW_COLUMN_FIELDS, view_columns),
            mssql._VIEWS_SQL: (("schema_name", "view_name", "definition"), views),
            mssql._ROUTINES_SQL: (("schema_name", "routine_name", "kind", "definition"), ()),
        }
        self._data_rows = data_rows

    def dispatch(self, sql: str):
        if sql in self._by_sql:
            return self._by_sql[sql]
        if sql.startswith("SELECT ") and " FROM [" in sql:  # table data read
            return ("c",), self._data_rows
        raise AssertionError(f"unexpected SQL: {sql[:80]}")

    def cursor(self) -> FakeCursor:
        return FakeCursor(self)


def _extract(conn: FakeConnection):
    return mssql.extract_database(conn, subscription="sub", server="srv", database="LiveBit")


def _columns_by_name(db, table="T"):
    (tbl,) = [t for t in db.tables if t.name == table]
    return {c.name: c for c in tbl.columns}


# --- char_length: bytes -> characters -----------------------------------------

def test_char_length_converted_from_bytes():
    conn = FakeConnection(
        columns=[
            _col_row("T", "nv100", "nvarchar", 200, 1),
            _col_row("T", "nvmax", "nvarchar", -1, 2),
            _col_row("T", "nc10", "nchar", 20, 3),
            _col_row("T", "v50", "varchar", 50, 4),
            _col_row("T", "vmax", "varchar", -1, 5),
            _col_row("T", "c7", "char", 7, 6),
            _col_row("T", "i", "int", 4, 7),
        ]
    )
    cols = _columns_by_name(_extract(conn))
    assert cols["nv100"].char_length == 100
    assert cols["nvmax"].char_length == -1
    assert cols["nc10"].char_length == 10
    assert cols["v50"].char_length == 50
    assert cols["vmax"].char_length == -1
    assert cols["c7"].char_length == 7
    assert cols["i"].char_length == 4  # non-character types unchanged


def test_char_length_helper_edge_cases():
    assert mssql._char_length("NVARCHAR", 8000) == 4000  # case-insensitive
    assert mssql._char_length("nvarchar", None) is None
    assert mssql._char_length("nchar", 0) == 0


def test_view_column_char_length_converted():
    conn = FakeConnection(
        view_columns=[
            ("dbo", "V", "name", "nvarchar", 1, 100, 0, 0, 1),
            ("dbo", "V", "code", "varchar", 1, 12, 0, 0, 2),
        ],
        views=[("dbo", "V", "SELECT 1")],
    )
    (view,) = _extract(conn).views
    assert [c.char_length for c in view.columns] == [50, 12]


def test_columns_sql_resolves_alias_types_to_base_type():
    for sql in (mssql._COLUMNS_SQL, mssql._VIEW_COLUMNS_SQL):
        assert "LEFT JOIN sys.types bt ON bt.user_type_id = ty.system_type_id" in sql
        assert "ty.is_assembly_type = 0" in sql
        assert "AS data_type" in sql


# --- is_computed ---------------------------------------------------------------

def test_is_computed_populated():
    conn = FakeConnection(
        columns=[
            _col_row("T", "a", "int", 4, 1),
            _col_row("T", "total", "int", 4, 2, computed=1),
        ]
    )
    cols = _columns_by_name(_extract(conn))
    assert cols["a"].is_computed is False
    assert cols["total"].is_computed is True
    assert "c.is_computed" in mssql._COLUMNS_SQL


def test_column_is_computed_defaults_false():
    assert Column(name="x", source_type="int").is_computed is False


# --- indexes -------------------------------------------------------------------

def test_index_sql_filters():
    sql = " ".join(mssql._INDEX_SQL.split())
    assert "i.type IN (1, 2)" in sql
    assert "ic.is_included_column = 0" in sql
    assert "i.is_disabled = 0" in sql
    assert "i.is_hypothetical = 0" in sql
    assert "i.has_filter = 0" in sql
    assert "i.is_primary_key = 0" in sql
    assert sql.rstrip(";").endswith("ORDER BY s.name, t.name, i.name, ic.key_ordinal")


def test_indexes_and_pk_attached_in_key_order():
    conn = FakeConnection(
        columns=[_col_row("T", "a", "int", 4, 1), _col_row("T", "b", "int", 4, 2)],
        pks=[("dbo", "T", "PK_T", "a", 1)],
        indexes=[("dbo", "T", "IX_T_b_a", 1, "b", 1), ("dbo", "T", "IX_T_b_a", 1, "a", 2)],
    )
    (table,) = _extract(conn).tables
    assert table.primary_key == Index(name="PK_T", columns=["a"], unique=True, is_primary=True)
    assert table.indexes == [Index(name="IX_T_b_a", columns=["b", "a"], unique=True)]


def _schema_col(schema, table, name, column_id):
    return (schema, table, name, "int", 1, 4, 10, 0, 0, 0, column_id, None)


def test_same_named_fks_in_two_schemas_stay_separate():
    # FK names are unique per schema only; grouping by name would merge these two.
    conn = FakeConnection(
        columns=[
            _schema_col("dbo", "Orders", "CustomerId", 1),
            _schema_col("zora", "Orders", "AccountId", 1),
            _schema_col("zora", "Orders", "RegionId", 2),
        ],
        fks=[
            (101, "FK_Orders", "dbo", "Orders", "CustomerId", "dbo", "Customers", "Id",
             "CASCADE", "NO_ACTION", 0),
            (202, "FK_Orders", "zora", "Orders", "AccountId", "zora", "Accounts", "Id",
             "NO_ACTION", "CASCADE", 1),
            (202, "FK_Orders", "zora", "Orders", "RegionId", "zora", "Accounts", "RegionId",
             "NO_ACTION", "CASCADE", 1),
        ],
    )
    tables = {(t.schema, t.name): t for t in _extract(conn).tables}
    (dbo_fk,) = tables[("dbo", "Orders")].foreign_keys
    (zora_fk,) = tables[("zora", "Orders")].foreign_keys
    assert (dbo_fk.columns, dbo_fk.ref_schema, dbo_fk.ref_table) == (
        ["CustomerId"], "dbo", "Customers"
    )
    assert dbo_fk.on_delete == "CASCADE" and dbo_fk.on_update == "NO ACTION"
    assert dbo_fk.not_valid is False
    assert (zora_fk.columns, zora_fk.ref_columns) == (["AccountId", "RegionId"], ["Id", "RegionId"])
    assert zora_fk.on_update == "CASCADE"
    assert zora_fk.not_valid is True


def test_fk_sql_groups_by_object_id_and_reads_trust():
    sql = " ".join(mssql._FK_SQL.split())
    assert "fk.object_id AS fk_id" in sql
    assert "ORDER BY fk.object_id, fkc.constraint_column_id" in sql
    assert "fk.is_not_trusted = 1 OR fk.is_disabled = 1" in sql
    assert "update_referential_action_desc AS on_update" in sql


# --- build_select_sql ------------------------------------------------------------

def _table(columns, pk=None, schema="dbo", name="T"):
    return Table(schema=schema, name=name, columns=columns, primary_key=pk)


def test_select_plain_columns_in_ordinal_order_without_pk():
    t = _table([Column("b", "int", ordinal=2), Column("a", "nvarchar", ordinal=1)])
    assert mssql.build_select_sql(t) == "SELECT [a], [b] FROM [dbo].[T]"


def test_select_type_conversions():
    t = _table(
        [
            Column("geo", "geography", ordinal=1),
            Column("shape", "geometry", ordinal=2),
            Column("node", "hierarchyid", ordinal=3),
            Column("v", "sql_variant", ordinal=4),
            Column("doc", "xml", ordinal=5),
            Column("n", "int", ordinal=6),
        ]
    )
    assert mssql.build_select_sql(t) == (
        "SELECT [geo].STAsText() AS [geo], [shape].STAsText() AS [shape], "
        "[node].ToString() AS [node], CAST([v] AS nvarchar(4000)) AS [v], "
        "CAST([doc] AS nvarchar(max)) AS [doc], [n] FROM [dbo].[T]"
    )


def test_select_conversion_is_case_insensitive():
    t = _table([Column("g", "Geography", ordinal=1)])
    assert mssql.build_select_sql(t) == "SELECT [g].STAsText() AS [g] FROM [dbo].[T]"


def test_select_escapes_closing_brackets():
    t = _table(
        [Column("we]ird", "int", ordinal=1), Column("sh]ape", "geometry", ordinal=2)],
        pk=Index(name="PK", columns=["we]ird"], unique=True, is_primary=True),
        schema="sch]ema",
        name="ta]ble",
    )
    assert mssql.build_select_sql(t) == (
        "SELECT [we]]ird], [sh]]ape].STAsText() AS [sh]]ape] "
        "FROM [sch]]ema].[ta]]ble] ORDER BY [we]]ird]"
    )


def test_bq():
    assert mssql._bq("plain") == "[plain]"
    assert mssql._bq("a]]b") == "[a]]]]b]"
    assert mssql._bq("with space[") == "[with space[]"


def test_select_orders_by_composite_pk_in_key_order():
    t = _table(
        [Column("a", "int", ordinal=1), Column("b", "int", ordinal=2), Column("c", "int", ordinal=3)],
        pk=Index(name="PK_T", columns=["c", "a"], unique=True, is_primary=True),
    )
    assert mssql.build_select_sql(t) == "SELECT [a], [b], [c] FROM [dbo].[T] ORDER BY [c], [a]"


def test_select_no_order_by_without_pk():
    t = _table([Column("a", "int", ordinal=1)])
    assert "ORDER BY" not in mssql.build_select_sql(t)


# --- iter_table_rows -------------------------------------------------------------

def test_iter_table_rows_batches_with_fetchmany():
    t = _table(
        [Column("id", "int", ordinal=1), Column("g", "geography", ordinal=2)],
        pk=Index(name="PK_T", columns=["id"], unique=True, is_primary=True),
    )
    rows = [(1, "POINT (1 2)"), (2, None), (3, "POINT (3 4)")]
    conn = FakeConnection(data_rows=rows)
    batches = list(mssql.iter_table_rows(conn, t, batch_size=2))
    assert batches == [[(1, "POINT (1 2)"), (2, None)], [(3, "POINT (3 4)")]]
    assert all(isinstance(r, tuple) for b in batches for r in b)
    assert conn.executed == [mssql.build_select_sql(t)]


def test_iter_table_rows_empty_table():
    conn = FakeConnection(data_rows=[])
    assert list(mssql.iter_table_rows(conn, _table([Column("a", "int", ordinal=1)]), 10)) == []


# --- connect ---------------------------------------------------------------------

def test_connect_passes_azure_settings(monkeypatch: pytest.MonkeyPatch):
    captured: dict = {}
    fake = types.ModuleType("pymssql")
    fake.connect = lambda **kw: captured.update(kw) or "conn"  # type: ignore[attr-defined]
    monkeypatch.setitem(sys.modules, "pymssql", fake)

    assert mssql.connect("h.example.net", "LiveBit", "reader", "not-a-real-password") == "conn"
    assert captured == {
        "server": "h.example.net",
        "user": "reader",
        "password": "not-a-real-password",
        "database": "LiveBit",
        "port": 1433,
        "tds_version": "7.4",
        "login_timeout": 30,
        "timeout": 0,
        "charset": "UTF-8",
    }
