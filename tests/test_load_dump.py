"""End-to-end: export a LiveBit-like database, load it into a real PostgreSQL, verify.

Uses the throwaway cluster from ``conftest.py`` (skipped when PostgreSQL is not
installed); every test gets its own fresh database.
"""

import json
import math
import uuid
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal

import pytest
from click.testing import CliRunner

from dbmigration.cli import main
from dbmigration.config import (
    DiscoveryConfig,
    MigrationConfig,
    NamingConfig,
    Plan,
    RoutinesConfig,
    TargetConfig,
)
from dbmigration.exporter import export_database, load_dump
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

psycopg = pytest.importorskip("psycopg")

IST = timezone(timedelta(hours=5, minutes=30))
PST = timezone(timedelta(hours=-8))
TRICKY = [
    "O'Brien & Co",
    "back\\slash \\N \\x41",
    "\\.",
    "\\N",
    "tab\there",
    "multi\nline\r\ntext\r",
    "semi; colon -- dash /* star */ $$ $tag$ %s %(x)s",
    "unicode: café Ωμέγα 日本語 🚀👩‍💻",
    "nul\x00in\x00side",
    "",
    "'",
    "''",
    '"double"',
    "\\",
    "ends with backslash\\",
    "   padded   ",
]


def make_plan(batch_size: int = 7) -> Plan:
    return Plan(
        target=TargetConfig(supabase_project_ref="example-ref"),
        naming=NamingConfig(),
        discovery=DiscoveryConfig(),
        migration=MigrationConfig(batch_size=batch_size),
        routines=RoutinesConfig(),
    )


def livebit_db() -> Database:
    dimdate = Table(
        schema="divadim", name="DimDate",
        columns=[
            Column("DateKey", "int", nullable=False, ordinal=1),
            Column("FullDate", "date", ordinal=2),
            Column("Label", "nvarchar", char_length=50, ordinal=3),
        ],
        primary_key=Index("PK_DimDate", ["DateKey"], unique=True, is_primary=True),
        approx_row_count=3,
    )
    customers = Table(
        schema="dbo", name="Customers",
        columns=[
            Column("Id", "int", nullable=False, is_identity=True, ordinal=1),
            Column("Name", "nvarchar", char_length=200, nullable=False, ordinal=2),
            Column("Notes", "nvarchar", char_length=-1, ordinal=3),
            Column("IsActive", "bit", nullable=False, default="((1))", ordinal=4),
            Column("Balance", "decimal", numeric_precision=18, numeric_scale=2, ordinal=5),
            Column("ExternalId", "uniqueidentifier", ordinal=6),
            Column("UpdatedAt", "datetimeoffset", numeric_scale=7, ordinal=7),
            Column("Photo", "varbinary", char_length=-1, ordinal=8),
            Column("Profile", "xml", ordinal=9),
            Column("BirthDate", "date", ordinal=10),
            Column("DateKey", "int", ordinal=11),
            Column("Score", "float", ordinal=12),
        ],
        primary_key=Index("PK_Customers", ["Id"], unique=True, is_primary=True),
        indexes=[Index("IX_Customers_Name", ["Name"])],
        foreign_keys=[ForeignKey("FK_Customers_DimDate", ["DateKey"], "divadim", "DimDate",
                                 ["DateKey"])],
        approx_row_count=60,
    )
    audit = Table(
        schema="dbo", name="AuditLog",
        columns=[
            Column("Id", "bigint", nullable=False, is_identity=True, ordinal=1),
            Column("Message", "nvarchar", char_length=-1, ordinal=2),
        ],
        primary_key=Index("PK_AuditLog", ["Id"], unique=True, is_primary=True),
        approx_row_count=0,
    )
    scratch = Table(  # capitalised schema, a name with a space, no primary key
        schema="Sandbox", name="Scratch Pad",
        columns=[
            Column("Key", "varchar", char_length=10, nullable=False, ordinal=1),
            Column("Value", "nvarchar", char_length=-1, ordinal=2),
            Column("Flag", "bit", ordinal=3),
            Column("Tiny", "tinyint", ordinal=4),
        ],
        approx_row_count=2,
    )
    views = [
        View("dbo", "v_CustomerDates",
             "CREATE VIEW [dbo].[v_CustomerDates] AS\r\n"
             "SELECT c.[Id], c.[Name], d.[FullDate]\r\n"
             "FROM [dbo].[Customers] c\r\n"
             "JOIN [divadim].[DimDate] d ON d.[DateKey] = c.[DateKey]\r\n"),
        # Sorts first by name but reads the view above: must load after it.
        View("dbo", "v_A_Dated",
             "CREATE VIEW dbo.v_A_Dated AS SELECT [Id], [FullDate] FROM [dbo].[v_CustomerDates] "
             "WHERE [FullDate] IS NOT NULL"),
    ]
    routines = [
        Routine("dbo", "usp_TouchCustomer", "procedure", "tsql",
                "CREATE PROCEDURE [dbo].[usp_TouchCustomer] @CustomerId int AS\r\n"
                "UPDATE dbo.Customers SET Name = Name WHERE Id = @CustomerId;\r\n"),
    ]
    return Database(subscription="(direct)", server="coe-index-db-server.database.windows.net",
                    kind=SourceKind.AZURE_SQL, name="LiveBit",
                    tables=[customers, dimdate, audit, scratch], views=views, routines=routines)


