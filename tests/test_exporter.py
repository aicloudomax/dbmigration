import json
import math
import uuid
from datetime import date, datetime, time, timedelta, timezone
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
from dbmigration.exporter import (
    encode_copy_row,
    encode_copy_value,
    encode_sql_literal,
    export_database,
    redact_url,
    split_sql_statements,
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

FIXED_TIME = "2026-01-01T00:00:00Z"


def make_plan(batch_size: int = 5000):
    return Plan(
        target=TargetConfig(supabase_project_ref="example-ref"),
        naming=NamingConfig(),
        discovery=DiscoveryConfig(),
        migration=MigrationConfig(batch_size=batch_size),
        routines=RoutinesConfig(),
    )


# --- COPY text encoder -------------------------------------------------------

def test_encode_none_is_backslash_n():
    assert encode_copy_value(None) == r"\N"


def test_encode_bool():
    assert encode_copy_value(True) == "t"
    assert encode_copy_value(False) == "f"


def test_encode_escapes_tab_newline_backslash():
    assert encode_copy_value("a\tb\nc\\d\re") == "a\\tb\\nc\\\\d\\re"


def test_encode_bytes_hex():
    assert encode_copy_value(b"\xde\xad") == "\\\\xdead"  # escaped backslash + xdead
    assert encode_copy_value(bytearray(b"\x00")) == "\\\\x00"
    assert encode_copy_value(memoryview(b"\x01")) == "\\\\x01"


def test_encode_copy_strips_nul_and_handles_numbers():
    assert encode_copy_value("a\x00b") == "ab"
    assert encode_copy_value(Decimal("1E+2")) == "100"
    assert encode_copy_value(Decimal("NaN")) == "NaN"
    assert encode_copy_value(float("inf")) == "Infinity"
    assert encode_copy_value(float("-inf")) == "-Infinity"
    assert encode_copy_value(float("nan")) == "NaN"
    assert encode_copy_value(1.5) == "1.5"


def test_encode_row_joins_with_tab():
    assert encode_copy_row((1, None, "x")) == "1\t\\N\tx\n"


# --- SQL literal encoder -----------------------------------------------------

def test_sql_literal_none():
    assert encode_sql_literal(None) == "NULL"


def test_sql_literal_bool_before_int():
    assert encode_sql_literal(True) == "TRUE"
    assert encode_sql_literal(False) == "FALSE"
    assert encode_sql_literal(1) == "1"


def test_sql_literal_int():
    assert encode_sql_literal(42) == "42"
    assert encode_sql_literal(-7) == "-7"


def test_sql_literal_decimal():
    assert encode_sql_literal(Decimal("12.34")) == "12.34"
    assert encode_sql_literal(Decimal("-0.50")) == "-0.50"
    assert encode_sql_literal(Decimal("1E+2")) == "100"  # never exponent notation
    assert encode_sql_literal(Decimal("1.000E-7")) == "0.0000001000"
    assert encode_sql_literal(Decimal("NaN")) == "'NaN'::numeric"
    assert encode_sql_literal(Decimal("-Infinity")) == "'-Infinity'::numeric"


def test_sql_literal_float():
    assert encode_sql_literal(1.5) == "1.5"
    assert encode_sql_literal(float("nan")) == "'NaN'::float8"
    assert encode_sql_literal(float("inf")) == "'Infinity'::float8"
    assert encode_sql_literal(float("-inf")) == "'-Infinity'::float8"
    assert float(encode_sql_literal(0.1)) == 0.1  # shortest round-trip repr


def test_sql_literal_string_escapes_quotes():
    assert encode_sql_literal("O'Brien") == "'O''Brien'"
    assert encode_sql_literal("back\\slash") == "'back\\slash'"  # standard strings


def test_sql_literal_string_strips_nul():
    assert encode_sql_literal("a\x00b\x00") == "'ab'"


def test_sql_literal_bytes():
    assert encode_sql_literal(b"\xde\xad") == "'\\xdead'::bytea"
    assert encode_sql_literal(bytearray(b"\x00'")) == "'\\x0027'::bytea"
    assert encode_sql_literal(memoryview(b"\xff")) == "'\\xff'::bytea"


def test_sql_literal_temporal_and_uuid_are_quoted_str():
    tz = timezone(timedelta(hours=5, minutes=30))
    assert encode_sql_literal(datetime(2026, 1, 2, 3, 4, 5, 6, tzinfo=tz)) == (
        "'2026-01-02 03:04:05.000006+05:30'"
    )
    assert encode_sql_literal(date(1, 1, 1)) == "'0001-01-01'"
    assert encode_sql_literal(time(23, 59, 59)) == "'23:59:59'"
    u = uuid.UUID(int=1)
    assert encode_sql_literal(u) == f"'{u}'"


# --- SQL splitting / URL redaction --------------------------------------------

def test_split_respects_quotes_comments_and_dollar_quotes():
    script = (
        "-- header; not a statement\n"
        "INSERT INTO t VALUES ('a;b', 'it''s; ok', \"we;ird\");\n"
        "/* block ; /* nested ; */ still comment ; */\n"
        "CREATE FUNCTION f() RETURNS int AS $fn$ BEGIN RETURN 1; END; $fn$ LANGUAGE plpgsql;\n"
        "SELECT E'esc\\';aped';\n"
        "SELECT 1 -- trailing; comment\n"
        ";\n"
        "-- only a comment at the end;\n"
    )
    stmts = split_sql_statements(script)
    assert len(stmts) == 4
    assert stmts[0].endswith("\"we;ird\");")
    assert "RETURN 1; END; $fn$ LANGUAGE plpgsql;" in stmts[1]
    assert stmts[2] == "SELECT E'esc\\';aped';"
    assert stmts[3].startswith("SELECT 1")


def test_split_comment_only_script_is_empty():
    assert split_sql_statements("-- nothing\n/* here */\n\n") == []


def test_split_keeps_statement_without_final_semicolon():
    assert split_sql_statements("SELECT 1;\nSELECT 2") == ["SELECT 1;", "SELECT 2"]


def test_redact_url():
    assert redact_url("postgresql://postgres:s3cr3t@db.example.co:5432/postgres?sslmode=require") == (
        "postgresql://postgres:***@db.example.co:5432/postgres?sslmode=require"
    )
    assert redact_url("postgresql://u@/db?host=/tmp&password=abc") == (
        "postgresql://u@/db?host=/tmp&password=***"
    )
    assert redact_url("host=h user=u password=abc dbname=d") == "host=h user=u password=*** dbname=d"
    assert redact_url("postgresql://postgres@/postgres?host=/tmp") == (
        "postgresql://postgres@/postgres?host=/tmp"
    )


# --- full export -------------------------------------------------------------

def sample_db():
    dim = Table(
        schema="divadim",
        name="DimDate",
        columns=[
            Column(name="DateKey", source_type="int", nullable=False, ordinal=1),
            Column(name="FullDate", source_type="date", ordinal=2),
        ],
        primary_key=Index(name="PK_DimDate", columns=["DateKey"], unique=True, is_primary=True),
        approx_row_count=1,
    )
    t = Table(
        schema="dbo",
        name="Customer",
        columns=[
            Column(name="Id", source_type="int", nullable=False, is_identity=True, ordinal=1),
            Column(name="Name", source_type="varchar", char_length=100, ordinal=2),
            Column(name="DateKey", source_type="int", ordinal=3),
        ],
        primary_key=Index(name="pk", columns=["Id"], unique=True, is_primary=True),
        indexes=[Index(name="IX_Name", columns=["Name"])],
        foreign_keys=[ForeignKey(name="FK_Date", columns=["DateKey"], ref_schema="divadim",
                                 ref_table="DimDate", ref_columns=["DateKey"])],
        approx_row_count=2,
    )
    empty = Table(
        schema="dbo",
        name="AuditLog",
        columns=[Column(name="Id", source_type="bigint", nullable=False, is_identity=True,
                        ordinal=1)],
        primary_key=Index(name="pk_a", columns=["Id"], unique=True, is_primary=True),
        approx_row_count=0,
    )
    v = View(schema="dbo", name="v_customer",
             definition="CREATE VIEW dbo.v_customer AS SELECT [Id] FROM [dbo].[Customer]")
    r = Routine(schema="dbo", name="usp_get", kind="procedure", language="tsql",
                definition="CREATE PROC dbo.usp_get AS\r\nBEGIN SELECT GETDATE(); END")
    f = Routine(schema="divadim", name="fn_Top", kind="function", language="tsql",
                definition="CREATE FUNCTION divadim.fn_Top() RETURNS int AS BEGIN SELECT TOP 1 1 END")
    return Database(subscription="(direct)", server="srv", kind=SourceKind.AZURE_SQL,
                    name="LiveBit", tables=[t, dim, empty], views=[v], routines=[r, f])


SAMPLE_ROWS = {
    "dbo.Customer": [(1, "Alice", 20260101), (2, "O'Brien", None)],
    "divadim.DimDate": [(20260101, date(2026, 1, 1))],
    "dbo.AuditLog": [],
}


def reader_for(rows_by_table, batch=2):
    def reader(table):
        rows = rows_by_table[table.qualified]
        for i in range(0, len(rows), batch):
            yield rows[i:i + batch]
    return reader


def read_manifest(db_dir):
    return json.loads((db_dir / "manifest.json").read_text(encoding="utf-8"))


def test_export_writes_per_object_tree(tmp_path):
    db = sample_db()
    result = export_database(make_plan(), db, tmp_path, reader_for(SAMPLE_ROWS))
    db_dir = tmp_path / "livebit"

    expected = {
        ".gitattributes", "manifest.json", "00_schemas.sql", "sequences.sql", "foreign_keys.sql",
        "tables/livebit_dbo__auditlog.sql", "tables/livebit_dbo__customer.sql",
        "tables/livebit_divadim__dimdate.sql",
        "data/livebit_dbo__auditlog.sql", "data/livebit_dbo__customer.sql",
        "data/livebit_divadim__dimdate.sql",
        "views/livebit_dbo__v_customer.sql", "source/views/livebit_dbo__v_customer.sql",
        "routines/livebit_dbo__usp_get.sql", "source/routines/livebit_dbo__usp_get.sql",
        "routines/livebit_divadim__fn_top.sql", "source/routines/livebit_divadim__fn_top.sql",
    }
    written = {p.relative_to(db_dir).as_posix() for p in db_dir.rglob("*") if p.is_file()}
    assert written == expected

    # Values keep CR/LF inside literals: git must not convert line endings.
    assert "* -text" in (db_dir / ".gitattributes").read_text().splitlines()

    schemas = (db_dir / "00_schemas.sql").read_text()
    assert 'CREATE SCHEMA IF NOT EXISTS "livebit_dbo";' in schemas
    assert 'CREATE SCHEMA IF NOT EXISTS "livebit_divadim";' in schemas

    table_sql = (db_dir / "tables/livebit_dbo__customer.sql").read_text()
    assert 'CREATE TABLE IF NOT EXISTS "livebit_dbo"."customer"' in table_sql
    assert 'CREATE INDEX IF NOT EXISTS "customer_ix_name"' in table_sql
    assert "FOREIGN KEY" not in table_sql  # applied after data

    data = (db_dir / "data/livebit_dbo__customer.sql").read_text()
    assert 'INSERT INTO "livebit_dbo"."customer" ("id", "name", "datekey") VALUES' in data
    assert "(1, 'Alice', 20260101)" in data
    assert "(2, 'O''Brien', NULL);" in data

    fks = (db_dir / "foreign_keys.sql").read_text().splitlines()
    fk_lines = [line for line in fks if line and not line.startswith("--")]
    assert fk_lines == [(
        'ALTER TABLE "livebit_dbo"."customer" ADD CONSTRAINT "customer_fk_date" FOREIGN KEY '
        '("datekey") REFERENCES "livebit_divadim"."dimdate" ("datekey");'
    )]
    seq_lines = [line for line in (db_dir / "sequences.sql").read_text().splitlines()
                 if line and not line.startswith("--")]
    assert len(seq_lines) == 2 and all(line.startswith("SELECT setval(") for line in seq_lines)

    # Original T-SQL is kept byte for byte (CRLF included).
    src = (db_dir / "source/routines/livebit_dbo__usp_get.sql").read_bytes()
    assert src == b"CREATE PROC dbo.usp_get AS\r\nBEGIN SELECT GETDATE(); END"
    assert (db_dir / "source/views/livebit_dbo__v_customer.sql").read_text() == db.views[0].definition
    assert 'CREATE OR REPLACE VIEW "livebit_dbo"."v_customer"' in (
        db_dir / "views/livebit_dbo__v_customer.sql").read_text()
    assert "REVIEW" in (db_dir / "routines/livebit_divadim__fn_top.sql").read_text()

    assert (result.tables, result.views, result.procedures, result.functions) == (3, 1, 1, 1)
    assert result.routines == 2
    assert result.rows == 3


def test_zero_row_table_gets_comment_only_data_file(tmp_path):
    export_database(make_plan(), sample_db(), tmp_path, reader_for(SAMPLE_ROWS))
    text = (tmp_path / "livebit/data/livebit_dbo__auditlog.sql").read_text()
    lines = [line for line in text.splitlines() if line]
    assert lines and all(line.startswith("--") for line in lines)
    assert split_sql_statements(text) == []


def test_manifest_contents(tmp_path):
    export_database(make_plan(), sample_db(), tmp_path, reader_for(SAMPLE_ROWS),
                    generated_at=FIXED_TIME)
    m = read_manifest(tmp_path / "livebit")
    assert m["database"] == "LiveBit"
    assert m["server"] == "srv"
    assert m["kind"] == "azure_sql"
    assert m["generated_at"] == FIXED_TIME
    assert m["data_format"] == "insert"
    assert m["target_schemas"] == ["livebit_dbo", "livebit_divadim"]
    counts = m["counts"]
    assert counts["schemas"] == 2 and counts["tables"] == 3 and counts["views"] == 1
    assert counts["procedures"] == 1 and counts["functions"] == 1 and counts["rows"] == 3
    assert counts["data_files"] == 3
    assert counts["data_bytes"] == sum(
        (tmp_path / "livebit" / f).stat().st_size for t in m["tables"] for f in t["data_files"]
    )
    customer = next(t for t in m["tables"] if t["source"] == "dbo.Customer")
    assert customer == {
        "source": "dbo.Customer",
        "target_schema": "livebit_dbo",
        "target_table": "customer",
        "columns": 3,
        "column_names": ["id", "name", "datekey"],
        "approx_source_rows": 2,
        "exported_rows": 2,
        "table_file": "tables/livebit_dbo__customer.sql",
        "data_files": ["data/livebit_dbo__customer.sql"],
        "notes": [],
    }
    assert [t["source"] for t in m["tables"]] == ["dbo.AuditLog", "dbo.Customer", "divadim.DimDate"]
    assert m["views"] == [{
        "source": "dbo.v_customer", "target": "livebit_dbo.v_customer",
        "file": "views/livebit_dbo__v_customer.sql",
        "source_file": "source/views/livebit_dbo__v_customer.sql", "review_items": [],
    }]
    fn = next(r for r in m["routines"] if r["source"] == "divadim.fn_Top")
    assert fn["kind"] == "function" and fn["target"] == "livebit_divadim.fn_top"
    assert fn["file"] == "routines/livebit_divadim__fn_top.sql"
    assert fn["source_file"] == "source/routines/livebit_divadim__fn_top.sql"
    assert any("TOP n" in item for item in fn["review_items"])
    assert any(item.startswith("routine divadim.fn_Top:") for item in m["review_items"])
    assert m["warnings"] == []
    assert m["load_order"] == [
        "00_schemas.sql",
        "tables/livebit_dbo__auditlog.sql",
        "tables/livebit_dbo__customer.sql",
        "tables/livebit_divadim__dimdate.sql",
        "data/livebit_dbo__auditlog.sql",
        "data/livebit_dbo__customer.sql",
        "data/livebit_divadim__dimdate.sql",
        "sequences.sql",
        "foreign_keys.sql",
        "views/livebit_dbo__v_customer.sql",
        "routines/livebit_dbo__usp_get.sql",
        "routines/livebit_divadim__fn_top.sql",
    ]


def test_export_is_deterministic(tmp_path):
    def snapshot(root):
        return {p.relative_to(root).as_posix(): p.read_bytes()
                for p in sorted(root.rglob("*")) if p.is_file()}

    export_database(make_plan(), sample_db(), tmp_path / "a", reader_for(SAMPLE_ROWS),
                    generated_at=FIXED_TIME)
    export_database(make_plan(), sample_db(), tmp_path / "b", reader_for(SAMPLE_ROWS),
                    generated_at=FIXED_TIME)
    assert snapshot(tmp_path / "a") == snapshot(tmp_path / "b")


def _big_table(n_rows):
    table = Table(
        schema="dbo", name="Events",
        columns=[Column(name="Id", source_type="int", nullable=False, ordinal=1),
                 Column(name="Payload", source_type="nvarchar", char_length=-1, ordinal=2)],
        primary_key=Index(name="pk", columns=["Id"], unique=True, is_primary=True),
    )
    rows = [(i, f"payload {i} " + "x" * 200) for i in range(n_rows)]
    db = Database(subscription="s", server="srv", kind=SourceKind.AZURE_SQL, name="LiveBit",
                  tables=[table])
    return db, {"dbo.Events": rows}


@pytest.mark.parametrize("data_format,ext", [("insert", ".sql"), ("copy", ".tsv")])
def test_data_is_chunked_into_parts(tmp_path, data_format, ext):
    db, rows = _big_table(200)
    limit_mb = 0.01  # ~10 KB
    result = export_database(make_plan(batch_size=7), db, tmp_path, reader_for(rows, batch=13),
                             data_format=data_format, max_data_file_mb=limit_mb)
    data_dir = tmp_path / "livebit" / "data"
    parts = sorted(data_dir.iterdir())
    assert len(parts) > 3
    assert [p.name for p in parts] == [
        f"livebit_dbo__events.part{i:04d}{ext}" for i in range(1, len(parts) + 1)
    ]
    assert all(p.stat().st_size <= limit_mb * 1024 * 1024 for p in parts)
    assert result.data_files == [f"data/{p.name}" for p in parts]
    m = read_manifest(tmp_path / "livebit")
    assert m["tables"][0]["data_files"] == result.data_files
    assert m["counts"]["data_files"] == len(parts)

    if data_format == "copy":
        lines = [line for p in parts for line in p.read_text().splitlines()]
        assert lines == [f"{i}\tpayload {i} " + "x" * 200 for i in range(200)]
    else:
        stmts = [s for p in parts for s in split_sql_statements(p.read_text())]
        per_stmt = [s.count("\n(") for s in stmts]
        assert sum(per_stmt) == 200
        assert max(per_stmt) == 7  # batch_size rows per INSERT


def test_insert_statement_flushed_at_one_megabyte(tmp_path):
    table = Table(schema="dbo", name="Blobs",
                  columns=[Column(name="Id", source_type="int", ordinal=1),
                           Column(name="Body", source_type="nvarchar", char_length=-1, ordinal=2)])
    rows = [(i, "y" * 300_000) for i in range(10)]
    db = Database(subscription="s", server="srv", kind=SourceKind.AZURE_SQL, name="LiveBit",
                  tables=[table])
    export_database(make_plan(batch_size=5000), db, tmp_path, reader_for({"dbo.Blobs": rows}))
    text = (tmp_path / "livebit/data/livebit_dbo__blobs.sql").read_text()
    stmts = split_sql_statements(text)
    assert [s.count("\n(") for s in stmts] == [4, 4, 2]


def test_schema_only_export(tmp_path):
    plan = make_plan()
    plan.migration.data = False
    result = export_database(plan, sample_db(), tmp_path, reader_for(SAMPLE_ROWS))
    db_dir = tmp_path / "livebit"
    assert result.rows == 0
    assert not (db_dir / "data").exists()
    m = read_manifest(db_dir)
    assert m["data_format"] is None
    assert all(t["exported_rows"] is None and t["data_files"] == [] for t in m["tables"])
    assert not any(p.startswith("data/") for p in m["load_order"])
    assert any("schema only" in w for w in m["warnings"])


def test_nul_characters_are_stripped_and_reported(tmp_path):
    rows = dict(SAMPLE_ROWS)
    rows["dbo.Customer"] = [(1, "a\x00b\x00", None), (2, "\x00", None)]
    export_database(make_plan(), sample_db(), tmp_path, reader_for(rows))
    data = (tmp_path / "livebit/data/livebit_dbo__customer.sql").read_text()
    assert "\x00" not in data and "(1, 'ab', NULL)" in data and "(2, '', NULL)" in data
    warnings = read_manifest(tmp_path / "livebit")["warnings"]
    assert any(w.startswith("dbo.Customer: stripped 3 NUL") for w in warnings)


def test_unpaired_surrogates_are_replaced_and_reported(tmp_path):
    rows = dict(SAMPLE_ROWS)
    rows["dbo.Customer"] = [(1, "bad \ud800 char", None)]
    export_database(make_plan(), sample_db(), tmp_path, reader_for(rows), data_format="copy")
    data = (tmp_path / "livebit/data/livebit_dbo__customer.tsv").read_text(encoding="utf-8")
    assert data == "1\tbad � char\t\\N\n"
    warnings = read_manifest(tmp_path / "livebit")["warnings"]
    assert any("replaced 1 invalid Unicode" in w for w in warnings)


def test_row_width_mismatch_is_an_error(tmp_path):
    rows = dict(SAMPLE_ROWS)
    rows["dbo.Customer"] = [(1, "only two values")]
    with pytest.raises(ValueError, match="dbo.Customer"):
        export_database(make_plan(), sample_db(), tmp_path, reader_for(rows))
    assert not (tmp_path / "livebit/manifest.json").exists()


def test_invalid_arguments(tmp_path):
    with pytest.raises(ValueError):
        export_database(make_plan(), sample_db(), tmp_path, None, data_format="csv")
    with pytest.raises(ValueError):
        export_database(make_plan(), sample_db(), tmp_path, None, max_data_file_mb=0)


def test_previous_export_files_are_removed(tmp_path):
    db_dir = tmp_path / "livebit"
    (db_dir / "data").mkdir(parents=True)
    stale = [db_dir / "01_schema.sql", db_dir / "04_foreign_keys.sql",
             db_dir / "data" / "livebit_dbo__old.part0009.sql", db_dir / "load_report.json"]
    for p in stale:
        p.write_text("stale")
    keep = db_dir / "NOTES.md"
    keep.write_text("mine")
    export_database(make_plan(), sample_db(), tmp_path, reader_for(SAMPLE_ROWS))
    assert not any(p.exists() for p in stale)
    assert keep.read_text() == "mine"


def test_views_ordered_by_dependency(tmp_path):
    db = sample_db()
    db.views = [
        View(schema="dbo", name="v_a_latest",
             definition="CREATE VIEW dbo.v_a_latest AS SELECT [Id] FROM [dbo].[v_customer]"),
        View(schema="dbo", name="v_customer",
             definition="CREATE VIEW dbo.v_customer AS SELECT [Id] FROM [dbo].[Customer]"),
    ]
    export_database(make_plan(), db, tmp_path, None)
    order = read_manifest(tmp_path / "livebit")["load_order"]
    views = [p for p in order if p.startswith("views/")]
    assert views == ["views/livebit_dbo__v_customer.sql", "views/livebit_dbo__v_a_latest.sql"]


def test_colliding_file_names_are_made_unique(tmp_path):
    db = sample_db()
    db.tables.append(Table(schema="dbo", name="Customer ", columns=[
        Column(name="Id", source_type="int", ordinal=1)]))
    rows = dict(SAMPLE_ROWS)
    rows["dbo.Customer "] = [(9,)]
    export_database(make_plan(), db, tmp_path, reader_for(rows))
    db_dir = tmp_path / "livebit"
    assert (db_dir / "tables/livebit_dbo__customer_2.sql").exists()
    assert (db_dir / "data/livebit_dbo__customer_2.sql").exists()
    m = read_manifest(db_dir)
    assert any("customer_2" in w for w in m["warnings"])


def test_float_and_decimal_values_in_insert_file(tmp_path):
    table = Table(schema="dbo", name="Nums",
                  columns=[Column(name="F", source_type="float", ordinal=1),
                           Column(name="D", source_type="decimal", numeric_precision=18,
                                  numeric_scale=2, ordinal=2)])
    db = Database(subscription="s", server="srv", kind=SourceKind.AZURE_SQL, name="LiveBit",
                  tables=[table])
    rows = {"dbo.Nums": [(float("nan"), Decimal("1.50")), (math.inf, None)]}
    export_database(make_plan(), db, tmp_path, reader_for(rows))
    text = (tmp_path / "livebit/data/livebit_dbo__nums.sql").read_text()
    assert "('NaN'::float8, 1.50)" in text
    assert "('Infinity'::float8, NULL)" in text
