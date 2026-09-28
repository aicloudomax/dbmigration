"""DDL generation: cross-schema FKs, defaults, identity, indexes, and a real-PG run."""

from __future__ import annotations

import secrets
import uuid
from datetime import datetime, timezone
from decimal import Decimal

import pytest

from dbmigration.config import (
    DiscoveryConfig,
    MigrationConfig,
    NamingConfig,
    Plan,
    RoutinesConfig,
    TargetConfig,
)
from dbmigration.model import (
    Column,
    Database,
    ForeignKey,
    Index,
    Routine,
    SourceKind,
    Table,
    View,
)
from dbmigration.pipeline import (
    TableDDL,
    build_schema_statements,
    build_table_statements,
    schema_create_statements,
)


def make_plan() -> Plan:
    return Plan(
        target=TargetConfig(supabase_project_ref="example"),
        naming=NamingConfig(),
        discovery=DiscoveryConfig(),
        migration=MigrationConfig(),
        routines=RoutinesConfig(),
    )


def make_db(tables, views=(), routines=(), name="LiveBit") -> Database:
    return Database(
        subscription="sub", server="srv", kind=SourceKind.AZURE_SQL, name=name,
        tables=list(tables), views=list(views), routines=list(routines),
    )


def pk(*cols: str) -> Index:
    return Index(name="PK", columns=list(cols), unique=True, is_primary=True)


def dim_date() -> Table:
    return Table(
        schema="divadim",
        name="DimDate",
        columns=[
            Column("DateKey", "int", nullable=False, ordinal=1),
            Column("Label", "nvarchar", char_length=20, ordinal=2),
        ],
        primary_key=pk("DateKey"),
    )


def orders(**overrides) -> Table:
    fields = {
        "schema": "dbo",
        "name": "Orders",
        "columns": [
            Column("Id", "int", nullable=False, is_identity=True, ordinal=1),
            Column("DateKey", "int", ordinal=2),
        ],
        "primary_key": pk("Id"),
        "foreign_keys": [
            ForeignKey("FK_Orders_DimDate", ["DateKey"], "divadim", "DimDate", ["DateKey"]),
        ],
    }
    fields.update(overrides)
    return Table(**fields)


def ddl_for(db: Database, qualified: str) -> TableDDL:
    (found,) = [t for t in build_table_statements(make_plan(), db) if t.table.qualified == qualified]
    return found


def column_line(create_sql: str, column: str) -> str:
    (line,) = [ln for ln in create_sql.splitlines() if ln.strip().startswith(f'"{column}" ')]
    return line.strip().rstrip(",")


def single_column_table(col: Column, name: str = "T") -> Table:
    return Table(schema="dbo", name=name, columns=[col])


# --- foreign keys ------------------------------------------------------------

def test_cross_schema_fk_references_referenced_tables_own_schema():
    db = make_db([orders(), dim_date()])
    (fk,) = ddl_for(db, "dbo.Orders").fk_sqls
    assert fk == (
        'ALTER TABLE "livebit_dbo"."orders" ADD CONSTRAINT "orders_fk_orders_dimdate" '
        'FOREIGN KEY ("datekey") REFERENCES "livebit_divadim"."dimdate" ("datekey");'
    )
    assert "\n" not in fk


def test_fk_to_missing_table_is_skipped_with_note():
    db = make_db([orders()])  # divadim.DimDate not part of the database
    tddl = ddl_for(db, "dbo.Orders")
    assert tddl.fk_sqls == []
    assert any("FK_Orders_DimDate" in n and "divadim.DimDate" in n for n in tddl.notes)


def test_fk_without_unique_target_is_skipped_with_note():
    dim = dim_date()
    dim.primary_key = None
    tddl = ddl_for(make_db([orders(), dim]), "dbo.Orders")
    assert tddl.fk_sqls == []
    assert any("no PK/unique index" in n for n in tddl.notes)


