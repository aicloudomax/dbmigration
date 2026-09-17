"""Best-effort conversion of source views to Postgres ``CREATE VIEW``.

MS SQL view bodies are T-SQL. Because every source schema of a database maps to
its own target schema *in the same* Supabase database, cross-schema references
inside a view can be preserved by rewriting each source-schema qualifier to its
target-schema name. Scalar T-SQL constructs are rewritten with the same rules as
the procedure converter, and anything non-mechanical is flagged for review.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

from ..model import SourceKind, View
from ..naming import quote_ident, sanitize_identifier
from .tsql_to_plpgsql import _MANUAL_PATTERNS, _SCALAR_REWRITES, ConversionFlag

_CREATE_VIEW_RE = re.compile(
    r"CREATE\s+(?:OR\s+ALTER\s+)?VIEW\s+.*?\bAS\b",
    re.IGNORECASE | re.DOTALL,
)

# [bracketed] identifiers. Simple names fold to bare lower-case (matching the
# lower-cased, sanitized table/column names we emit); names with spaces or other
# characters are double-quoted.
_BRACKET_RE = re.compile(r"\[([^\]]+)\]")
_SIMPLE_IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def _debracket(match: re.Match) -> str:
    inner = match.group(1)
    if _SIMPLE_IDENT.match(inner):
        return inner.lower()
    return quote_ident(inner)


@dataclass
class ViewConversion:
    target_schema: str
    view_name: str
    ddl: str
    flags: list[ConversionFlag] = field(default_factory=list)

    @property
    def needs_review(self) -> bool:
        return any(f.severity == "manual" for f in self.flags)


def _rewrite_schema_qualifiers(body: str, schema_map: dict[str, str]) -> str:
    """Rewrite ``srcschema.`` qualifiers to the mapped target schema.

    Handles the qualifier bare (``dbo.``), bracketed (``[dbo].``), or already
    double-quoted (``"dbo".``) — bracket-to-quote conversion may run first.
    """
    for src, tgt in schema_map.items():
        pattern = re.compile(
            rf'(?<![\w.])["\[]?{re.escape(src)}["\]]?\s*\.',
            re.IGNORECASE,
        )
        body = pattern.sub(f"{quote_ident(tgt)}.", body)
    return body


def convert_view(
    view: View,
    target_schema: str,
    schema_map: dict[str, str],
    source_kind: SourceKind,
) -> ViewConversion:
    """Convert one :class:`View` to a Postgres ``CREATE OR REPLACE VIEW`` DDL."""
    view_name = sanitize_identifier(view.name)
    qualified = f"{quote_ident(target_schema)}.{quote_ident(view_name)}"
    flags: list[ConversionFlag] = []

    if source_kind == SourceKind.AZURE_POSTGRES:
        # pg_views.definition is already a Postgres SELECT body.
        body = _rewrite_schema_qualifiers(view.definition, schema_map)
        ddl = f"CREATE OR REPLACE VIEW {qualified} AS\n{body.rstrip().rstrip(';')};"
        return ViewConversion(target_schema, view_name, ddl, flags)

    # MS SQL: isolate the SELECT body after CREATE VIEW ... AS.
    match = _CREATE_VIEW_RE.search(view.definition)
    body = view.definition[match.end():] if match else view.definition

    # [ident] -> bare lower-case (simple) or "quoted" (complex).
    body = _BRACKET_RE.sub(_debracket, body)
    # Scalar rewrites (GETDATE, ISNULL, ...).
    for pattern, replacement in _SCALAR_REWRITES:
        body = pattern.sub(replacement, body)
    # Re-target schema qualifiers so cross-schema references resolve.
    body = _rewrite_schema_qualifiers(body, schema_map)

    for pattern, description in _MANUAL_PATTERNS:
        for m in pattern.finditer(body):
            flags.append(ConversionFlag("manual", description, snippet=m.group(0)))

    review = "".join(
        f"-- REVIEW ({f.severity}): {f.message}" + (f"  [{f.snippet}]" if f.snippet else "") + "\n"
        for f in flags
    )
    ddl = f"{review}CREATE OR REPLACE VIEW {qualified} AS\n{body.strip().rstrip(';')};"
    return ViewConversion(target_schema, view_name, ddl, flags)
