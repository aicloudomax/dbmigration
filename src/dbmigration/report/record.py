"""In-memory model of a migration run plus JSON + Markdown serialization.

The record is the product deliverable: after any run (including a dry run) it
answers "what was transferred, from where, to which schema, how many rows, and
what needed manual attention" without anyone re-querying the databases.
"""

from __future__ import annotations

import json
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path


@dataclass
class TableOutcome:
    source: str            # schema.table in the source
    target_schema: str
    target_table: str
    columns: int
    approx_source_rows: int | None
    rows_copied: int | None
    status: str            # "migrated", "schema_only", "skipped", "error"
    notes: list[str] = field(default_factory=list)


@dataclass
class RoutineOutcome:
    source: str            # schema.name
    target_schema: str
    target_function: str
    kind: str
    status: str            # "converted", "converted_with_review", "inventoried", "error"
    review_items: list[str] = field(default_factory=list)


@dataclass
class DatabaseOutcome:
    subscription: str
    server: str
    kind: str
    database: str
    target_schema: str
    tables: list[TableOutcome] = field(default_factory=list)
    routines: list[RoutineOutcome] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)


@dataclass
class MigrationRecord:
    target: str
    started_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    finished_at: str | None = None
    dry_run: bool = False
    databases: list[DatabaseOutcome] = field(default_factory=list)

    def add_database(self, outcome: DatabaseOutcome) -> None:
        self.databases.append(outcome)

    def finish(self) -> None:
        self.finished_at = datetime.now(timezone.utc).isoformat()

    # -- aggregates -----------------------------------------------------------

    @property
    def total_tables(self) -> int:
        return sum(len(d.tables) for d in self.databases)

    @property
    def total_rows(self) -> int:
        return sum(t.rows_copied or 0 for d in self.databases for t in d.tables)

    @property
    def total_routines(self) -> int:
        return sum(len(d.routines) for d in self.databases)

    @property
    def routines_needing_review(self) -> int:
        return sum(
            1
            for d in self.databases
            for r in d.routines
            if r.status in {"converted_with_review", "inventoried", "error"}
        )

    # -- serialization --------------------------------------------------------

    def to_dict(self) -> dict:
        return asdict(self)

    def write_json(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(self.to_dict(), indent=2))

    def write_markdown(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(self.render_markdown())

    def render_markdown(self) -> str:
        lines: list[str] = []
        mode = "DRY RUN — no changes applied" if self.dry_run else "Applied"
        lines += [
            "# Database Migration Report",
            "",
            f"- **Target:** `{self.target}`",
            f"- **Mode:** {mode}",
            f"- **Started:** {self.started_at}",
            f"- **Finished:** {self.finished_at or '(in progress)'}",
            "",
            "## Summary",
            "",
            "| Metric | Count |",
            "| --- | ---: |",
            f"| Source databases | {len(self.databases)} |",
            f"| Tables | {self.total_tables} |",
            f"| Rows copied | {self.total_rows:,} |",
            f"| Routines | {self.total_routines} |",
            f"| Routines needing review | {self.routines_needing_review} |",
            "",
        ]

        for db in self.databases:
            lines += [
                f"## {db.database}  →  schema `{db.target_schema}`",
                "",
                f"- Subscription: `{db.subscription}`",
                f"- Server: `{db.server}` ({db.kind})",
                "",
            ]
            if db.errors:
                lines += ["**Errors:**", ""]
                lines += [f"- {e}" for e in db.errors]
                lines += [""]

            if db.tables:
                lines += [
                    "### Tables",
                    "",
                    "| Source | Target table | Cols | Src rows | Rows copied | Status |",
                    "| --- | --- | ---: | ---: | ---: | --- |",
                ]
                for t in db.tables:
                    src_rows = "—" if t.approx_source_rows is None else f"{t.approx_source_rows:,}"
                    copied = "—" if t.rows_copied is None else f"{t.rows_copied:,}"
                    lines.append(
                        f"| `{t.source}` | `{t.target_schema}.{t.target_table}` | "
                        f"{t.columns} | {src_rows} | {copied} | {t.status} |"
                    )
                lines.append("")

            if db.routines:
                lines += [
                    "### Routines (stored procedures / functions)",
                    "",
                    "| Source | Target function | Kind | Status | Review items |",
                    "| --- | --- | --- | --- | --- |",
                ]
                for r in db.routines:
                    review = "; ".join(r.review_items) if r.review_items else "—"
                    lines.append(
                        f"| `{r.source}` | `{r.target_schema}.{r.target_function}` | "
                        f"{r.kind} | {r.status} | {review} |"
                    )
                lines.append("")

        return "\n".join(lines) + "\n"