def test_fk_actions_are_single_line():
    fk = ForeignKey("FK_X", ["DateKey"], "divadim", "DimDate", ["DateKey"],
                    on_delete="CASCADE", on_update="SET_NULL")
    (sql,) = ddl_for(make_db([orders(foreign_keys=[fk]), dim_date()]), "dbo.Orders").fk_sqls
    assert sql.endswith(" ON DELETE CASCADE ON UPDATE SET NULL;")
    assert "\n" not in sql


def test_untrusted_fk_created_not_valid_with_note():
    fk = ForeignKey("FK_X", ["DateKey"], "divadim", "DimDate", ["DateKey"],
                    on_delete="CASCADE", not_valid=True)
    tddl = ddl_for(make_db([orders(foreign_keys=[fk]), dim_date()]), "dbo.Orders")
    (sql,) = tddl.fk_sqls
    assert sql.endswith(" ON DELETE CASCADE NOT VALID;")
    assert any("NOT VALID" in n for n in tddl.notes)


def test_build_schema_statements_collects_all_fks():
    create, fks, table_schema = build_schema_statements(make_plan(), make_db([orders(), dim_date()]))
    assert len(fks) == 1 and '"livebit_divadim"."dimdate"' in fks[0]
    assert table_schema == {"dbo.Orders": "livebit_dbo", "divadim.DimDate": "livebit_divadim"}
    assert create[:2] == [
        'CREATE SCHEMA IF NOT EXISTS "livebit_dbo";',
        'CREATE SCHEMA IF NOT EXISTS "livebit_divadim";',
    ]


# --- defaults ----------------------------------------------------------------

@pytest.mark.parametrize(
    ("source_type", "default", "expected"),
    [
        ("bit", "((1))", '"c" boolean DEFAULT true'),
        ("bit", "((0))", '"c" boolean DEFAULT false'),
        ("nvarchar", "(N'abc')", '"c" varchar(10) DEFAULT \'abc\''),
        ("datetime", "(getdate())", '"c" timestamp DEFAULT now()'),
    ],
)
def test_defaults_translated(source_type, default, expected):
    col = Column("c", source_type, default=default, char_length=10)
    tddl = ddl_for(make_db([single_column_table(col)]), "dbo.T")
    assert column_line(tddl.create_sql, "c") == expected


def test_convert_default_dropped_with_note():
    col = Column("Flag", "bit", default="(CONVERT([bit],(0)))")
    tddl = ddl_for(make_db([single_column_table(col)]), "dbo.T")
    assert column_line(tddl.create_sql, "flag") == '"flag" boolean'
    assert "column Flag: default (CONVERT([bit],(0))) not translated; dropped" in tddl.notes


def test_incompatible_default_dropped_with_note():
    col = Column("When", "datetime", default="((0))")  # 1900-01-01 in MS SQL, invalid in PG
    tddl = ddl_for(make_db([single_column_table(col)]), "dbo.T")
    assert "DEFAULT" not in tddl.create_sql
    assert any("not compatible with timestamp" in n for n in tddl.notes)


# --- identity ----------------------------------------------------------------

def test_decimal_identity_becomes_bigint_with_note():
    col = Column("Id", "decimal", nullable=False, is_identity=True,
                 numeric_precision=18, numeric_scale=0)
    tddl = ddl_for(make_db([single_column_table(col)]), "dbo.T")
    assert column_line(tddl.create_sql, "id") == '"id" bigint GENERATED BY DEFAULT AS IDENTITY NOT NULL'
    assert any("bigint" in n and "identity" in n for n in tddl.notes)


def test_numeric_fk_column_widened_to_match_bigint_identity():
    dim = Table(
        schema="divadim", name="DimDate",
        columns=[Column("DateKey", "decimal", nullable=False, is_identity=True,
                        numeric_precision=18, numeric_scale=0)],
        primary_key=pk("DateKey"),
    )
    fact = orders(columns=[
        Column("Id", "int", nullable=False, is_identity=True, ordinal=1),
        Column("DateKey", "decimal", numeric_precision=18, numeric_scale=0, ordinal=2),
    ])
    tddl = ddl_for(make_db([fact, dim]), "dbo.Orders")
    assert column_line(tddl.create_sql, "datekey") == '"datekey" bigint'
    assert len(tddl.fk_sqls) == 1


