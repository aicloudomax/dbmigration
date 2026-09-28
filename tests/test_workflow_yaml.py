"""Tests for .github/workflows/export-livebit.yml.

Two layers:

* static checks on the parsed YAML (triggers, permissions, secrets hygiene,
  action pins, step wiring);
* behavioural checks that execute the workflow's own ``run:`` scripts with
  ``bash -eo pipefail`` (exactly how Actions runs them), using stub ``git`` /
  ``az`` / ``curl`` / ``pymssql`` so no network, Azure or real git is touched.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import socket
import subprocess
import sys
import tempfile
from pathlib import Path

import pytest
import yaml

REPO = Path(__file__).resolve().parents[1]
WORKFLOW = REPO / ".github" / "workflows" / "export-livebit.yml"
ALLOWED_SECRETS = {
    "SRC_MSSQL_USER",
    "SRC_MSSQL_PASSWORD",
    "AZURE_CLIENT_ID",
    "AZURE_CLIENT_SECRET",
    "AZURE_TENANT_ID",
    "AZURE_SUBSCRIPTION_ID",
}
ALLOWED_ACTIONS = {
    "actions/checkout@v4",
    "actions/setup-python@v5",
    "actions/upload-artifact@v4",
    "azure/login@v2",
}

requires_bash_jq = pytest.mark.skipif(
    shutil.which("bash") is None or shutil.which("jq") is None,
    reason="bash and jq are needed to execute the workflow scripts",
)


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------


@pytest.fixture(scope="module")
def text() -> str:
    return WORKFLOW.read_text(encoding="utf-8")


@pytest.fixture(scope="module")
def wf(text: str) -> dict:
    return yaml.safe_load(text)


def _on(wf: dict) -> dict:
    # PyYAML (YAML 1.1) parses the bare key `on` as boolean True.
    return wf.get("on", wf.get(True))


def _job(wf: dict) -> dict:
    return wf["jobs"]["export"]


def _steps(wf: dict) -> list[dict]:
    return _job(wf)["steps"]


def _step(wf: dict, key: str) -> dict:
    """Find a step by id, or by a substring of its name."""
    for step in _steps(wf):
        if step.get("id") == key:
            return step
    for step in _steps(wf):
        if key.lower() in step.get("name", "").lower():
            return step
    raise AssertionError(f"no step {key!r}")


def _index(wf: dict, key: str) -> int:
    return _steps(wf).index(_step(wf, key))


def _write_exe(path: Path, body: str) -> None:
    path.write_text(body, encoding="utf-8")
    path.chmod(0o755)


def _parse_outputs(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            out[key] = value
    return out


def _run_step(
    wf: dict,
    key: str,
    tmp_path: Path,
    env: dict[str, str] | None = None,
    *,
    cwd: Path | None = None,
    fake_bin: Path | None = None,
) -> tuple[subprocess.CompletedProcess, dict[str, str], str]:
    """Run one step's ``run:`` script like Actions does (bash -eo pipefail).

    Returns (process, parsed $GITHUB_OUTPUT, $GITHUB_STEP_SUMMARY text).
    """
    script = tmp_path / f"step-{re.sub(r'[^a-z0-9]+', '-', key.lower())}.sh"
    script.write_text(_step(wf, key)["run"], encoding="utf-8")
    gh_output = tmp_path / "github_output"
    gh_summary = tmp_path / "github_step_summary"
    gh_output.write_text("", encoding="utf-8")
    gh_summary.write_text("", encoding="utf-8")
    path = os.environ.get("PATH", "/usr/bin:/bin")
    full_env = {
        "PATH": f"{fake_bin}{os.pathsep}{path}" if fake_bin else path,
        "HOME": str(tmp_path),
        "LANG": "C.UTF-8",
        "GITHUB_OUTPUT": str(gh_output),
        "GITHUB_STEP_SUMMARY": str(gh_summary),
        "GITHUB_SERVER_URL": "https://github.com",
        "GITHUB_REPOSITORY": "example-org/example-repo",
        "GITHUB_RUN_ID": "4242",
        "GITHUB_RUN_ATTEMPT": "1",
        "GITHUB_REF_NAME": "main",
        "GITHUB_REF_TYPE": "branch",
        "GITHUB_EVENT_NAME": "workflow_dispatch",
        "RUNNER_TEMP": str(tmp_path),
    }
    full_env.update(env or {})
    proc = subprocess.run(
        ["bash", "--noprofile", "--norc", "-eo", "pipefail", str(script)],
        cwd=cwd or tmp_path,
        env=full_env,
        capture_output=True,
        text=True,
        timeout=120,
        check=False,
    )
    return proc, _parse_outputs(gh_output), gh_summary.read_text(encoding="utf-8")


# ---------------------------------------------------------------------------
# static structure
# ---------------------------------------------------------------------------


def test_workflow_parses_and_is_named(wf: dict) -> None:
    assert wf["name"] == "Export LiveBit (MS SQL -> Postgres SQL files)"
    assert set(wf["jobs"]) == {"export"}


def test_workflow_dispatch_inputs_and_defaults(wf: dict) -> None:
    inputs = _on(wf)["workflow_dispatch"]["inputs"]
    assert inputs["database"]["default"] == "LiveBit"
    assert inputs["server_host"]["default"] == "coe-index-db-server.database.windows.net"
    assert inputs["schema_only"]["type"] == "boolean"
    assert inputs["schema_only"]["default"] is False
    assert inputs["commit_results"]["type"] == "boolean"
    assert inputs["commit_results"]["default"] is True
    assert inputs["max_commit_mb"]["type"] == "string"
    assert inputs["max_commit_mb"]["default"] == "1800"


def test_push_trigger_paths(wf: dict) -> None:
    assert _on(wf)["push"]["paths"] == ["migration-requests/*.json"]


def test_permissions_and_concurrency(wf: dict) -> None:
    assert wf["permissions"] == {"contents": "write"}
    conc = wf["concurrency"]
    assert "github.ref" in conc["group"]
    assert conc["cancel-in-progress"] is False


def test_job_runner_timeout_and_postgres_service(wf: dict) -> None:
    job = _job(wf)
    assert job["runs-on"] == "ubuntu-latest"
    assert job["timeout-minutes"] == 360
    pg = job["services"]["postgres"]
    assert pg["image"] == "postgres:16"
    assert pg["env"]["POSTGRES_PASSWORD"] == "postgres"
    assert pg["ports"] == ["5432:5432"]
    assert "--health-cmd pg_isready" in pg["options"]
    assert job["env"]["VALIDATION_DB_URL"] == (
        "postgresql://postgres:postgres@localhost:5432/postgres"
    )
    assert job["defaults"]["run"]["shell"] == "bash"  # -> bash -eo pipefail


def test_secrets_are_allowed_names_mapped_once_at_job_level(text: str, wf: dict) -> None:
    refs = re.findall(r"secrets\.([A-Za-z0-9_]+)", text)
    assert set(refs) <= ALLOWED_SECRETS, set(refs) - ALLOWED_SECRETS
    assert sorted(refs) == sorted(ALLOWED_SECRETS), "each secret must be mapped exactly once"
    job_env = _job(wf)["env"]
    for name in ALLOWED_SECRETS:
        assert job_env[name] == f"${{{{ secrets.{name} }}}}"
    for step in _steps(wf):
        assert not re.search(r"secrets\.[A-Za-z_]", json.dumps(step)), step.get("name")


def test_actions_pinned_to_major_versions(wf: dict) -> None:
    used = {s["uses"] for s in _steps(wf) if "uses" in s}
    assert used == ALLOWED_ACTIONS


def test_no_shell_tracing(text: str, wf: dict) -> None:
    assert not re.search(r"set\s+-[a-wyz]*x|set\s+-o\s+xtrace|bash\s+-x", text)
    for step in _steps(wf):
        assert "set -x" not in step.get("run", "")


def test_no_hardcoded_credentials(text: str, wf: dict) -> None:
    guid = r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"
    assert not re.search(guid, text), "GUID-looking value (tenant/client/subscription id?)"
    assert not re.search(r"[A-Za-z0-9_~.-]{3}\dQ~[A-Za-z0-9_~.-]{20,}", text), "Azure client secret"
    # Every URL with inline credentials must be the throwaway validation DB.
    for user, password, host in re.findall(r"://([^:/@\s]+):([^@\s]+)@([^:/\s]+)", text):
        assert (user, password, host) == ("postgres", "postgres", "localhost")
    # Every secret-ish env var is either a secrets mapping or the service password.
    sensitive = re.compile(r"PASSWORD|SECRET|TOKEN|_KEY$|CLIENT_ID|TENANT", re.IGNORECASE)
    env_maps = [_job(wf)["env"], _job(wf)["services"]["postgres"]["env"]]
    env_maps += [s.get("env", {}) for s in _steps(wf)]
    for env in env_maps:
        for key, value in env.items():
            if not sensitive.search(key):
                continue
            ok_secret = re.fullmatch(r"\$\{\{ secrets\.[A-Z_]+ \}\}", str(value))
            assert ok_secret or (key, value) == ("POSTGRES_PASSWORD", "postgres"), key


def test_run_scripts_never_interpolate_expressions(wf: dict) -> None:
    # Values reach scripts only through env: prevents script injection from
    # workflow inputs / request files and keeps the scripts testable.
    for step in _steps(wf):
        assert "${{" not in step.get("run", ""), step.get("name")


def test_step_references_exist(text: str, wf: dict) -> None:
    by_id = {s["id"]: s for s in _steps(wf) if "id" in s}
    for sid, kind, name in re.findall(r"steps\.([a-z_]+)\.(outputs|outcome|conclusion)\.?(\w*)", text):
        assert sid in by_id, f"unknown step id {sid}"
        if kind == "outputs" and "run" in by_id[sid]:
            assert re.search(rf"\b{name}=", by_id[sid]["run"]), f"{sid} never sets {name}"


def test_step_order(wf: dict) -> None:
    order = [
        "Check required secrets",
        "actions/checkout",
        "Set up Python",
        "Install dbmigration",
        "cfg",
        "ip",
        "fw",
        "connect",
        "Prepare config",
        "export",
        "validate",
        "size",
        "Write job summary",
        "Upload export artifact",
        "commit",
        "Fail the run if validation failed",
    ]
    positions = []
    for key in order:
        if "/" in key:
            positions.append(next(i for i, s in enumerate(_steps(wf)) if key in s.get("uses", "")))
        else:
            positions.append(_index(wf, key))
    assert positions == sorted(positions)
    # The firewall rule is removed as soon as the export no longer needs it.
    assert _index(wf, "export") < _index(wf, "Remove temporary SQL firewall rule") < _index(
        wf, "validate"
    )


def test_setup_python_uses_pip_cache(wf: dict) -> None:
    step = next(s for s in _steps(wf) if s.get("uses", "").startswith("actions/setup-python"))
    assert step["with"]["python-version"] == "3.11"
    assert step["with"]["cache"] == "pip"
    assert step["with"]["cache-dependency-path"] == "pyproject.toml"
    assert "pip install -e ." in _step(wf, "Install dbmigration")["run"]


def test_firewall_steps_are_optional_and_cleanup_always_runs(wf: dict) -> None:
    login = _step(wf, "azlogin")
    assert login["uses"] == "azure/login@v2"
    assert login["if"] == "env.AZURE_CLIENT_ID != ''"
    assert login["continue-on-error"] is True
    assert "clientSecret" in login["with"]["creds"]

    fw = _step(wf, "fw")
    assert fw["if"] == "env.AZURE_CLIENT_ID != ''"
    assert fw["continue-on-error"] is True
    assert "az sql server list" in fw["run"]
    assert "[?name=='${SQL_SERVER_NAME}'].resourceGroup | [0]" in fw["run"]
    assert 'rule="gh-runner-${GITHUB_RUN_ID}"' in fw["run"]
    assert "::warning::" in fw["run"]

    cleanup = _step(wf, "Remove temporary SQL firewall rule")
    assert "always()" in cleanup["if"]
    assert "steps.fw.outputs.rule_created == 'true'" in cleanup["if"]
    assert "az sql server firewall-rule delete" in cleanup["run"]


def test_export_and_load_dump_commands(wf: dict) -> None:
    export = _step(wf, "export")["run"]
    for token in (
        "export --database",
        "--server-host",
        "--kind mssql",
        "--out export",
        "--data-format insert",
        '--max-data-file-mb "$MAX_DATA_FILE_MB"',
        "-c config/migration.yaml",
        "--schema-only",
        'dbmigrate "${args[@]}"',
        'rm -rf -- "$DB_DIR"',
    ):
        assert token in export, token
    assert _job(wf)["env"]["MAX_DATA_FILE_MB"] == "45"
    assert "cp config/migration.example.yaml config/migration.yaml" in _step(
        wf, "Prepare config"
    )["run"]

    validate = _step(wf, "validate")
    assert validate["continue-on-error"] is True
    assert 'dbmigrate load-dump "$DB_DIR" --target-url "$VALIDATION_DB_URL"' in validate["run"]
    assert '--report "$report"' in validate["run"]
    assert 'report="$DB_DIR/validation_report.json"' in validate["run"]

    final = _step(wf, "Fail the run if validation failed")
    assert final["if"] == "always() && steps.validate.outcome == 'failure'"
    assert "exit 1" in final["run"]


def test_artifact_upload(wf: dict) -> None:
    step = _step(wf, "Upload export artifact")
    assert step["uses"] == "actions/upload-artifact@v4"
    assert "always()" in step["if"] and "steps.size.outputs.exists == 'true'" in step["if"]
    assert step["with"]["retention-days"] == 14
    assert step["with"]["path"] == "${{ steps.cfg.outputs.db_dir }}"


def test_commit_step_configuration(wf: dict) -> None:
    step = _step(wf, "commit")
    assert step["if"] == "steps.cfg.outputs.commit_results == 'true'"
    run = step["run"]
    assert 'git config user.name "github-actions[bot]"' in run
    assert "git pull --rebase" in run
    assert "DATA_NOT_COMMITTED.md" in run
    assert 'subject="Export ${DB_NAME}: schema, data, views, routines (run ${GITHUB_RUN_ID})"' in run
    assert step["env"]["PUSH_ATTEMPTS"] == "4"  # first try + 3 retries


# ---------------------------------------------------------------------------
# behaviour: required secrets
# ---------------------------------------------------------------------------


@requires_bash_jq
def test_missing_secrets_fail_fast_with_instructions(wf: dict, tmp_path: Path) -> None:
    proc, _, _ = _run_step(wf, "Check required secrets", tmp_path, {"SRC_MSSQL_USER": "u"})
    assert proc.returncode == 1
    assert "::error title=Missing repository secrets::" in proc.stdout
    assert "SRC_MSSQL_PASSWORD" in proc.stdout
    assert "Settings -> Secrets and variables -> Actions" in proc.stdout


@requires_bash_jq
def test_present_secrets_pass_without_echoing_them(wf: dict, tmp_path: Path) -> None:
    env = {"SRC_MSSQL_USER": "reader-login-x", "SRC_MSSQL_PASSWORD": "pw-value-x"}
    proc, _, _ = _run_step(wf, "Check required secrets", tmp_path, env)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert "reader-login-x" not in proc.stdout + proc.stderr
    assert "pw-value-x" not in proc.stdout + proc.stderr


# ---------------------------------------------------------------------------
# behaviour: parameter resolution
# ---------------------------------------------------------------------------


def _cfg_env(**overrides: str) -> dict[str, str]:
    env = {
        "PYTHONPATH": str(REPO / "src"),
        "DEFAULT_DATABASE": "LiveBit",
        "DEFAULT_SERVER_HOST": "coe-index-db-server.database.windows.net",
        "DEFAULT_SCHEMA_ONLY": "false",
        "DEFAULT_COMMIT_RESULTS": "true",
        "DEFAULT_MAX_COMMIT_MB": "1800",
    }
    env.update(overrides)
    return env


@requires_bash_jq
def test_resolve_dispatch_inputs(wf: dict, tmp_path: Path) -> None:
    env = _cfg_env(
        IN_DATABASE="LiveBit",
        IN_SERVER_HOST="coe-index-db-server.database.windows.net",
        IN_SCHEMA_ONLY="true",
        IN_COMMIT_RESULTS="false",
        IN_MAX_COMMIT_MB="500",
    )
    proc, out, _ = _run_step(wf, "cfg", tmp_path, env)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert out["database"] == "LiveBit"
    assert out["db_sanitized"] == "livebit"
    assert out["db_dir"] == "export/livebit"
    assert out["server_name"] == "coe-index-db-server"
    assert out["schema_only"] == "true"
    assert out["commit_results"] == "false"
    assert out["max_commit_mb"] == "500"
    assert out["trigger"] == "workflow_dispatch"


@requires_bash_jq
def test_resolve_dispatch_defaults_when_inputs_empty(wf: dict, tmp_path: Path) -> None:
    proc, out, _ = _run_step(wf, "cfg", tmp_path, _cfg_env())
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert out["database"] == "LiveBit"
    assert out["server_host"] == "coe-index-db-server.database.windows.net"
    assert (out["schema_only"], out["commit_results"], out["max_commit_mb"]) == (
        "false",
        "true",
        "1800",
    )


@requires_bash_jq
def test_resolve_push_uses_newest_request_and_keeps_false(wf: dict, tmp_path: Path) -> None:
    requests = tmp_path / "migration-requests"
    requests.mkdir()
    (requests / "2026-01-01-old.json").write_text('{"database": "OldDb"}', encoding="utf-8")
    # commit_results=false must survive (jq's `//` would turn it into the default).
    (requests / "2026-09-28-livebit.json").write_text(
        json.dumps({"database": "LiveBit", "schema_only": True, "commit_results": False}),
        encoding="utf-8",
    )
    event = {
        "commits": [
            {"added": ["migration-requests/2026-01-01-old.json"], "modified": []},
            {"added": ["README.md"], "modified": ["migration-requests/2026-09-28-livebit.json"]},
            {"added": ["docs/x.md"], "modified": []},
        ]
    }
    event_path = tmp_path / "event.json"
    event_path.write_text(json.dumps(event), encoding="utf-8")
    env = _cfg_env(GITHUB_EVENT_NAME="push", GITHUB_EVENT_PATH=str(event_path))
    proc, out, _ = _run_step(wf, "cfg", tmp_path, env)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert out["request_file"] == "migration-requests/2026-09-28-livebit.json"
    assert out["database"] == "LiveBit"
    assert out["schema_only"] == "true"
    assert out["commit_results"] == "false"
    assert out["server_host"] == "coe-index-db-server.database.windows.net"  # defaulted
    assert out["max_commit_mb"] == "1800"  # defaulted
    assert out["trigger"] == "push"


@requires_bash_jq
def test_resolve_push_falls_back_to_last_request_file(wf: dict, tmp_path: Path) -> None:
    requests = tmp_path / "migration-requests"
    requests.mkdir()
    (requests / "a.json").write_text('{"database": "Alpha"}', encoding="utf-8")
    (requests / "b.json").write_text('{"database": "Beta", "max_commit_mb": 900}', "utf-8")
    event_path = tmp_path / "event.json"
    event_path.write_text("{}", encoding="utf-8")
    env = _cfg_env(GITHUB_EVENT_NAME="push", GITHUB_EVENT_PATH=str(event_path))
    proc, out, _ = _run_step(wf, "cfg", tmp_path, env)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert out["request_file"] == "migration-requests/b.json"
    assert (out["database"], out["db_dir"], out["max_commit_mb"]) == ("Beta", "export/beta", "900")


@requires_bash_jq
@pytest.mark.parametrize(
    ("overrides", "fragment"),
    [
        ({"IN_SERVER_HOST": "x$(touch pwned).example.net"}, "server_host"),
        ({"IN_DATABASE": "Live;Bit`touch pwned`"}, "database"),
        ({"IN_MAX_COMMIT_MB": "12abc"}, "max_commit_mb"),
        ({"IN_SCHEMA_ONLY": "maybe"}, "schema_only"),
    ],
)
def test_resolve_rejects_bad_values_without_executing_them(
    wf: dict, tmp_path: Path, overrides: dict[str, str], fragment: str
) -> None:
    proc, _, _ = _run_step(wf, "cfg", tmp_path, _cfg_env(**overrides))
    assert proc.returncode == 1
    assert "::error title=Invalid run parameters::" in proc.stdout
    assert fragment in proc.stdout
    assert not (tmp_path / "pwned").exists()


@requires_bash_jq
def test_resolve_rejects_non_object_request(wf: dict, tmp_path: Path) -> None:
    requests = tmp_path / "migration-requests"
    requests.mkdir()
    (requests / "bad.json").write_text("[1, 2]", encoding="utf-8")
    event_path = tmp_path / "event.json"
    event_path.write_text(json.dumps({"commits": [{"added": ["migration-requests/bad.json"]}]}))
    env = _cfg_env(GITHUB_EVENT_NAME="push", GITHUB_EVENT_PATH=str(event_path))
    proc, _, _ = _run_step(wf, "cfg", tmp_path, env)
    assert proc.returncode == 1
    assert "is not a JSON object" in proc.stdout


# ---------------------------------------------------------------------------
# behaviour: runner IP + firewall rule
# ---------------------------------------------------------------------------


@requires_bash_jq
@pytest.mark.parametrize(("reply", "expected"), [("203.0.113.7\n", "203.0.113.7"), ("<html>", "unknown")])
def test_detect_runner_ip(wf: dict, tmp_path: Path, reply: str, expected: str) -> None:
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    _write_exe(fake_bin / "curl", f"#!/usr/bin/env bash\nprintf '%s' '{reply}'\n")
    proc, out, _ = _run_step(wf, "ip", tmp_path, fake_bin=fake_bin)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert out["ip"] == expected


FAKE_AZ = """#!/usr/bin/env bash
echo "$*" >> "$FAKE_AZ_LOG"
if [ "$1 $2" = "account list" ]; then
  for s in ${FAKE_AZ_SUBS:-}; do echo "$s"; done
  exit 0