def customer_rows() -> list[tuple]:
    rows = []
    for i in range(60):
        rows.append((
            2 * i + 1,  # identity with gaps; max id = 119
            f"{TRICKY[i % len(TRICKY)]} #{i}",
            None if i % 5 == 0 else TRICKY[(i * 3) % len(TRICKY)] * (1 + (i % 3) * 40),
            i % 2 == 0,
            [Decimal("-12345.67"), Decimal("0.00"), Decimal("9999999999999999.99"),
             Decimal("0.01"), None][i % 5],
            None if i % 7 == 0 else uuid.UUID(int=(i * 7919) << 64 | i),
            None if i % 11 == 0 else datetime(2026, 1, 1 + i % 28, i % 24, i % 60, i % 60,
                                              (i * 12345) % 1_000_000,
                                              tzinfo=[IST, timezone.utc, PST][i % 3]),
            [bytes(range(256)), b"", b"\x00\x00'\\\"\n\t", None][i % 4],
            ['<root a="1">text &amp; more</root>', "<a/><b>fragment</b>", None][i % 3],
            [date(1990, 5, 17), date(1, 1, 1), date(9999, 12, 31), None][i % 4],
            [20260101, 20260102, None][i % 3],
            [1.5, float("nan"), float("inf"), float("-inf"), 1e-300, 1.7976931348623157e308,
             -0.25, None][i % 8],
        ))
    return rows


ROWS = {
    "dbo.Customers": customer_rows(),
    "divadim.DimDate": [
        (20260101, date(2026, 1, 1), "New Year's Day"),
        (20260102, date(2026, 1, 2), "Friday 🎉"),
        (20260103, None, None),
    ],
    "dbo.AuditLog": [],
    "Sandbox.Scratch Pad": [("a", "x\ty", True, 255), ("b", None, None, 0)],
}


def reader(table: Table):
    rows = ROWS[table.qualified]
    for i in range(0, len(rows), 5):
        yield rows[i:i + 5]


def export(tmp_path, data_format: str):
    return export_database(make_plan(), livebit_db(), tmp_path / "export", reader,
                           data_format=data_format, max_data_file_mb=0.01)


def fetch(url: str, sql: str) -> list[tuple]:
    with psycopg.connect(url) as conn:
        return conn.execute(sql).fetchall()


def expected_customer(row: tuple) -> tuple:
    return tuple(v.replace("\x00", "") if isinstance(v, str) else v for v in row)


def assert_same(actual, expected):
    if isinstance(expected, float) and math.isnan(expected):
        assert isinstance(actual, float) and math.isnan(actual)
    else:
        assert actual == expected
        assert type(actual) is type(expected) or expected is None