def test_identity_reset_sql_exact_text():
    tddl = ddl_for(make_db([orders(), dim_date()]), "dbo.Orders")
    assert tddl.identity_reset_sqls == [
        (
            "SELECT setval(pg_get_serial_sequence('\"livebit_dbo\".\"orders\"', 'id'), "
            'COALESCE(MAX("id"), 1), MAX("id") IS NOT NULL) FROM "livebit_dbo"."orders";'
        )
    ]
    assert ddl_for(make_db([orders(), dim_date()]), "divadim.DimDate").identity_reset_sqls == []


def test_identity_on_non_integer_type_is_dropped_with_note():
    col = Column("Id", "uniqueidentifier", is_identity=True)
    tddl = ddl_for(make_db([single_column_table(col)]), "dbo.T")
    assert "IDENTITY" not in tddl.create_sql
    assert tddl.identity_reset_sqls == []
    assert any("created without identity" in n for n in tddl.notes)


# --- indexes & notes ---------------------------------------------------------

def test_xml_index_skipped_with_note():
    t = Table(
        schema="dbo", name="Doc",
        columns=[Column("Id", "int"), Column("Body", "xml")],
        indexes=[Index("IX_Body", ["Body"]), Index("IX_Id", ["Id"])],
    )
    tddl = ddl_for(make_db([t]), "dbo.Doc")
    assert tddl.index_sqls == ['CREATE INDEX IF NOT EXISTS "doc_ix_id" ON "livebit_dbo"."doc" ("id");']
    assert any("IX_Body skipped" in n and "xml" in n for n in tddl.notes)


def test_lob_include_column_left_out_of_index():
    t = Table(
        schema="dbo", name="T",
        columns=[Column("Code", "varchar", char_length=10), Column("Body", "nvarchar", char_length=-1)],
        indexes=[Index("UX_Code", ["Code", "Body"], unique=True)],
    )
    tddl = ddl_for(make_db([t]), "dbo.T")
    assert tddl.index_sqls == [
        'CREATE UNIQUE INDEX IF NOT EXISTS "t_ux_code" ON "livebit_dbo"."t" ("code");'
    ]
    assert any("Body left out" in n for n in tddl.notes)


def test_index_names_unique_within_target_schema():
    line = Table(schema="dbo", name="Line", columns=[Column("A", "int")],
                 indexes=[Index("Item_IX", ["A"])])
    line_item = Table(schema="dbo", name="Line_Item", columns=[Column("A", "int")],
                      indexes=[Index("IX", ["A"])])
    # A table already called "line_item_ix" must not be shadowed by an index.
    clash = Table(schema="dbo", name="Line_Item_IX", columns=[Column("A", "int")])
    other = Table(schema="divadim", name="Line", columns=[Column("A", "int")],
                  indexes=[Index("Item_IX", ["A"])])
    db = make_db([line, line_item, clash, other])
    names = {
        t.table.qualified: [s.split('"')[1] for s in t.index_sqls]
        for t in build_table_statements(make_plan(), db)
    }
    assert names["dbo.Line"] == ["line_item_ix_2"]
    assert names["dbo.Line_Item"] == ["line_item_ix_3"]
    assert names["divadim.Line"] == ["line_item_ix"]  # different schema, no clash


def test_lossy_type_mapping_note_recorded():
    tddl = ddl_for(make_db([single_column_table(Column("Tiny", "tinyint"))]), "dbo.T")
    assert "column Tiny: tinyint widened to smallint" in tddl.notes