fi
if [ "$1 $2 $3" = "sql server list" ]; then
  sub=""
  while [ $# -gt 0 ]; do [ "$1" = "--subscription" ] && sub="$2"; shift; done
  if [ "$sub" = "${FAKE_AZ_SERVER_SUB:-}" ]; then echo "${FAKE_AZ_RG:-}"; fi
  exit 0
fi
if [ "$1 $2 $3 $4" = "sql server firewall-rule create" ]; then exit "${FAKE_AZ_CREATE_RC:-0}"; fi
exit 0
"""


def _fw_env(tmp_path: Path, **overrides: str) -> dict[str, str]:
    env = {
        "FAKE_AZ_LOG": str(tmp_path / "az.log"),
        "AZLOGIN_OUTCOME": "success",
        "RUNNER_IP": "203.0.113.7",
        "SQL_SERVER_NAME": "coe-index-db-server",
        "AZURE_SUBSCRIPTION_ID": "",
        "FAKE_AZ_SUBS": "sub-a sub-b",
        "FAKE_AZ_SERVER_SUB": "sub-b",
        "FAKE_AZ_RG": "rg-data",
    }
    env.update(overrides)
    return env


def _fake_az(tmp_path: Path) -> Path:
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir(exist_ok=True)
    _write_exe(fake_bin / "az", FAKE_AZ)
    return fake_bin


@requires_bash_jq
def test_firewall_rule_created_for_runner_ip(wf: dict, tmp_path: Path) -> None:
    proc, out, _ = _run_step(wf, "fw", tmp_path, _fw_env(tmp_path), fake_bin=_fake_az(tmp_path))
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert out == {
        "rule_created": "true",
        "rg": "rg-data",
        "subscription": "sub-b",
        "rule_name": "gh-runner-4242",
    }
    log = (tmp_path / "az.log").read_text()
    assert "--query [?name=='coe-index-db-server'].resourceGroup | [0]" in log
    create = next(line for line in log.splitlines() if "firewall-rule create" in line)
    assert "--subscription sub-b --resource-group rg-data --server coe-index-db-server" in create
    assert "--name gh-runner-4242" in create
    assert "--start-ip-address 203.0.113.7 --end-ip-address 203.0.113.7" in create


@requires_bash_jq
def test_firewall_prefers_configured_subscription(wf: dict, tmp_path: Path) -> None:
    env = _fw_env(tmp_path, AZURE_SUBSCRIPTION_ID="sub-z", FAKE_AZ_SERVER_SUB="sub-z")
    proc, out, _ = _run_step(wf, "fw", tmp_path, env, fake_bin=_fake_az(tmp_path))
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert (out["rule_created"], out["subscription"]) == ("true", "sub-z")


@requires_bash_jq
@pytest.mark.parametrize(
    ("overrides", "warning"),
    [
        ({"FAKE_AZ_CREATE_RC": "1"}, "SQL Server Contributor"),
        ({"FAKE_AZ_SERVER_SUB": "elsewhere"}, "was not found"),
        ({"AZLOGIN_OUTCOME": "failure"}, "Azure login failed"),
        ({"RUNNER_IP": "unknown"}, "Runner IP unknown"),
    ],
)
def test_firewall_problems_warn_and_continue(
    wf: dict, tmp_path: Path, overrides: dict[str, str], warning: str
) -> None:
    env = _fw_env(tmp_path, **overrides)
    proc, out, _ = _run_step(wf, "fw", tmp_path, env, fake_bin=_fake_az(tmp_path))
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert out["rule_created"] == "false"
    assert "::warning::" in proc.stdout and warning in proc.stdout


# ---------------------------------------------------------------------------
# behaviour: connectivity check
# ---------------------------------------------------------------------------

FAKE_PYMSSQL = '''
import os


class _Cursor:
    def execute(self, sql):
        assert sql == "SELECT @@VERSION, DB_NAME()"

    def fetchone(self):
        return ("Microsoft SQL Azure (RTM) - 12.0.2000.8\\n\\tCopyright", "LiveBit")


class _Conn:
    def cursor(self):
        return _Cursor()

    def close(self):
        pass


def connect(**kwargs):
    with open(os.environ["FAKE_PYMSSQL_LOG"], "a") as fh:
        fh.write(repr(sorted(k for k in kwargs)) + "\\n")
    error = os.environ.get("FAKE_PYMSSQL_ERROR")
    if error:
        raise Exception(error)
    assert kwargs["password"] == os.environ["SRC_MSSQL_PASSWORD"]
    return _Conn()
'''


def _connect_env(tmp_path: Path, **overrides: str) -> dict[str, str]:
    fake = tmp_path / "fakepy"
    fake.mkdir(exist_ok=True)
    (fake / "pymssql.py").write_text(FAKE_PYMSSQL, encoding="utf-8")
    env = {
        "PYTHONPATH": str(fake),
        "FAKE_PYMSSQL_LOG": str(tmp_path / "pymssql.log"),
        "SRC_MSSQL_USER": "reader",
        "SRC_MSSQL_PASSWORD": "not-a-real-password",
        "DB_HOST": "coe-index-db-server.database.windows.net",
        "DB_NAME": "LiveBit",
        "RUNNER_IP": "203.0.113.7",
        "CONNECT_ATTEMPTS": "2",
        "CONNECT_RETRY_SECONDS": "0",
    }
    env.update(overrides)
    return env


@requires_bash_jq
def test_connectivity_check_success(wf: dict, tmp_path: Path) -> None:
    proc, _, _ = _run_step(wf, "connect", tmp_path, _connect_env(tmp_path))
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert "Connected to coe-index-db-server.database.windows.net, database LiveBit." in proc.stdout
    assert "Microsoft SQL Azure" in proc.stdout


@requires_bash_jq
def test_connectivity_failure_explains_both_fixes(wf: dict, tmp_path: Path) -> None:
    err = (
        "(40615, b\"Cannot open server 'coe-index-db-server' requested by the login. "
        "Client with IP address '203.0.113.7' is not allowed to access the server.\")"
    )
    env = _connect_env(tmp_path, FAKE_PYMSSQL_ERROR=err)
    proc, _, _ = _run_step(wf, "connect", tmp_path, env)
    assert proc.returncode == 1
    assert "Attempt 1/2 failed" in proc.stdout and "Attempt 2/2 failed" in proc.stdout
    error_line = next(line for line in proc.stdout.splitlines() if line.startswith("::error"))
    assert "%0A" in error_line and "\n" not in error_line  # one annotation, encoded newlines
    assert "public IP 203.0.113.7" in error_line
    assert "Allow Azure services and resources to access this server" in error_line
    assert "SQL server Networking page" in error_line
    assert "AZURE_CLIENT_ID" in error_line and "temporary firewall rule" in error_line
    assert "not-a-real-password" not in proc.stdout + proc.stderr


@requires_bash_jq
def test_connectivity_login_failure_points_at_secrets(wf: dict, tmp_path: Path) -> None:
    env = _connect_env(tmp_path, FAKE_PYMSSQL_ERROR="(18456, b\"Login failed for user 'reader'.\")")
    proc, _, _ = _run_step(wf, "connect", tmp_path, env)
    assert proc.returncode == 1
    assert "::error title=SQL login failed::" in proc.stdout
    assert "SRC_MSSQL_PASSWORD" in proc.stdout


# ---------------------------------------------------------------------------
# behaviour: job summary
# ---------------------------------------------------------------------------

MANIFEST = {
    "database": "LiveBit",
    "target_schemas": ["livebit_dbo", "livebit_divadim", "livebit_zora"],
    "counts": {"tables": 3, "views": 1, "routines": 2, "rows": 1234},
    "tables": [
        {"source": "dbo.Customers", "target_schema": "livebit_dbo", "target_table": "customers",
         "columns": 3, "approx_source_rows": 1000, "exported_rows": 1000},
        {"source": "dbo.Orders", "target_schema": "livebit_dbo", "target_table": "orders",
         "columns": 5, "approx_source_rows": 200, "exported_rows": 200},
        {"source": "divadim.DimDate", "target_schema": "livebit_divadim",
         "target_table": "dimdate", "columns": 2, "approx_source_rows": None,
         "exported_rows": 34},
    ],
    "load_order": ["00_schemas.sql"],
    "review_items": ["routine dbo.usp_x: uses a cursor"],
}


def _summary_env(**overrides: str) -> dict[str, str]:
    env = {
        "DB_NAME": "LiveBit",
        "DB_HOST": "coe-index-db-server.database.windows.net",
        "DB_DIR": "export/livebit",
        "SCHEMA_ONLY": "false",
        "TRIGGER": "workflow_dispatch",
        "REQUEST_FILE": "",
        "COMMIT_RESULTS": "true",
        "MAX_COMMIT_MB": "1800",
        "RUNNER_IP": "203.0.113.7",
        "FIREWALL_RULE": "",
        "CONNECT_OUTCOME": "success",
        "EXPORT_OUTCOME": "success",
        "VALIDATE_OUTCOME": "success",
        "SIZE_MB": "12",
        "DATA_MB": "10",
        "DATA_FILES": "3",
    }
    env.update(overrides)
    return env


def _write_export(tmp_path: Path, report: dict | None = None) -> Path:
    db_dir = tmp_path / "export" / "livebit"
    db_dir.mkdir(parents=True)
    (db_dir / "manifest.json").write_text(json.dumps(MANIFEST), encoding="utf-8")
    if report is not None:
        (db_dir / "validation_report.json").write_text(json.dumps(report), encoding="utf-8")
    return db_dir


@requires_bash_jq
def test_summary_reports_counts_schemas_failures_and_review(wf: dict, tmp_path: Path) -> None:
    report = {
        "ok": False,
        "statements": 57,
        "failures": [{"file": "routines/livebit_dbo__usp_x.sql",
                      "error": 'syntax error at "TOP" | near'}],
        "by_kind": {"tables": {"ok": 3, "failed": 0}, "routines": {"ok": 1, "failed": 1}},
        "row_checks": [
            {"table": "livebit_dbo.orders", "source": "dbo.Orders", "expected": 200,
             "actual": 150, "match": False},
            {"table": "livebit_dbo.customers", "source": "dbo.Customers", "expected": 1000,
             "actual": 1000, "match": True},
        ],
    }
    _write_export(tmp_path, report)
    env = _summary_env(VALIDATE_OUTCOME="failure")
    proc, _, summary = _run_step(wf, "Write job summary", tmp_path, env)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert "## Export `LiveBit` from `coe-index-db-server.database.windows.net`" in summary
    assert "| 3 | 1 | 2 | 1,234 | 3 | 1 |" in summary
    assert "| `livebit_dbo` | 2 | 8 | 1,200 | 1,200 |" in summary
    assert "| `livebit_divadim` | 1 | 2 | 0 | 34 |" in summary
    assert "| `livebit_zora` | 0 | 0 | 0 | 0 |" in summary  # schema with no tables still listed
    assert "| routines | 1 | 1 |" in summary
    assert "### Review items: 1" in summary
    assert "Result: **FAILED**" in summary
    assert "| statements | 57 |" in summary
    assert "**1 failure(s)**" in summary
    assert "`routines/livebit_dbo__usp_x.sql`: syntax error at \"TOP\" \\| near" in summary
    assert "**1 row-count mismatch(es)**" in summary
    assert "`livebit_dbo.orders`: expected 200, loaded 150" in summary


@requires_bash_jq
def test_summary_passed_validation(wf: dict, tmp_path: Path) -> None:
    _write_export(tmp_path, {"ok": True, "failures": []})
    proc, _, summary = _run_step(wf, "Write job summary", tmp_path, _summary_env())
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert "Result: **PASSED**" in summary
    assert "The whole export directory is committed." in summary


@requires_bash_jq
def test_summary_flags_oversized_export(wf: dict, tmp_path: Path) -> None:
    _write_export(tmp_path, {"ok": True})
    env = _summary_env(SIZE_MB="2500", MAX_COMMIT_MB="1800")
    _, _, summary = _run_step(wf, "Write job summary", tmp_path, env)
    assert "everything **except `data/`** is committed" in summary


@requires_bash_jq
def test_summary_validation_crash_without_report(wf: dict, tmp_path: Path) -> None:
    _write_export(tmp_path)
    env = _summary_env(VALIDATE_OUTCOME="failure")
    _, _, summary = _run_step(wf, "Write job summary", tmp_path, env)
    assert "**FAILED** before writing `validation_report.json`" in summary


@requires_bash_jq
def test_summary_ignores_stale_committed_export_when_export_skipped(
    wf: dict, tmp_path: Path
) -> None:
    # export/livebit from an earlier commit is in the checkout, but this run's
    # export never ran: the summary must not present the old files as this run's.
    _write_export(tmp_path, {"ok": True})
    env = _summary_env(CONNECT_OUTCOME="failure", EXPORT_OUTCOME="", VALIDATE_OUTCOME="")
    _, _, summary = _run_step(wf, "Write job summary", tmp_path, env)
    assert "| SQL Server connectivity | FAILED |" in summary
    assert "**The export did not run**" in summary
    assert "### Exported" not in summary
    assert "PASSED" not in summary


# ---------------------------------------------------------------------------
# behaviour: commit and push (stub git)
# ---------------------------------------------------------------------------

FAKE_GIT = """#!/usr/bin/env bash
echo "$*" >> "$FAKE_GIT_LOG"
case "$1" in
  diff) exit "${FAKE_GIT_DIFF_RC:-1}" ;;
  commit)
    prev=""
    for a in "$@"; do
      if [ "$prev" = "-F" ]; then cp "$a" "$FAKE_GIT_COMMIT_MSG"; fi
      prev="$a"
    done ;;
  push)
    n=$(( $(cat "$FAKE_GIT_PUSH_COUNT" 2>/dev/null || echo 0) + 1 ))
    echo "$n" > "$FAKE_GIT_PUSH_COUNT"
    [ "$n" -gt "${FAKE_GIT_PUSH_FAILS:-0}" ] || exit 1 ;;
  pull) exit "${FAKE_GIT_PULL_RC:-0}" ;;
  rev-parse) echo abc1234 ;;
