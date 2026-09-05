from dbmigration.naming import quote_ident, sanitize_identifier, target_schema_name


def test_sanitize_basic():
    assert sanitize_identifier("Sales") == "sales"
    assert sanitize_identifier("My DB-Name") == "my_db_name"


def test_sanitize_leading_digit():
    assert sanitize_identifier("123abc").startswith("_")


def test_sanitize_empty_becomes_obj():
    assert sanitize_identifier("!!!") == "obj"


def test_sanitize_truncates_with_hash():
    long = "x" * 100
    result = sanitize_identifier(long)
    assert len(result) <= 63
    # Distinct long names stay distinct.
    other = "x" * 99 + "y"
    assert sanitize_identifier(other) != result


def test_target_schema_template():
    name = target_schema_name(
        "{db}_{schema}", subscription="sub", server="srv", db="Sales", schema="dbo"
    )
    assert name == "sales_dbo"


def test_quote_ident_escapes():
    assert quote_ident('we"ird') == '"we""ird"'