def test_schema_create_statements_include_view_and_routine_schemas():
    db = make_db(
        [dim_date()],
        views=[View("zora", "vDates", "CREATE VIEW zora.vDates AS SELECT 1 AS a")],
        routines=[Routine("aidd", "usp_Run", "procedure", "tsql", "CREATE PROC aidd.usp_Run AS SELECT 1")],
    )
    assert schema_create_statements(make_plan(), db) == [
        'CREATE SCHEMA IF NOT EXISTS "livebit_aidd";',
        'CREATE SCHEMA IF NOT EXISTS "livebit_divadim";',
        'CREATE SCHEMA IF NOT EXISTS "livebit_zora";',
    ]


# --- real Postgres -----------------------------------------------------------

def synthetic_livebit(name: str) -> Database:
    """A two-schema (dbo + divadim) database exercising the risky mappings."""
    dim = Table(
        schema="divadim",
        name="DimDate",
        columns=[
            Column("DateKey", "decimal", nullable=False, is_identity=True,
                   numeric_precision=18, numeric_scale=0, ordinal=1),
            Column("Label", "nvarchar", char_length=30, default="(N'n/a')", ordinal=2),
        ],
        primary_key=Index("PK_DimDate", ["DateKey"], unique=True, is_primary=True),
    )
    fact = Table(
        schema="dbo",
        name="Orders",
        columns=[
            Column("Id", "int", nullable=False, is_identity=True, ordinal=1),
            Column("IsActive", "bit", nullable=False, default="((1))", ordinal=2),
            Column("IsDeleted", "bit", nullable=False, default="((0))", ordinal=3),
            Column("Legacy", "bit", default="(CONVERT([bit],(0)))", ordinal=4),
            Column("Notes", "nvarchar", char_length=-1, default="(N'it''s')", ordinal=5),
            Column("Amount", "decimal", numeric_precision=18, numeric_scale=2,
                   default="((-1.50))", ordinal=6),
            Column("RowGuid", "uniqueidentifier", nullable=False, default="(newid())", ordinal=7),
            Column("CreatedAt", "datetimeoffset", default="(sysdatetimeoffset())", ordinal=8),
            Column("Payload", "varbinary", char_length=-1, ordinal=9),
            Column("Doc", "xml", ordinal=10),
            Column("DateKey", "decimal", numeric_precision=18, numeric_scale=0, ordinal=11),
            Column("Updated", "datetime", default="((0))", ordinal=12),
            Column("Created", "datetime2", default="(getutcdate())", ordinal=13),
            Column("Code", "varchar", char_length=10, default="('A')", ordinal=14),
        ],
        primary_key=Index("PK_Orders", ["Id"], unique=True, is_primary=True),
        indexes=[
            Index("IX_Doc", ["Doc"]),
            Index("IX_Amount", ["Amount", "Notes"]),
            Index("UX_RowGuid", ["RowGuid"], unique=True),
            Index("Line_IX", ["Code"]),
        ],
        foreign_keys=[
            ForeignKey("FK_Orders_DimDate", ["DateKey"], "divadim", "DimDate", ["DateKey"],
                       on_delete="NO ACTION"),
            ForeignKey("FK_Orders_Gone", ["Id"], "dbo", "Gone", ["Id"]),
        ],
    )
    orders_line = Table(
        schema="dbo",
        name="Orders_Line",
        columns=[Column("Id", "bigint", nullable=False, is_identity=True, ordinal=1),
                 Column("Qty", "tinyint", ordinal=2)],
        primary_key=Index("PK_Orders_Line", ["Id"], unique=True, is_primary=True),
        indexes=[Index("IX", ["Qty"])],
    )
    return make_db([fact, dim, orders_line], name=name)


def _text(value):
    """Text comes back as bytes from a SQL_ASCII cluster; normalize to str."""
    return value.decode() if isinstance(value, bytes) else value


