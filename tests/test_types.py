from dbmigration.model import Column
from dbmigration.transform.types import map_column_type, map_default


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
