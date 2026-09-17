from dbmigration.model import SourceKind, View
from dbmigration.transform.views import convert_view


def make_view(defn, schema="dbo", name="v_active"):
    return View(schema=schema, name=name, definition=defn)


def test_mssql_view_basic_conversion():
    defn = "CREATE VIEW dbo.v_active AS SELECT [Id], [Name] FROM [dbo].[Customers] WHERE IsActive = 1"
    smap = {"dbo": "livebit_dbo"}
    out = convert_view(make_view(defn), "livebit_dbo", smap, SourceKind.AZURE_SQL)
    assert 'CREATE OR REPLACE VIEW "livebit_dbo"."v_active" AS' in out.ddl
    # Simple bracketed identifiers fold to bare lower-case (match created columns).
    assert "SELECT id, name" in out.ddl
    # dbo. qualifier retargeted to livebit_dbo., table folded to lower-case.
    assert '"livebit_dbo".customers' in out.ddl


def test_mssql_view_quotes_complex_identifier():
    defn = "CREATE VIEW dbo.v AS SELECT [Full Name] FROM [dbo].[T]"
    out = convert_view(make_view(defn), "s", {"dbo": "s"}, SourceKind.AZURE_SQL)
    assert '"Full Name"' in out.ddl  # space -> stays quoted


def test_cross_schema_reference_retargeted():
    defn = "CREATE VIEW dbo.v_join AS SELECT * FROM dbo.A JOIN divadim.B ON A.id = B.id"
    smap = {"dbo": "livebit_dbo", "divadim": "livebit_divadim"}
    out = convert_view(make_view(defn), "livebit_dbo", smap, SourceKind.AZURE_SQL)
    assert '"livebit_divadim".' in out.ddl
    assert '"livebit_dbo".' in out.ddl


def test_view_getdate_rewritten():
    defn = "CREATE VIEW dbo.v AS SELECT GETDATE() AS now_ts"
    out = convert_view(make_view(defn), "s", {"dbo": "s"}, SourceKind.AZURE_SQL)
    assert "now()" in out.ddl
    assert "GETDATE" not in out.ddl


def test_view_top_flagged():
    defn = "CREATE VIEW dbo.v AS SELECT TOP 10 * FROM T"
    out = convert_view(make_view(defn), "s", {"dbo": "s"}, SourceKind.AZURE_SQL)
    assert out.needs_review
    assert any("top" in f.message.lower() for f in out.flags)


def test_postgres_view_passthrough():
    v = View(schema="public", name="v_x", definition="SELECT a, b FROM public.t")
    out = convert_view(v, "mydb_public", {"public": "mydb_public"}, SourceKind.AZURE_POSTGRES)
    assert 'CREATE OR REPLACE VIEW "mydb_public"."v_x" AS' in out.ddl
    assert '"mydb_public".' in out.ddl