def test_generated_sql_executes_on_real_postgres(request):
    try:
        url = request.getfixturevalue("pg_url")
    except pytest.FixtureLookupError:
        pytest.skip("pg_url fixture (throwaway PostgreSQL) not available")
    psycopg = pytest.importorskip("psycopg")

    db = synthetic_livebit(f"DdlProbe{uuid.uuid4().hex[:8]}")
    plan = make_plan()
    tables = {t.table.qualified: t for t in build_table_statements(plan, db)}
    fact, dim = tables["dbo.Orders"], tables["divadim.DimDate"]
    s_dbo, s_dim = fact.target_schema, dim.target_schema

    with psycopg.connect(url, autocommit=False) as conn:
        try:
            with conn.cursor() as cur:
                for stmt in schema_create_statements(plan, db):
                    cur.execute(stmt)
                for t in tables.values():
                    cur.execute(t.create_sql)
                    for stmt in t.index_sqls:
                        cur.execute(stmt)

                # Data load with explicit identity values, as the loader does.
                cur.execute(f'INSERT INTO "{s_dim}"."dimdate" ("datekey", "label") '
                            "VALUES (20240101, 'Jan 1'), (20240102, 'Jan 2')")
                cur.execute(
                    f'INSERT INTO "{s_dbo}"."orders" ("id", "isactive", "isdeleted", "rowguid", '
                    '"notes", "amount", "createdat", "payload", "doc", "datekey") '
                    "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                    # Incompressible 8000-char note: would overflow a btree entry if the
                    # INCLUDE-only nvarchar(max) column were indexed.
                    (41, False, True, uuid.uuid4(), secrets.token_hex(4000), Decimal("12.34"),
                     datetime(2024, 1, 1, 8, 30, tzinfo=timezone.utc), b"\x00\xff",
                     "<a><b>1</b></a><c/>", 20240101),
                )

                for t in tables.values():
                    for stmt in t.fk_sqls + t.identity_reset_sqls:
                        assert "\n" not in stmt
                        cur.execute(stmt)

                # Identity continues after the loaded max; empty tables start at 1.
                cur.execute(f'INSERT INTO "{s_dbo}"."orders" ("datekey") VALUES (20240102) '
                            'RETURNING "id", "isactive", "isdeleted", "legacy", "notes", '
                            '"amount", "rowguid", "createdat", "updated", "created", "code"')
                row = [_text(v) for v in cur.fetchone()]
                assert row[:6] == [42, True, False, None, "it's", Decimal("-1.50")]
                assert row[6] is not None and row[7] is not None
                assert row[8] is None and row[9] is not None and row[10] == "A"
                cur.execute(f'INSERT INTO "{s_dim}"."dimdate" DEFAULT VALUES '
                            'RETURNING "datekey", "label"')
                assert [_text(v) for v in cur.fetchone()] == [20240103, "n/a"]
                cur.execute(f'INSERT INTO "{s_dbo}"."orders_line" DEFAULT VALUES RETURNING "id"')
                assert cur.fetchone() == (1,)

                # The FK really points across schemas and is enforced.
                cur.execute(
                    "SELECT confrelid::regclass::text FROM pg_constraint "
                    "WHERE contype = 'f' AND conrelid = %s::regclass",
                    (f'"{s_dbo}"."orders"',),
                )
                assert [_text(r[0]) for r in cur.fetchall()] == [f"{s_dim}.dimdate"]
                with pytest.raises(psycopg.errors.ForeignKeyViolation), conn.transaction():
                    cur.execute(f'INSERT INTO "{s_dbo}"."orders" ("datekey") VALUES (99)')

                cur.execute("SELECT indexname FROM pg_indexes WHERE schemaname = %s", (s_dbo,))
                assert sorted(_text(r[0]) for r in cur.fetchall()) == [
                    "orders_ix_amount", "orders_line_ix", "orders_line_ix_2",
                    "orders_line_pkey", "orders_pkey", "orders_ux_rowguid",
                ]
        finally:
            conn.rollback()  # DDL is transactional: leave the database untouched
