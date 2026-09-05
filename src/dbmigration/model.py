"""Provider-neutral intermediate representation of database objects.

Extractors (MS SQL, Postgres) populate these dataclasses; the loader and the
report consume them. Keeping a single IR means transformation logic lives in one
place instead of being duplicated per source.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum


class SourceKind(str, Enum):
    AZURE_SQL = "azure_sql"
    AZURE_POSTGRES = "azure_postgres"


@dataclass
class Column:
    name: str
    # Source type as reported by the source catalog (e.g. "varchar", "int",
    # "datetime2"). Mapped to a Postgres type by transform.types.
    source_type: str
    nullable: bool = True
    default: str | None = None
    # Length/precision/scale where the source exposes them.
    char_length: int | None = None
    numeric_precision: int | None = None
    numeric_scale: int | None = None
    is_identity: bool = False
    ordinal: int = 0


@dataclass
class Index:
    name: str
    columns: list[str]
    unique: bool = False
    is_primary: bool = False


@dataclass
class ForeignKey:
    name: str
    columns: list[str]
    ref_schema: str
    ref_table: str
    ref_columns: list[str]
    on_delete: str | None = None
    on_update: str | None = None


@dataclass
class Table:
    schema: str  # source schema (e.g. "dbo", "public")
    name: str
    columns: list[Column] = field(default_factory=list)
    primary_key: Index | None = None
    indexes: list[Index] = field(default_factory=list)
    foreign_keys: list[ForeignKey] = field(default_factory=list)
    approx_row_count: int | None = None

    @property
    def qualified(self) -> str:
        return f"{self.schema}.{self.name}"


@dataclass
class Routine:
    """A stored procedure or function from the source."""

    schema: str
    name: str
    kind: str  # "procedure" or "function"
    language: str  # "tsql" or "plpgsql"/"sql"
    definition: str  # original source body


@dataclass
class Database:
    """One source database and everything to migrate from it."""

    subscription: str
    server: str
    kind: SourceKind
    name: str
    tables: list[Table] = field(default_factory=list)
    routines: list[Routine] = field(default_factory=list)

    @property
    def source_id(self) -> str:
        return f"{self.subscription}/{self.server}/{self.name}"