@pytest.mark.parametrize("data_format", ["insert", "copy"])
def test_export_then_load_round_trips_exactly(tmp_path, pg_database, data_format):
    result = export(tmp_path, data_format)
    db_dir = result.out_dir
    manifest = json.loads((db_dir / "manifest.json").read_text(encoding="utf-8"))
    customers = next(t for t in manifest["tables"] if t["source"] == "dbo.Customers")
    assert len(customers["data_files"]) > 1  # forced into several parts
    assert all(f.startswith("data/livebit_dbo__customers.part") for f in customers["data_files"])
    assert any("NUL" in w for w in manifest["warnings"])
    views = [p for p in manifest["load_order"] if p.startswith("views/")]
    assert views == ["views/livebit_dbo__v_customerdates.sql", "views/livebit_dbo__v_a_dated.sql"]

    report = load_dump(db_dir, pg_database)

    assert report["failures"] == []
    assert report["ok"] is True
    for kind in ("schemas", "tables", "data", "sequences", "foreign_keys", "views", "routines"):
        assert report["by_kind"][kind]["failed"] == 0, kind
        assert report["by_kind"][kind]["ok"] > 0, kind
    assert not any("attempts" in r for r in report["results"])  # views already in order
    assert report["totals"]["rows_loaded"] == 65
    checks = {c["table"]: (c["expected"], c["actual"], c["match"]) for c in report["row_checks"]}
    assert checks == {
        "livebit_dbo.auditlog": (0, 0, True),
        "livebit_dbo.customers": (60, 60, True),
        "livebit_divadim.dimdate": (3, 3, True),
        "livebit_sandbox.scratch_pad": (2, 2, True),
    }

    # Every value round-trips exactly (NUL characters stripped).
    got = fetch(pg_database,
                "SELECT id, name, notes, isactive, balance, externalid, updatedat, photo, "
                "profile, birthdate, datekey, score FROM livebit_dbo.customers ORDER BY id")
    expected = [expected_customer(r) for r in ROWS["dbo.Customers"]]
    assert len(got) == len(expected)
    for actual_row, expected_row in zip(got, expected):
        for actual, want in zip(actual_row, expected_row):
            assert_same(actual, want)
    assert fetch(pg_database, "SELECT * FROM livebit_divadim.dimdate ORDER BY datekey") == \
        ROWS["divadim.DimDate"]
    assert fetch(pg_database, "SELECT key, value, flag, tiny FROM livebit_sandbox.scratch_pad "
                              "ORDER BY key") == ROWS["Sandbox.Scratch Pad"]

    with psycopg.connect(pg_database) as conn:
        # Identity continues after the highest loaded id; bit default ((1)) -> true.
        new_id, active = conn.execute(
            "INSERT INTO livebit_dbo.customers (name) VALUES ('new') RETURNING id, isactive"
        ).fetchone()
        assert (new_id, active) == (120, True)
        assert conn.execute(
            "INSERT INTO livebit_dbo.auditlog (message) VALUES ('first') RETURNING id"
        ).fetchone() == (1,)
        # The cross-schema foreign key is enforced.
        with pytest.raises(psycopg.errors.ForeignKeyViolation):
            conn.execute("INSERT INTO livebit_dbo.customers (name, datekey) VALUES ('x', 1)")
        conn.rollback()
        assert conn.execute("SELECT count(*) FROM livebit_dbo.v_a_dated").fetchone() == (40,)
        assert conn.execute(
            "SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace "
            "WHERE n.nspname = 'livebit_dbo' AND p.proname = 'usp_touchcustomer'"
        ).fetchone() == (1,)


