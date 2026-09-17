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


@main.command()
@click.option("--config", "-c", default="config/migration.yaml")
@click.option("--database", "-d", required=True, help="Source database name, e.g. LiveBit.")
@click.option("--server-host", required=True, help="Source server host, e.g. coe-index-db-server.database.windows.net.")
@click.option("--kind", type=click.Choice(["mssql", "postgres"]), default="mssql")
@click.option("--out", default="export", help="Output directory (committed to the repo).")
@click.option("--schema-only", is_flag=True, help="Export schema/views/routines but not data.")
def export(config: str, database: str, server_host: str, kind: str, out: str, schema_only: bool) -> None:
    """Extract a source database to on-disk files (schema + data) in the repo.

    Needs only the source DB credentials (SRC_* env vars) — no Azure discovery.
    Run this where the database is reachable; commit the `export/` tree.
    """
    from pathlib import Path as _Path

    from .exporter import export_database
    from .model import SourceKind
    from .runner import connect_source, extract_source

    plan_obj = _load(config)
    if schema_only:
        plan_obj.migration.data = False

    src_kind = SourceKind.AZURE_SQL if kind == "mssql" else SourceKind.AZURE_POSTGRES
    extractor = __import__(
        f"dbmigration.extract.{'mssql' if kind == 'mssql' else 'postgres'}",
        fromlist=["iter_table_rows"],
    )

    console.print(f"Extracting [bold]{database}[/bold] from {server_host}...")
    db = extract_source(src_kind, server_host, subscription="(direct)", server=server_host, database=database)

    def data_reader(table):
        conn = connect_source(src_kind, server_host, database)
        try:
            yield from extractor.iter_table_rows(conn, table, plan_obj.migration.batch_size)
        finally:
            conn.close()

    result = export_database(plan_obj, db, _Path(out), None if schema_only else data_reader)
    console.print(
        f"[green]Exported[/green] to {result.out_dir}: "
        f"{result.tables} tables, {result.views} views, {result.routines} routines, "
        f"{result.rows:,} rows."
    )
    if result.review_items:
        console.print(f"[yellow]{len(result.review_items)} items flagged for review[/yellow] "
                      f"(see manifest.json).")


@main.command(name="load-dump")
@click.argument("dump_dir", type=click.Path(exists=True, path_type=Path))
@click.option("--config", "-c", default="config/migration.yaml")
def load_dump(dump_dir: Path, config: str) -> None:
    """Load a previously exported dump directory into Supabase (psycopg)."""
    import psycopg

    plan_obj = _load(config)
    order = ["01_schema.sql", "02_views.sql", "03_routines.sql"]
    with psycopg.connect(plan_obj.target.connection_url()) as conn:
        for fname in order:
            path = dump_dir / fname
            if path.exists():
                console.print(f"Applying {fname}...")
                conn.execute(path.read_text())
                conn.commit()
        data_dir = dump_dir / "data"
        if data_dir.exists():
            for tsv in sorted(data_dir.glob("*.tsv")):
                schema, table = tsv.stem.split("__", 1)
                target = f'"{schema}"."{table}"'
                console.print(f"Loading {tsv.name} -> {target}")
                with conn.cursor() as cur, cur.copy(f"COPY {target} FROM STDIN") as copy:
                    copy.write(tsv.read_text())
                conn.commit()
        fk = dump_dir / "04_foreign_keys.sql"
        if fk.exists():
            console.print("Applying 04_foreign_keys.sql...")
            conn.execute(fk.read_text())
            conn.commit()
    console.print("[green]Dump loaded.[/green]")


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
        f"Views: [bold]{record.total_views}[/bold]  "
        f"Rows: [bold]{record.total_rows:,}[/bold]  "
        f"Routines: [bold]{record.total_routines}[/bold]  "
        f"Need review: [bold yellow]{record.routines_needing_review}[/bold yellow]"
    )


if __name__ == "__main__":
    main()
