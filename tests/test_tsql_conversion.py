from dbmigration.model import Routine
from dbmigration.transform.tsql_to_plpgsql import convert_routine


def make(definition):
    return Routine(
        schema="dbo", name="usp_test", kind="procedure",
        language="tsql", definition=definition,
    )


def test_simple_procedure_converts():
    tsql = """
    CREATE PROCEDURE dbo.usp_GetActive
        @Since datetime
    AS
    BEGIN
        SELECT Id, Name FROM Customers WHERE UpdatedAt > @Since;
    END
    """
    r = convert_routine(make(tsql), "sales_dbo")
    assert r.converted
    assert "CREATE OR REPLACE FUNCTION" in r.ddl
    assert '"sales_dbo"."usp_test"' in r.ddl
    # @Since parameter sigil is removed in the body.
    assert "@Since" not in r.ddl
    assert "since" in r.ddl.lower()


def test_getdate_rewritten():
    tsql = "CREATE PROC dbo.p AS BEGIN SELECT GETDATE(); END"
    r = convert_routine(make(tsql), "s")
    assert "now()" in r.ddl
    assert "GETDATE" not in r.ddl


def test_isnull_rewritten_to_coalesce():
    tsql = "CREATE PROC dbo.p AS BEGIN SELECT ISNULL(x, 0); END"
    r = convert_routine(make(tsql), "s")
    assert "COALESCE(" in r.ddl


def test_cursor_flagged_for_manual_review():
    tsql = """
    CREATE PROC dbo.p AS
    BEGIN
        DECLARE c CURSOR FOR SELECT Id FROM T;
        OPEN c;
        FETCH NEXT FROM c;
    END
    """
    r = convert_routine(make(tsql), "s")
    assert r.needs_review
    assert any("cursor" in f.message.lower() for f in r.flags)


def test_dynamic_sql_flagged():
    tsql = "CREATE PROC dbo.p AS BEGIN EXEC('SELECT 1'); END"
    r = convert_routine(make(tsql), "s")
    assert any("dynamic sql" in f.message.lower() for f in r.flags)


def test_top_flagged():
    tsql = "CREATE PROC dbo.p AS BEGIN SELECT TOP 10 * FROM T; END"
    r = convert_routine(make(tsql), "s")
    assert any("top" in f.message.lower() for f in r.flags)


def test_unparseable_header_inventoried():
    r = convert_routine(make("this is not a procedure"), "s")
    assert not r.converted
    assert r.needs_review


def test_postgres_routine_reschema():
    r = Routine(
        schema="public", name="get_x", kind="function", language="plpgsql",
        definition="CREATE OR REPLACE FUNCTION public.get_x() RETURNS int AS $$ BEGIN RETURN 1; END $$ LANGUAGE plpgsql;",
    )
    out = convert_routine(r, "mydb_public")
    assert '"mydb_public"."get_x"' in out.ddl
