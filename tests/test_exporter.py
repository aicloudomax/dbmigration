from dbmigration.config import (
    DiscoveryConfig,
    MigrationConfig,
    NamingConfig,
    Plan,
    RoutinesConfig,
    TargetConfig,
)
from dbmigration.exporter import encode_copy_row, encode_copy_value, export_database
from dbmigration.model import Column, Database, Index, Routine, SourceKind, Table, View


def make_plan():
    return Plan(
        target=TargetConfig(supabase_project_ref="mmbxootqppuvriodzetb"),
        naming=NamingConfig(),
        discovery=DiscoveryConfig(),
        migration=MigrationConfig(),
        routines=RoutinesConfig(),
    )


# --- COPY text encoder -------------------------------------------------------

def test_encode_none_is_backslash_n():
    assert encode_copy_value(None) == r"\N"


def test_encode_bool():
    assert encode_copy_value(True) == "t"
    assert encode_copy_value(False) == "f"


def test_encode_escapes_tab_newline_backslash():
    assert encode_copy_value("a\tb\nc\\d") == "a\\tb\\nc\\\\d"


def test_encode_bytes_hex():
    assert encode_copy_value(b"\xde\xad") == "\\\\xdead"  # escaped backslash + xdead


def test_encode_row_joins_with_tab():
    assert encode_copy_row((1, None, "x")) == "1\t\\N\tx\n"


# --- full export -------------------------------------------------------------

def sample_db():
    t = Table(
        schema="dbo",
        name="Customer",
        columns=[
            Column(name="Id", source_type="int", nullable=False, is_identity=True, ordinal=1),
            Column(name="Name", source_type="varchar", char_length=100, ordinal=2),
        ],
        primary_key=Index(name="pk", columns=["Id"], unique=True, is_primary=True),
        approx_row_count=2,
    )
    v = View(schema="dbo", name="v_customer", definition="CREATE VIEW dbo.v_customer AS SELECT [Id] FROM [dbo].[Customer]")
    r = Routine(schema="dbo", name="usp_get", kind="procedure", language="tsql",
                definition="CREATE PROC dbo.usp_get AS BEGIN SELECT GETDATE(); END")
    return Database(subscription="(direct)", server="srv", kind=SourceKind.AZURE_SQL,
                    name="LiveBit", tables=[t], views=[v], routines=[r])


def test_export_writes_expected_tree(tmp_path):
    plan = make_plan()
    db = sample_db()

    def reader(table):
        yield [(1, "Alice"), (2, "Bob")]

    result = export_database(plan, db, tmp_path, reader)
    db_dir = tmp_path / "livebit"

    assert (db_dir / "01_schema.sql").exists()
    assert (db_dir / "02_views.sql").exists()
    assert (db_dir / "03_routines.sql").exists()
    assert (db_dir / "manifest.json").exists()

    schema_sql = (db_dir / "01_schema.sql").read_text()
    assert 'CREATE SCHEMA IF NOT EXISTS "livebit_dbo"' in schema_sql
    assert 'CREATE TABLE IF NOT EXISTS "livebit_dbo"."customer"' in schema_sql

    data_file = db_dir / "data" / "livebit_dbo__customer.tsv"
    assert data_file.exists()
    assert data_file.read_text() == "1\tAlice\n2\tBob\n"

    assert result.tables == 1
    assert result.views == 1
    assert result.routines == 1
    assert result.rows == 2


def test_export_schema_only(tmp_path):
    plan = make_plan()
    plan.migration.data = False
    db = sample_db()
    result = export_database(plan, db, tmp_path, None)
    assert result.rows == 0
    # No data files written when data export is disabled.
    assert list((tmp_path / "livebit" / "data").glob("*.tsv")) == []