esac
exit 0
"""


def _commit_setup(tmp_path: Path, data_bytes: int = 1024) -> tuple[Path, Path]:
    db_dir = _write_export(tmp_path, {"ok": True})
    (db_dir / "01_schema.sql").write_text("CREATE SCHEMA livebit_dbo;\n", encoding="utf-8")
    (db_dir / "data").mkdir()
    (db_dir / "data" / "livebit_dbo__customers.sql").write_bytes(b"x" * data_bytes)
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    _write_exe(fake_bin / "git", FAKE_GIT)
    return db_dir, fake_bin


def _commit_env(tmp_path: Path, **overrides: str) -> dict[str, str]:
    env = {
        "FAKE_GIT_LOG": str(tmp_path / "git.log"),
        "FAKE_GIT_COMMIT_MSG": str(tmp_path / "commit-msg.txt"),
        "FAKE_GIT_PUSH_COUNT": str(tmp_path / "push-count"),
        "DB_NAME": "LiveBit",
        "DB_DIR": "export/livebit",
        "SCHEMA_ONLY": "false",
        "MAX_COMMIT_MB": "1800",
        "REQUEST_FILE": "",
        "VALIDATE_OUTCOME": "success",
        "ARTIFACT_NAME": "export-livebit-run4242-1",
        "PUSH_ATTEMPTS": "4",
        "PUSH_RETRY_SECONDS": "0",
    }
    env.update(overrides)
    return env


def _git_log(tmp_path: Path) -> list[str]:
    path = tmp_path / "git.log"
    return path.read_text().splitlines() if path.exists() else []


@requires_bash_jq
def test_commit_whole_export_when_small(wf: dict, tmp_path: Path) -> None:
    db_dir, fake_bin = _commit_setup(tmp_path)
    proc, _, summary = _run_step(wf, "commit", tmp_path, _commit_env(tmp_path), fake_bin=fake_bin)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    log = _git_log(tmp_path)
    assert "config user.name github-actions[bot]" in log
    assert "add -A -- export/livebit" in log
    assert not any("exclude" in line or line.startswith("rm ") for line in log)
    assert "push origin HEAD:refs/heads/main" in log
    assert not any(line.startswith("pull") for line in log)
    msg = (tmp_path / "commit-msg.txt").read_text().splitlines()
    assert msg[0] == "Export LiveBit: schema, data, views, routines (run 4242)"
    assert "https://github.com/example-org/example-repo/actions/runs/4242" in "\n".join(msg)
    assert not (db_dir / "DATA_NOT_COMMITTED.md").exists()
    assert "`abc1234` pushed to `main`" in summary


@requires_bash_jq
def test_commit_excludes_data_when_over_threshold(wf: dict, tmp_path: Path) -> None:
    db_dir, fake_bin = _commit_setup(tmp_path, data_bytes=3 * 1024 * 1024)
    env = _commit_env(tmp_path, MAX_COMMIT_MB="1")
    proc, _, summary = _run_step(wf, "commit", tmp_path, env, fake_bin=fake_bin)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    log = _git_log(tmp_path)
    assert "add -A -- export/livebit :(exclude)export/livebit/data" in log
    assert "rm -r -q --cached --ignore-unmatch -- export/livebit/data" in log
    marker = (db_dir / "DATA_NOT_COMMITTED.md").read_text()
    assert "above max_commit_mb (1 MB)" in marker
    assert re.search(r"\| data/ \| [34] MB in 1 files \|", marker)  # du -sm rounds up
    assert "export-livebit-run4242-1" in marker
    assert "data/ NOT committed" in (tmp_path / "commit-msg.txt").read_text()
    assert "**data/ NOT committed**" in summary


@requires_bash_jq
def test_commit_excludes_data_when_a_data_file_exceeds_github_limit(
    wf: dict, tmp_path: Path
) -> None:
    db_dir, fake_bin = _commit_setup(tmp_path)
    with (db_dir / "data" / "livebit_dbo__big.part0001.sql").open("wb") as fh:
        fh.truncate(96 * 1024 * 1024)  # sparse: apparent size > 95 MB, tiny on disk
    proc, _, _ = _run_step(wf, "commit", tmp_path, _commit_env(tmp_path), fake_bin=fake_bin)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert "add -A -- export/livebit :(exclude)export/livebit/data" in _git_log(tmp_path)
    marker = (db_dir / "DATA_NOT_COMMITTED.md").read_text()
    assert "- livebit_dbo__big.part0001.sql" in marker


@requires_bash_jq
def test_commit_refuses_oversized_non_data_file(wf: dict, tmp_path: Path) -> None:
    db_dir, fake_bin = _commit_setup(tmp_path)
    with (db_dir / "03_routines.sql").open("wb") as fh:
        fh.truncate(96 * 1024 * 1024)
    proc, _, _ = _run_step(wf, "commit", tmp_path, _commit_env(tmp_path), fake_bin=fake_bin)
    assert proc.returncode == 1
    assert "03_routines.sql" in proc.stdout and "::error::" in proc.stdout
    assert not any(line.startswith("commit") for line in _git_log(tmp_path))


@requires_bash_jq
def test_commit_skipped_when_nothing_changed(wf: dict, tmp_path: Path) -> None:
    _, fake_bin = _commit_setup(tmp_path)
    env = _commit_env(tmp_path, FAKE_GIT_DIFF_RC="0")
    proc, _, summary = _run_step(wf, "commit", tmp_path, env, fake_bin=fake_bin)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    log = _git_log(tmp_path)
    assert not any(line.startswith(("commit", "push")) for line in log)
    assert "no commit made" in summary


@requires_bash_jq
def test_push_retries_with_rebase(wf: dict, tmp_path: Path) -> None:
    _, fake_bin = _commit_setup(tmp_path)
    env = _commit_env(tmp_path, FAKE_GIT_PUSH_FAILS="2")
    proc, _, _ = _run_step(wf, "commit", tmp_path, env, fake_bin=fake_bin)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    log = _git_log(tmp_path)
    assert sum(line.startswith("push") for line in log) == 3
    assert log.count("pull --rebase origin main") == 2


@requires_bash_jq
def test_push_gives_up_after_three_retries(wf: dict, tmp_path: Path) -> None:
    _, fake_bin = _commit_setup(tmp_path)
    env = _commit_env(tmp_path, FAKE_GIT_PUSH_FAILS="99")
    proc, _, _ = _run_step(wf, "commit", tmp_path, env, fake_bin=fake_bin)
    assert proc.returncode == 1
    assert sum(line.startswith("push") for line in _git_log(tmp_path)) == 4
    assert "failed after 4 attempts" in proc.stdout


@requires_bash_jq
def test_failed_rebase_is_aborted(wf: dict, tmp_path: Path) -> None:
    _, fake_bin = _commit_setup(tmp_path)
    env = _commit_env(tmp_path, FAKE_GIT_PUSH_FAILS="1", FAKE_GIT_PULL_RC="1")
    proc, _, _ = _run_step(wf, "commit", tmp_path, env, fake_bin=fake_bin)
    assert proc.returncode == 1
    assert "rebase --abort" in _git_log(tmp_path)


@requires_bash_jq
def test_schema_only_commit_subject(wf: dict, tmp_path: Path) -> None:
    _, fake_bin = _commit_setup(tmp_path)
    env = _commit_env(tmp_path, SCHEMA_ONLY="true")
    proc, _, _ = _run_step(wf, "commit", tmp_path, env, fake_bin=fake_bin)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    subject = (tmp_path / "commit-msg.txt").read_text().splitlines()[0]
    assert subject == "Export LiveBit: schema, views, routines (schema only, run 4242)"


@requires_bash_jq
def test_commit_skipped_on_tag_and_refused_without_manifest(wf: dict, tmp_path: Path) -> None:
    db_dir, fake_bin = _commit_setup(tmp_path)
    env = _commit_env(tmp_path, GITHUB_REF_TYPE="tag", GITHUB_REF_NAME="v1")
    proc, _, _ = _run_step(wf, "commit", tmp_path, env, fake_bin=fake_bin)
    assert proc.returncode == 0 and "::warning::" in proc.stdout
    assert _git_log(tmp_path) == []

    (db_dir / "manifest.json").unlink()
    proc, _, _ = _run_step(wf, "commit", tmp_path, _commit_env(tmp_path), fake_bin=fake_bin)
    assert proc.returncode == 1
    assert "refusing to commit an incomplete export" in proc.stdout


# ---------------------------------------------------------------------------
# integration: the validate + summary steps against a real Postgres 16
# ---------------------------------------------------------------------------

PG_BIN = Path("/usr/lib/postgresql/16/bin")


def _cli_supports_validation() -> bool:
    try:
        sys.path.insert(0, str(REPO / "src"))
        from dbmigration.cli import main
    except Exception:  # noqa: BLE001 - CLI may be mid-edit; then skip
        return False
    finally:
        sys.path.remove(str(REPO / "src"))
    load_dump = main.commands.get("load-dump")
    if load_dump is None:
        return False
    flags = {opt for p in load_dump.params for opt in getattr(p, "opts", [])}
    return {"--target-url", "--report"} <= flags


def _free_port() -> int:
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


@pytest.fixture
def pg16_url():
    """Start a throwaway Postgres 16 cluster; always stopped afterwards."""
    if not (PG_BIN / "initdb").exists():
        pytest.skip("PostgreSQL 16 binaries not installed")
    base = Path(tempfile.mkdtemp(prefix="wf-pg16-"))
    data, sock = base / "data", base / "sock"
    sock.mkdir()
    prefix: list[str] = []
    if os.geteuid() == 0:  # initdb refuses to run as root
        prefix = ["runuser", "-u", "postgres", "--"]
        for path in (base, sock):
            shutil.chown(path, "postgres", "postgres")
    port = _free_port()
    subprocess.run(
        [*prefix, str(PG_BIN / "initdb"), "-D", str(data), "-U", "postgres",
         "--auth=trust", "-E", "UTF8"],
        check=True, capture_output=True,
    )
    subprocess.run(
        [*prefix, str(PG_BIN / "pg_ctl"), "-D", str(data), "-w", "-l", str(base / "pg.log"),
         "-o", f"-p {port} -k {sock} -c listen_addresses=localhost", "start"],
        check=True, capture_output=True,
    )
    try:
        yield f"postgresql://postgres:postgres@localhost:{port}/postgres"
    finally:
        subprocess.run(
            [*prefix, str(PG_BIN / "pg_ctl"), "-D", str(data), "-m", "fast", "stop"],
            capture_output=True,
            check=False,
        )
        shutil.rmtree(base, ignore_errors=True)


@requires_bash_jq
@pytest.mark.skipif(
    not _cli_supports_validation(), reason="dbmigrate load-dump lacks --target-url/--report"
)
def test_validate_step_loads_example_export_into_postgres16(
    wf: dict, tmp_path: Path, pg16_url: str
) -> None:
    example = REPO / "examples" / "example-export" / "livebit"
    shutil.copytree(example, tmp_path / "export" / "livebit")
    (tmp_path / "config").mkdir()
    shutil.copy(REPO / "config" / "migration.example.yaml", tmp_path / "config" / "migration.yaml")
    fake_bin = tmp_path / "bin"
    fake_bin.mkdir()
    _write_exe(
        fake_bin / "dbmigrate",
        f'#!/usr/bin/env bash\nexec "{sys.executable}" -c '
        '"import sys; from dbmigration.cli import main; sys.exit(main())" "$@"\n',
    )
    env = {
        "PYTHONPATH": str(REPO / "src"),
        "DB_DIR": "export/livebit",
        "VALIDATION_DB_URL": pg16_url,
    }
    proc, _, _ = _run_step(wf, "validate", tmp_path, env, fake_bin=fake_bin)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    report = tmp_path / "export" / "livebit" / "validation_report.json"
    assert report.is_file()

    _, _, summary = _run_step(wf, "Write job summary", tmp_path, _summary_env())
    assert "Result: **PASSED**" in summary
