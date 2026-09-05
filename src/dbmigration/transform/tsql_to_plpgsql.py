"""Best-effort T-SQL stored procedure -> PL/pgSQL converter.

This is a *mechanical* converter: it rewrites the patterns that map cleanly and
leaves a clearly-marked flag for anything that needs a human. The goal is to get
the majority of straightforward CRUD/reporting procedures across automatically
while never silently producing wrong logic — every uncertain construct is
surfaced in ``ConversionResult.flags`` and echoed as a ``-- REVIEW:`` comment in
the emitted body.

It is deliberately not a full T-SQL parser. Complex procedures (cursors with
non-trivial control flow, dynamic SQL, temp tables, MERGE, etc.) are converted
as far as is safe and flagged for manual completion.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

from ..model import Routine
from ..naming import quote_ident, sanitize_identifier


@dataclass
class ConversionFlag:
    severity: str  # "warning" or "manual"
    message: str
    snippet: str | None = None


@dataclass
class ConversionResult:
    target_schema: str
    routine_name: str
    ddl: str  # CREATE FUNCTION ... statement (best effort)
    flags: list[ConversionFlag] = field(default_factory=list)
    converted: bool = True  # False when we could only inventory, not convert

    @property
    def needs_review(self) -> bool:
        return any(f.severity == "manual" for f in self.flags)


# Patterns that we can rewrite with a simple substitution.
_SCALAR_REWRITES: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"\bGETDATE\s*\(\s*\)", re.IGNORECASE), "now()"),
    (re.compile(r"\bSYSDATETIME\s*\(\s*\)", re.IGNORECASE), "now()"),
    (re.compile(r"\bGETUTCDATE\s*\(\s*\)", re.IGNORECASE), "(now() at time zone 'utc')"),
    (re.compile(r"\bNEWID\s*\(\s*\)", re.IGNORECASE), "gen_random_uuid()"),
    (re.compile(r"\bISNULL\s*\(", re.IGNORECASE), "COALESCE("),
    (re.compile(r"\bLEN\s*\(", re.IGNORECASE), "length("),
    (re.compile(r"\bDATALENGTH\s*\(", re.IGNORECASE), "octet_length("),
    (re.compile(r"\bSCOPE_IDENTITY\s*\(\s*\)", re.IGNORECASE), "lastval()"),
    (re.compile(r"\b@@ROWCOUNT\b", re.IGNORECASE), "row_count"),
    (re.compile(r"\bGETDATE\b", re.IGNORECASE), "now()"),
]

# Constructs we cannot safely auto-convert; each match is flagged for a human.
_MANUAL_PATTERNS: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"\bMERGE\b", re.IGNORECASE), "MERGE statement — rewrite as INSERT ... ON CONFLICT"),
    (re.compile(r"\bEXEC(?:UTE)?\s*\(", re.IGNORECASE), "dynamic SQL (EXEC(...)) — port to EXECUTE with USING"),
    (re.compile(r"\bsp_executesql\b", re.IGNORECASE), "sp_executesql — port to EXECUTE ... USING"),
    (re.compile(r"\bOPEN\s+\w+|\bFETCH\s+NEXT\b", re.IGNORECASE), "cursor — port to a PL/pgSQL FOR loop or cursor"),
    (re.compile(r"#\w+", re.IGNORECASE), "temp table (#tmp) — use a real or TEMP table / CTE"),
    (re.compile(r"\bPIVOT\b|\bUNPIVOT\b", re.IGNORECASE), "PIVOT/UNPIVOT — rewrite with crosstab or CASE aggregation"),
    (re.compile(r"\bTRY\b|\bCATCH\b", re.IGNORECASE), "TRY/CATCH — port to BEGIN ... EXCEPTION WHEN OTHERS"),
    (re.compile(r"\bIDENTITY\s*\(", re.IGNORECASE), "IDENTITY(...) in a query — verify sequence semantics"),
    (re.compile(r"\bTOP\s+\d+", re.IGNORECASE), "TOP n — rewrite as LIMIT n"),
    (re.compile(r"\+\s*N?'", re.IGNORECASE), "string concatenation with '+' — use '||' in Postgres"),
]

_PARAM_RE = re.compile(
    r"@(?P<name>\w+)\s+(?P<type>[\w]+(?:\s*\(\s*[\w,\s]+\)|\s*\(\s*max\s*\))?)"
    r"(?P<default>\s*=\s*[^,\)]+)?",
    re.IGNORECASE,
)

_CREATE_RE = re.compile(
    r"CREATE\s+(?:OR\s+ALTER\s+)?(?:PROC(?:EDURE)?|FUNCTION)\s+"
    r"(?:\[?(?P<schema>\w+)\]?\.)?\[?(?P<name>\w+)\]?"
    r"(?P<params>.*?)\bAS\b",
    re.IGNORECASE | re.DOTALL,
)


def _map_param_type(tsql_type: str) -> str:
    base = re.split(r"[\s(]", tsql_type.strip(), maxsplit=1)[0].lower()
    mapping = {
        "int": "integer",
        "bigint": "bigint",
        "smallint": "smallint",
        "tinyint": "smallint",
        "bit": "boolean",
        "varchar": "text",
        "nvarchar": "text",
        "char": "text",
        "nchar": "text",
        "text": "text",
        "ntext": "text",
        "datetime": "timestamp",
        "datetime2": "timestamp",
        "date": "date",
        "time": "time",
        "decimal": "numeric",
        "numeric": "numeric",
        "money": "numeric(19,4)",
        "float": "double precision",
        "real": "real",
        "uniqueidentifier": "uuid",
        "varbinary": "bytea",
        "xml": "xml",
    }
    return mapping.get(base, "text")


def _parse_params(param_block: str) -> tuple[list[str], list[ConversionFlag]]:
    flags: list[ConversionFlag] = []
    params: list[str] = []
    param_block = param_block.strip()
    param_block = param_block.removeprefix("(")
    param_block = param_block.removesuffix(")")
    for match in _PARAM_RE.finditer(param_block):
        name = sanitize_identifier(match.group("name"))
        pgtype = _map_param_type(match.group("type"))
        if re.search(r"\bOUTPUT\b|\bOUT\b", param_block[match.end():match.end() + 12], re.IGNORECASE):
            params.append(f"INOUT {name} {pgtype}")
            flags.append(
                ConversionFlag(
                    "warning",
                    f"parameter @{match.group('name')} was OUTPUT — mapped to INOUT",
                )
            )
        else:
            default = match.group("default")
            if default:
                params.append(f"{name} {pgtype} DEFAULT {default.split('=', 1)[1].strip()}")
            else:
                params.append(f"{name} {pgtype}")
    return params, flags


def _rewrite_body(body: str) -> tuple[str, list[ConversionFlag]]:
    flags: list[ConversionFlag] = []
    for pattern, replacement in _SCALAR_REWRITES:
        body = pattern.sub(replacement, body)

    # Rewrite @var -> var (PL/pgSQL variables have no @ sigil).
    body = re.sub(r"@@\w+", lambda m: m.group(0), body)  # keep @@GLOBALs for flagging
    body = re.sub(r"@(\w+)", lambda m: sanitize_identifier(m.group(1)), body)

    for pattern, description in _MANUAL_PATTERNS:
        for m in pattern.finditer(body):
            flags.append(ConversionFlag("manual", description, snippet=m.group(0)))

    return body, flags


def convert_routine(routine: Routine, target_schema: str) -> ConversionResult:
    """Convert a single source :class:`Routine` to a PL/pgSQL function DDL."""
    fn_name = sanitize_identifier(routine.name)

    # Postgres sources: the definition is already PL/pgSQL/SQL — re-emit into the
    # target schema without T-SQL rewriting.
    if routine.language != "tsql":
        ddl = _reschema_pg_routine(routine, target_schema, fn_name)
        return ConversionResult(target_schema, fn_name, ddl, converted=True)

    flags: list[ConversionFlag] = []
    match = _CREATE_RE.search(routine.definition)
    if not match:
        return ConversionResult(
            target_schema,
            fn_name,
            _inventory_only(routine, target_schema, fn_name),
            flags=[ConversionFlag("manual", "could not locate CREATE PROC/FUNCTION header")],
            converted=False,
        )

    params, pflags = _parse_params(match.group("params") or "")
    flags.extend(pflags)

    raw_body = routine.definition[match.end():].strip()
    # Strip a trailing GO batch separator if present.
    raw_body = re.sub(r"\bGO\s*$", "", raw_body, flags=re.IGNORECASE).strip()
    body, bflags = _rewrite_body(raw_body)
    flags.extend(bflags)

    review_comments = "\n".join(
        f"    -- REVIEW ({f.severity}): {f.message}"
        + (f"  [{f.snippet}]" if f.snippet else "")
        for f in flags
    )

    signature = ", ".join(params)
    qualified = f"{quote_ident(target_schema)}.{quote_ident(fn_name)}"
    ddl = f"""CREATE OR REPLACE FUNCTION {qualified}({signature})