def test_failures_are_recorded_and_loading_continues(tmp_path, pg_database):
    db_dir = export(tmp_path, "insert").out_dir
    manifest = json.loads((db_dir / "manifest.json").read_text(encoding="utf-8"))
    broken = next(f for f in manifest["load_order"] if f.startswith("data/livebit_dbo__customers"))
    path = db_dir / broken
    path.write_text(path.read_text(encoding="utf-8").replace("VALUES\n(", "VALUES\n(oops ", 1),
                    encoding="utf-8")

    report = load_dump(db_dir, pg_database)

    assert report["ok"] is False
    assert [f["file"] for f in report["failures"]] == [broken]
    failure = report["failures"][0]
    assert failure["statement"].startswith('INSERT INTO "livebit_dbo"."customers"')
    assert "syntax error" in failure["error"]
    # Everything else still loaded, and the lost rows show up as a mismatch.
    assert report["by_kind"]["foreign_keys"]["failed"] == 0
    assert report["by_kind"]["views"]["failed"] == 0
    mismatches = [c for c in report["row_checks"] if not c["match"]]
    assert [c["table"] for c in mismatches] == ["livebit_dbo.customers"]
    assert 0 < mismatches[0]["actual"] < 60
    assert report["totals"]["row_mismatches"] == 1


def test_stop_on_error_stops_at_first_failure(tmp_path, pg_database):
    db_dir = export(tmp_path, "copy").out_dir
    (db_dir / "tables/livebit_dbo__customers.sql").write_text("CREATE TABLE broken (;\n")

    report = load_dump(db_dir, pg_database, stop_on_error=True)

    assert report["ok"] is False and report["stopped_early"] is True
    assert report["results"][-1]["file"] == "tables/livebit_dbo__customers.sql"
    assert not any(r["file"].startswith("data/") for r in report["results"])
    assert report["row_checks"] == []


def test_view_needing_a_later_function_is_retried(tmp_path, pg_database):
    items = Table(schema="public", name="items",
                  columns=[Column("id", "integer", nullable=False, ordinal=1)],
                  primary_key=Index("items_pkey", ["id"], unique=True, is_primary=True))
    db = Database(
        subscription="s", server="pg", kind=SourceKind.AZURE_POSTGRES, name="App",
        tables=[items],
        views=[View("public", "doubled", " SELECT public.fn_double(items.id) AS d\n   FROM public.items;")],
        routines=[Routine("public", "fn_double", "function", "sql",
                          "CREATE OR REPLACE FUNCTION public.fn_double(x integer) RETURNS integer "
                          "LANGUAGE sql AS $$ SELECT x * 2 $$")],
    )
    export_database(make_plan(), db, tmp_path, lambda t: iter([[(1,), (2,)]]))

    report = load_dump(tmp_path / "app", pg_database)

    assert report["ok"] is True, report["failures"]
    view = next(r for r in report["results"] if r["file"].startswith("views/"))
    assert view["attempts"] == 2
    assert fetch(pg_database, "SELECT d FROM app_public.doubled ORDER BY d") == [(2,), (4,)]


@pytest.mark.parametrize("stop_on_error", [False, True])
def test_view_that_never_loads_is_recorded_once(tmp_path, pg_database, stop_on_error):
    db_dir = export(tmp_path, "copy").out_dir
    (db_dir / "views/livebit_dbo__v_customerdates.sql").write_text(
        "CREATE VIEW livebit_dbo.v_customerdates AS SELECT TOP 1 id FROM livebit_dbo.customers;\n"
    )

    report = load_dump(db_dir, pg_database, stop_on_error=stop_on_error)

    assert report["ok"] is False
    assert report["stopped_early"] is stop_on_error
    failed = [r for r in report["results"] if not r["ok"]]
    # The dependent view fails too; each is recorded once, after a retry.
    assert sorted(r["file"] for r in failed) == [
        "views/livebit_dbo__v_a_dated.sql", "views/livebit_dbo__v_customerdates.sql"]
    assert all(r["attempts"] == 2 for r in failed)
    assert report["by_kind"]["routines"] == {"ok": 1, "failed": 0}
    assert report["by_kind"]["data"]["failed"] == 0
    assert (report["row_checks"] == []) is stop_on_error


