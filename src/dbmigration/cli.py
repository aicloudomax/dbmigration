"""Command-line interface for dbmigration.

    dbmigrate discover   -- list Azure subscriptions and databases to migrate
    dbmigrate plan       -- dry run: show the target schema/table/routine plan
    dbmigrate migrate    -- perform the migration into Supabase
    dbmigrate convert    -- convert a single T-SQL file to PL/pgSQL (offline)
    dbmigrate export     -- extract one database to per-object files in the repo
    dbmigrate load-dump  -- load an export into Postgres and verify row counts
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

import click
from dotenv import load_dotenv
from rich.console import Console
from rich.markup import escape
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
@click.option("--data-format", type=click.Choice(["insert", "copy"]), default="insert",
              help="Per-table data files: 'insert' (.sql of INSERTs) or 'copy' (.tsv COPY text).")
@click.option("--max-data-file-mb", type=click.FloatRange(min=0, min_open=True), default=45.0,
              show_default=True,
              help="Split a table's data into .partNNNN files so none grows past this size.")
def export(config: str, database: str, server_host: str, kind: str, out: str,
           schema_only: bool, data_format: str, max_data_file_mb: float) -> None:
    """Extract a source database to per-object files (schema + data) in the repo.

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

    console.print(f"Extracting [bold]{escape(database)}[/bold] from {escape(server_host)}...")
    db = extract_source(src_kind, server_host, subscription="(direct)", server=server_host, database=database)

    def data_reader(table):
        conn = connect_source(src_kind, server_host, database)
        try:
            yield from extractor.iter_table_rows(conn, table, plan_obj.migration.batch_size)
        finally:
            conn.close()

    result = export_database(
        plan_obj, db, _Path(out),
        None if schema_only else data_reader,
        data_format=data_format,
        max_data_file_mb=max_data_file_mb,
    )
    _print_export_counts(result)


def _print_export_counts(result) -> None:
    table = RichTable(title=f"Exported {escape(result.database)} to {escape(str(result.out_dir))}")
    table.add_column("Item")
    table.add_column("Count", justify="right")
    rows = [
        ("Target schemas", result.schemas),
        ("Tables", result.tables),
        ("Views", result.views),
        ("Procedures", result.procedures),
        ("Functions", result.functions),
        ("Rows", result.rows),
        ("Data files", len(result.data_files)),
        ("Data size (MB)", f"{result.data_bytes / (1024 * 1024):,.1f}"),
        ("Warnings", len(result.warnings)),
        ("Review items", len(result.review_items)),
    ]
    for label, value in rows:
        table.add_row(label, f"{value:,}" if isinstance(value, int) else value)
    console.print(table)
    for warning in result.warnings:
        console.print(f"[yellow]warning:[/yellow] {escape(warning)}")
    if result.review_items:
        console.print(f"[yellow]{len(result.review_items)} items flagged for review[/yellow] "
                      f"(see manifest.json and the -- REVIEW comments).")


def _resolve_target_url(target_url: str | None, config: str) -> str:
    """--target-url, else SUPABASE_DB_URL, else the config's target connection URL."""
    if target_url:
        return target_url
    if os.environ.get("SUPABASE_DB_URL"):
        return os.environ["SUPABASE_DB_URL"]
    plan_obj = _load(config)
    try:
        return plan_obj.target.connection_url()
    except ConfigError as exc:
        console.print(f"[red]Config error:[/red] {escape(str(exc))}")
        sys.exit(2)


@main.command(name="load-dump")
@click.argument("dump_dir", type=click.Path(exists=True, file_okay=False, path_type=Path))
@click.option("--config", "-c", default="config/migration.yaml",
              help="Used for the target only when neither --target-url nor SUPABASE_DB_URL is set.")
@click.option("--target-url", default=None,
              help="Target Postgres URL (default: SUPABASE_DB_URL, then the config's target).")
@click.option("--stop-on-error", is_flag=True, help="Stop at the first failed file or statement.")
@click.option("--report", "report_path", type=click.Path(dir_okay=False, path_type=Path),
              default=None, help="Where to write the JSON report (default: <dump_dir>/load_report.json).")
def load_dump_command(dump_dir: Path, config: str, target_url: str | None,
                      stop_on_error: bool, report_path: Path | None) -> None:
    """Load an exported dump directory into Postgres/Supabase and verify row counts.

    Follows manifest.json's load_order, one transaction per file (per statement
    for sequences.sql and foreign_keys.sql), records every success or failure,
    then compares each table's row count with the export. Exits 1 on any
    failure or row-count mismatch.
    """
    import json

    from .exporter import load_dump, redact_url

    load_dotenv()
    url = _resolve_target_url(target_url, config)
    console.print(f"Loading [bold]{escape(str(dump_dir))}[/bold] into {escape(redact_url(url))}...")
    report = load_dump(dump_dir, url, stop_on_error=stop_on_error)

    path = report_path or dump_dir / "load_report.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    _print_load_summary(report)
    console.print(f"Report written: {escape(str(path))}")
    if not report["ok"]:
        sys.exit(1)


def _print_load_summary(report: dict) -> None:
    from .exporter import iter_failures

    table = RichTable(title="Load summary")
    for col in ("Kind", "OK", "Failed"):
        table.add_column(col, justify="left" if col == "Kind" else "right")
    for kind, counts in report["by_kind"].items():
        table.add_row(kind, f"{counts['ok']:,}", f"{counts['failed']:,}")
    console.print(table)
    checks = report["row_checks"]
    matched = sum(1 for c in checks if c["match"])
    console.print(
        f"Row counts: {matched:,}/{len(checks):,} tables match; "
        f"{report['totals'].get('rows_loaded', 0):,} rows loaded."
    )
    problems = list(iter_failures(report))
    for line in problems[:50]:
        console.print(f"[red]FAILED[/red] {escape(line)}")
    if len(problems) > 50:
        console.print(f"... and {len(problems) - 50} more (see the report).")
    if report.get("stopped_early"):
        console.print("[red]Stopped at the first failure (--stop-on-error).[/red]")
    verdict = "[green]OK[/green]" if report["ok"] else "[red]FAILED[/red]"
    totals = report["totals"]
    console.print(
        f"Result: {verdict} ({totals['ok']:,} ok, {totals['failed']:,} failed, "
        f"{totals['row_mismatches']:,} row-count mismatches)"
    )


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
