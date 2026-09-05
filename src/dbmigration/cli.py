"""Command-line interface for dbmigration.

    dbmigrate discover   -- list Azure subscriptions and databases to migrate
    dbmigrate plan       -- dry run: show the target schema/table/routine plan
    dbmigrate migrate    -- perform the migration into Supabase
    dbmigrate convert    -- convert a single T-SQL file to PL/pgSQL (offline)
"""

from __future__ import annotations

import sys
from pathlib import Path

import click
from dotenv import load_dotenv
from rich.console import Console
from rich.table import Table as RichTable

from .config import ConfigError, load_plan
from .logging_utils import get_logger
from .model import Routine

console = Console()
log = get_logger()


def _load(config: str):
    load_dotenv()
    try:
        return load_plan(config)
    except ConfigError as exc:
        console.print(f"[red]Config error:[/red] {exc}")
        sys.exit(2)


def _discover_sources(plan):
    """Enumerate sources from Azure, honouring discovery config."""
    from .azure import discovery
    from .pipeline import SourceTarget

    excluded = plan.excluded_databases()
    sources: list[SourceTarget] = []
    subs = discovery.list_subscriptions(plan.discovery.subscriptions or None)
    for sub_id, sub_name in subs:
        found = []
        if plan.discovery.include_azure_sql:
            found += discovery.discover_sql_databases(sub_id, sub_name)
        if plan.discovery.include_azure_postgres:
            found += discovery.discover_postgres_databases(sub_id, sub_name)
        for d in found:
            if d.database.lower() in excluded:
                continue
            sources.append(
                SourceTarget(
                    subscription=d.subscription_name,
                    server=d.server_name,
                    server_host=d.server_host,
                    kind=d.kind,
                    database=d.database,
                )
            )
    return sources


@click.group()
@click.version_option()
def main() -> None:
    """Migrate Azure MS SQL + PostgreSQL databases into Supabase."""


@main.command()
@click.option("--config", "-c", default="config/migration.yaml", help="Path to migration plan.")
def discover(config: str) -> None:
    """List all Azure databases that would be migrated."""
    plan = _load(config)
    sources = _discover_sources(plan)
    table = RichTable(title="Discovered source databases")
    for col in ("Subscription", "Server", "Kind", "Database"):
        table.add_column(col)
    for s in sources:
        table.add_row(s.subscription, s.server, s.kind.value, s.database)
    console.print(table)
    console.print(f"\n[bold]{len(sources)}[/bold] databases in scope.")


@main.command()
@click.option("--config", "-c", default="config/migration.yaml")
def plan(config: str) -> None:
    """Dry run: extract sources and print the target mapping + write a report."""
    plan_obj = _load(config)
    from .runner import run_migration

    sources = _discover_sources(plan_obj)
    console.print(f"Planning migration of [bold]{len(sources)}[/bold] databases (dry run)...")
    record = run_migration(plan_obj, sources, dry_run=True)
    _write_reports(plan_obj, record, prefix="plan")
    _print_summary(record)


@main.command()
@click.option("--config", "-c", default="config/migration.yaml")
@click.option("--yes", is_flag=True, help="Skip the confirmation prompt.")
def migrate(config: str, yes: bool) -> None:
    """Perform the migration into Supabase."""
    plan_obj = _load(config)
    from .runner import run_migration

    sources = _discover_sources(plan_obj)
    console.print(
        f"About to migrate [bold]{len(sources)}[/bold] databases into "
        f"[bold]{plan_obj.target.safe_summary()}[/bold]."
    )
    if not yes and not click.confirm("Proceed?", default=False):
        console.print("Aborted.")
        return
    record = run_migration(plan_obj, sources, dry_run=False)
    _write_reports(plan_obj, record, prefix="migrate")
    _print_summary(record)


@main.command()
@click.argument("tsql_file", type=click.Path(exists=True, path_type=Path))
@click.option("--schema", "-s", default="converted", help="Target schema name.")
def convert(tsql_file: Path, schema: str) -> None:
    """Convert one T-SQL procedure file to PL/pgSQL and print the result (offline)."""
    from .transform.tsql_to_plpgsql import convert_routine

    definition = tsql_file.read_text()
    routine = Routine(
        schema="dbo", name=tsql_file.stem, kind="procedure",
        language="tsql", definition=definition,
    )
    result = convert_routine(routine, schema)
    console.rule(f"Converted: {result.target_schema}.{result.routine_name}")
    console.print(result.ddl)
    if result.flags:
        console.rule("Review items")
        for f in result.flags:
            colour = "yellow" if f.severity == "warning" else "red"
            console.print(f"[{colour}]{f.severity}[/{colour}]: {f.message}")


def _write_reports(plan_obj, record, *, prefix: str) -> None:
    ts = record.started_at.replace(":", "").replace("-", "")[:15]
    base = plan_obj.output_dir / f"{prefix}_{ts}"
    record.write_json(base.with_suffix(".json"))
    record.write_markdown(base.with_suffix(".md"))
    console.print(f"[green]Report written:[/green] {base}.md / {base}.json")


def _print_summary(record) -> None:
    console.print(
        f"\nDatabases: [bold]{len(record.databases)}[/bold]  "
        f"Tables: [bold]{record.total_tables}[/bold]  "
        f"Rows: [bold]{record.total_rows:,}[/bold]  "
        f"Routines: [bold]{record.total_routines}[/bold]  "
        f"Need review: [bold yellow]{record.routines_needing_review}[/bold yellow]"
    )


if __name__ == "__main__":
    main()
