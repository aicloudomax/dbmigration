"""Load and validate the migration plan (config/migration.yaml + environment)."""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml

# System databases that must never be migrated, regardless of config.
SYSTEM_DATABASES = {
    "master",
    "tempdb",
    "model",
    "msdb",
    "postgres",
    "azure_maintenance",
    "azure_sys",
}


class ConfigError(Exception):
    """Raised when the migration plan is missing or invalid."""


@dataclass
class TargetConfig:
    supabase_project_ref: str
    database: str = "postgres"
    port: int = 5432
    sslmode: str = "require"

    def connection_url(self) -> str:
        """Build the target Postgres URL, honouring SUPABASE_DB_URL if set."""
        override = os.environ.get("SUPABASE_DB_URL")
        if override:
            return override
        password = os.environ.get("SUPABASE_DB_PASSWORD")
        if not password:
            raise ConfigError(
                "SUPABASE_DB_PASSWORD is not set and SUPABASE_DB_URL was not provided."
            )
        host = f"db.{self.supabase_project_ref}.supabase.co"
        return (
            f"postgresql://postgres:{password}@{host}:{self.port}/"
            f"{self.database}?sslmode={self.sslmode}"
        )

    def safe_summary(self) -> str:
        """Human-readable target description with no secrets."""
        return f"db.{self.supabase_project_ref}.supabase.co/{self.database}"


@dataclass
class NamingConfig:
    schema_template: str = "{db}_{schema}"
    auto_disambiguate: bool = False


@dataclass
class DiscoveryConfig:
    subscriptions: list[str] = field(default_factory=list)
    include_azure_sql: bool = True
    include_azure_postgres: bool = True
    exclude_databases: set[str] = field(default_factory=set)


@dataclass
class MigrationConfig:
    schema: bool = True
    data: bool = True
    routines: bool = True
    batch_size: int = 5000
    load_method: str = "copy"
    on_existing_schema: str = "error"
    fail_fast: bool = False


@dataclass
class RoutinesConfig:
    mode: str = "convert"
    keep_original_as_comment: bool = True


@dataclass
class Plan:
    target: TargetConfig
    naming: NamingConfig
    discovery: DiscoveryConfig
    migration: MigrationConfig
    routines: RoutinesConfig
    servers: list[dict[str, Any]] = field(default_factory=list)
    output_dir: Path = Path("output")

    def excluded_databases(self) -> set[str]:
        return {d.lower() for d in self.discovery.exclude_databases} | SYSTEM_DATABASES


def _require(mapping: dict[str, Any], key: str, ctx: str) -> Any:
    if key not in mapping:
        raise ConfigError(f"Missing required key '{key}' in {ctx}.")
    return mapping[key]


def load_plan(path: str | Path) -> Plan:
    """Parse a migration plan YAML file into a validated :class:`Plan`."""
    path = Path(path)
    if not path.exists():
        raise ConfigError(
            f"Config file not found: {path}. Copy config/migration.example.yaml "
            f"to {path} and edit it."
        )
    raw = yaml.safe_load(path.read_text()) or {}

    target_raw = _require(raw, "target", "config")
    target = TargetConfig(
        supabase_project_ref=_require(target_raw, "supabase_project_ref", "target"),
        database=target_raw.get("database", "postgres"),
        port=int(target_raw.get("port", 5432)),
        sslmode=target_raw.get("sslmode", "require"),
    )

    naming_raw = raw.get("naming", {})
    naming = NamingConfig(
        schema_template=naming_raw.get("schema_template", "{db}_{schema}"),
        auto_disambiguate=bool(naming_raw.get("auto_disambiguate", False)),
    )

    disc_raw = raw.get("discovery", {})
    include = disc_raw.get("include", {})
    discovery = DiscoveryConfig(
        subscriptions=list(disc_raw.get("subscriptions", []) or []),
        include_azure_sql=bool(include.get("azure_sql", True)),
        include_azure_postgres=bool(include.get("azure_postgres", True)),
        exclude_databases=set(disc_raw.get("exclude_databases", []) or []),
    )

    mig_raw = raw.get("migration", {})
    migration = MigrationConfig(
        schema=bool(mig_raw.get("schema", True)),
        data=bool(mig_raw.get("data", True)),
        routines=bool(mig_raw.get("routines", True)),
        batch_size=int(mig_raw.get("batch_size", 5000)),
        load_method=mig_raw.get("load_method", "copy"),
        on_existing_schema=mig_raw.get("on_existing_schema", "error"),
        fail_fast=bool(mig_raw.get("fail_fast", False)),
    )
    if migration.load_method not in {"copy", "insert"}:
        raise ConfigError("migration.load_method must be 'copy' or 'insert'.")
    if migration.on_existing_schema not in {"skip", "drop", "error"}:
        raise ConfigError("migration.on_existing_schema must be 'skip', 'drop', or 'error'.")

    routines_raw = raw.get("routines", {})
    routines = RoutinesConfig(
        mode=routines_raw.get("mode", "convert"),
        keep_original_as_comment=bool(routines_raw.get("keep_original_as_comment", True)),
    )
    if routines.mode not in {"convert", "report"}:
        raise ConfigError("routines.mode must be 'convert' or 'report'.")

    output_dir = Path(raw.get("output", {}).get("dir", "output"))

    return Plan(
        target=target,
        naming=naming,
        discovery=discovery,
        migration=migration,
        routines=routines,
        servers=list(raw.get("servers", []) or []),
        output_dir=output_dir,
    )
