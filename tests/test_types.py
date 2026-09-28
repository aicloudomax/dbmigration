import pytest

from dbmigration.model import Column
from dbmigration.transform.types import (
    map_column_type,
    map_default,
    strip_wrapping_parens,
    translate_default,
)


def col(source_type, **kw):
    return Column(name="c", source_type=source_type, **kw)


def test_int_maps_to_integer():
    assert map_column_type(col("int"), False).postgres_type == "integer"


def test_varchar_length_preserved():
    assert map_column_type(col("varchar", char_length=50), False).postgres_type == "varchar(50)"


def test_varchar_max_becomes_text():
    assert map_column_type(col("varchar", char_length=-1), False).postgres_type == "text"


def test_decimal_precision_scale():
    m = map_column_type(col("decimal", numeric_precision=10, numeric_scale=2), False)
    assert m.postgres_type == "numeric(10,2)"


def test_uniqueidentifier_to_uuid():
    assert map_column_type(col("uniqueidentifier"), False).postgres_type == "uuid"


def test_datetimeoffset_to_timestamptz():
    assert map_column_type(col("datetimeoffset"), False).postgres_type == "timestamptz"


def test_bit_to_boolean():
    assert map_column_type(col("bit"), False).postgres_type == "boolean"


def test_unknown_type_falls_back_to_text_with_note():
    m = map_column_type(col("weirdtype"), False)
    assert m.postgres_type == "text"
    assert m.note is not None


def test_postgres_passthrough():
    assert map_column_type(col("numeric(10,2)"), True).postgres_type == "numeric(10,2)"


def test_default_getdate_to_now():
    assert map_default("(getdate())", False) == "now()"


def test_default_newid_to_gen_random_uuid():
    assert map_default("(newid())", False) == "gen_random_uuid()"


def test_default_numeric_unwrapped():
    assert map_default("((0))", False) == "0"


def test_map_default_drops_untranslatable_expression():
    assert map_default("(CONVERT([bit],(0)))", False) is None


def test_map_default_postgres_passthrough():
    assert map_default("nextval('s'::regclass)", True) == "nextval('s'::regclass)"


@pytest.mark.parametrize(
    ("default", "pg_type", "expected"),
    [
        ("((1))", "boolean", "true"),
        ("((0))", "boolean", "false"),
        ("('1')", "boolean", "true"),
        ("((-1))", "integer", "-1"),
        ("(-(1))", "integer", "-1"),
        ("((0.50))", "numeric(18,2)", "0.50"),
        ("((0))", "varchar(5)", "'0'"),
        ("(N'abc')", "text", "'abc'"),
        ("('it''s')", "text", "'it''s'"),
        ("(N'')", "varchar(10)", "''"),
        ("('a)b')", "text", "'a)b'"),
        ("('42')", "integer", "42"),
        ("(getdate())", "timestamp", "now()"),
        ("(CURRENT_TIMESTAMP)", "timestamptz", "now()"),
        ("(sysdatetime())", "date", "now()"),
        ("(getutcdate())", "timestamp", "(now() at time zone 'utc')"),
        ("(sysutcdatetime())", "timestamp", "(now() at time zone 'utc')"),
        ("(newid())", "uuid", "gen_random_uuid()"),
        ("(newsequentialid())", "uuid", "gen_random_uuid()"),
        ("('1900-01-01')", "timestamp", "'1900-01-01'"),
        ("('00000000-0000-0000-0000-000000000000')", "uuid",
         "'00000000-0000-0000-0000-000000000000'"),
    ],
)
def test_translate_default_translated(default, pg_type, expected):
    result = translate_default(default, False, pg_type)
    assert (result.expr, result.note) == (expected, None)


@pytest.mark.parametrize("default", ["(NULL)", "((NULL))", None])
def test_translate_default_null_is_no_default(default):
    assert translate_default(default, False, "integer") == translate_default(None, False, None)
    assert translate_default(default, False, "integer").expr is None
    assert translate_default(default, False, "integer").note is None


@pytest.mark.parametrize(
    "default",
    ["(CONVERT([bit],(0)))", "(dateadd(day,(1),getdate()))", "([dbo].[fn]())",
     "((0)+(1))", "('a'+'b')", "(0x00)", "(user_name())"],
)
def test_translate_default_untranslatable_dropped(default):
    result = translate_default(default, False, "text")
    assert result.expr is None
    assert result.note == f"default {default} not translated; dropped"


@pytest.mark.parametrize(
    ("default", "pg_type"),
    [
        ("((0))", "timestamp"),  # MS SQL datetime 0 = 1900-01-01; PG rejects int
        ("('')", "uuid"),
        ("('not-a-uuid')", "uuid"),
        ("('2023-02-30')", "date"),
        ("('1/1/1900')", "timestamp"),
        ("('abc')", "integer"),
        ("('yes')", "boolean"),
        ("(getdate())", "varchar(20)"),
        ("(newid())", "varchar(10)"),
        ("((1))", "bytea"),
    ],
)
def test_translate_default_incompatible_dropped(default, pg_type):
    result = translate_default(default, False, pg_type)
    assert result.expr is None
    assert result.note == f"default {default} not compatible with {pg_type}; dropped"


def test_translate_default_postgres_source_unchanged():
    result = translate_default("'x'::text", True, "text")
    assert (result.expr, result.note) == ("'x'::text", None)


@pytest.mark.parametrize(
    ("expr", "expected"),
    [("((0))", "0"), ("(((getdate())))", "getdate()"), ("(a)+(b)", "(a)+(b)"),
     ("('(')", "'('"), ("x", "x")],
)
def test_strip_wrapping_parens(expr, expected):
    assert strip_wrapping_parens(expr) == expected


def test_datetimeoffset_mapping_notes_offset_loss():
    assert "offset" in map_column_type(col("datetimeoffset"), False).note


def test_sysname_maps_to_varchar():
    assert map_column_type(col("sysname", char_length=128), False).postgres_type == "varchar(128)"