RETURNS void
LANGUAGE plpgsql
AS $function$
BEGIN
{review_comments + chr(10) if review_comments else ""}    -- ---- converted from T-SQL procedure {routine.schema}.{routine.name} ----
{_indent(body)}
END;
$function$;"""

    return ConversionResult(target_schema, fn_name, ddl, flags=flags, converted=True)


def _indent(text: str, spaces: int = 4) -> str:
    pad = " " * spaces
    return "\n".join(pad + line if line.strip() else line for line in text.splitlines())


def _reschema_pg_routine(routine: Routine, target_schema: str, fn_name: str) -> str:
    """Re-point an existing Postgres routine definition at the target schema."""
    definition = routine.definition
    # Replace the first schema-qualified or bare name after CREATE FUNCTION.
    definition = re.sub(
        r"(CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\s+)(?:[\w\"]+\.)?[\w\"]+",
        rf"\1{quote_ident(target_schema)}.{quote_ident(fn_name)}",
        definition,
        count=1,
        flags=re.IGNORECASE,
    )
    return definition


def _inventory_only(routine: Routine, target_schema: str, fn_name: str) -> str:
    return (
        f"-- Routine {routine.schema}.{routine.name} could not be auto-converted.\n"
        f"-- Original T-SQL preserved below for manual porting into "
        f"{target_schema}.{fn_name}:\n"
        + "\n".join(f"-- {line}" for line in routine.definition.splitlines())
    )
