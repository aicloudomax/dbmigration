"""Target identifier construction and sanitization.

Every source database is mapped to ONE schema in the target Supabase database.
The schema name is derived from a template (default ``{db}_{schema}``) and then
sanitized into a legal Postgres identifier.
"""

from __future__ import annotations

import hashlib
import re

# Postgres identifiers are limited to 63 bytes and are folded to lower case
# unless quoted. We always produce quoted-safe, lower-case identifiers.
MAX_IDENTIFIER_LEN = 63

_INVALID = re.compile(r"[^a-z0-9_]+")
_LEADING = re.compile(r"^[^a-z_]+")


def sanitize_identifier(value: str) -> str:
    """Fold *value* into a legal, lower-case Postgres identifier.

    Non-alphanumeric characters become underscores, leading digits are prefixed
    with ``_``, and the result is truncated to 63 chars. A short hash suffix is
    appended when truncation happens so distinct long names stay distinct.
    """
    lowered = value.strip().lower()
    cleaned = _INVALID.sub("_", lowered).strip("_")
    if not cleaned:
        cleaned = "obj"
    if _LEADING.match(cleaned):
        cleaned = f"_{cleaned}"
    if len(cleaned) > MAX_IDENTIFIER_LEN:
        digest = hashlib.sha1(value.encode("utf-8")).hexdigest()[:6]
        cleaned = f"{cleaned[: MAX_IDENTIFIER_LEN - 7]}_{digest}"
    return cleaned


def target_schema_name(
    template: str,
    *,
    subscription: str,
    server: str,
    db: str,
    schema: str,
) -> str:
    """Render and sanitize the target schema name for a source (db, schema)."""
    rendered = template.format(
        subscription=subscription,
        server=server,
        db=db,
        schema=schema,
    )
    return sanitize_identifier(rendered)


def quote_ident(name: str) -> str:
    """Double-quote an identifier for safe SQL emission."""
    escaped = name.replace('"', '""')
    return f'"{escaped}"'