def test_unusable_inputs_are_reported_not_raised(tmp_path):
    missing = load_dump(tmp_path, "postgresql://u@/db?host=/nonexistent")
    assert missing["ok"] is False
    assert missing["failures"][0]["file"] == "manifest.json"

    export_database(make_plan(), livebit_db(), tmp_path, reader)
    url = "postgresql://migrator:TopSecretPw1@/postgres?host=/nonexistent-dir&port=1"
    report = load_dump(tmp_path / "livebit", url)
    assert report["ok"] is False
    assert report["failures"][0]["file"] == "(connect)"
    assert report["target"] == "postgresql://migrator:***@/postgres?host=/nonexistent-dir&port=1"
    assert "TopSecretPw1" not in json.dumps(report)


def test_manifest_paths_cannot_escape_the_dump(tmp_path, pg_database):
    export_database(make_plan(), livebit_db(), tmp_path, None)
    (tmp_path / "outside.sql").write_text("CREATE TABLE escaped (id int);\n")
    manifest_path = tmp_path / "livebit" / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["load_order"].insert(1, "../outside.sql")
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

    report = load_dump(tmp_path / "livebit", pg_database)

    assert [f["file"] for f in report["failures"]] == ["../outside.sql"]
    assert fetch(pg_database, "SELECT to_regclass('public.escaped') IS NULL") == [(True,)]


# --- CLI ------------------------------------------------------------------------

def test_cli_export_and_load_dump(tmp_path, pg_database, monkeypatch):
    from dbmigration import runner
    from dbmigration.extract import mssql

    class FakeConn:
        def close(self):
            pass

    monkeypatch.setattr(runner, "extract_source", lambda *a, **k: livebit_db())
    monkeypatch.setattr(runner, "connect_source", lambda *a, **k: FakeConn())
    monkeypatch.setattr(mssql, "iter_table_rows", lambda conn, table, batch: reader(table))
    monkeypatch.delenv("SUPABASE_DB_URL", raising=False)
    config = tmp_path / "migration.yaml"
    config.write_text("target:\n  supabase_project_ref: example-ref\nmigration:\n  batch_size: 7\n")
    runner_cli = CliRunner()

    out = runner_cli.invoke(main, [
        "export", "-c", str(config), "-d", "LiveBit", "--server-host", "example.invalid",
        "--out", str(tmp_path / "export"), "--max-data-file-mb", "0.01",
    ])
    assert out.exit_code == 0, out.output
    assert "Procedures" in out.output and "Data files" in out.output
    db_dir = tmp_path / "export" / "livebit"
    manifest = json.loads((db_dir / "manifest.json").read_text(encoding="utf-8"))
    assert manifest["counts"]["rows"] == 65 and manifest["counts"]["data_files"] > 4

    # Trust auth ignores the password; it must still never be printed or stored.
    url = pg_database.replace("postgresql://postgres@", "postgresql://postgres:TopSecretPw1@")
    report_path = tmp_path / "reports" / "load.json"
    out = runner_cli.invoke(main, ["load-dump", str(db_dir), "--target-url", url,
                                   "--report", str(report_path)])
    assert out.exit_code == 0, out.output
    assert "TopSecretPw1" not in out.output
    report_text = report_path.read_text(encoding="utf-8")
    assert "TopSecretPw1" not in report_text
    report = json.loads(report_text)
    assert report["ok"] is True and report["totals"]["failed"] == 0
    assert "postgres:***@" in report["target"]

    # Loading again: CREATE ... IF NOT EXISTS is fine but rows double and PKs clash.
    out = runner_cli.invoke(main, ["load-dump", str(db_dir), "--target-url", url])
    assert out.exit_code == 1
    assert (db_dir / "load_report.json").exists()
    assert "FAILED" in out.output


def test_cli_load_dump_uses_supabase_db_url(tmp_path, pg_database, monkeypatch):
    export_database(make_plan(), livebit_db(), tmp_path, reader)
    monkeypatch.setenv("SUPABASE_DB_URL", pg_database)
    out = CliRunner().invoke(main, ["load-dump", str(tmp_path / "livebit"),
                                    "-c", str(tmp_path / "no-such-config.yaml")])
    assert out.exit_code == 0, out.output
    assert json.loads((tmp_path / "livebit" / "load_report.json").read_text())["ok"] is True
