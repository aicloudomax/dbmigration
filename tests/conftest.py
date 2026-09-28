"""Shared fixtures: a throwaway PostgreSQL cluster for end-to-end tests.

``pg_url`` starts one cluster per test session (skipped when PostgreSQL server
binaries or psycopg are unavailable); ``pg_database`` gives each test its own
fresh database on it, dropped afterwards.
"""

from __future__ import annotations

import glob
import os
import re
import shutil
import socket
import subprocess
import tempfile
import uuid
from collections.abc import Iterator
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit

import pytest


def _free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def _initdb_binary() -> Path | None:
    def version(path: str) -> tuple[int, ...]:
        m = re.search(r"/postgresql/([\d.]+)/", path)
        return tuple(int(p) for p in m.group(1).split(".")) if m else (0,)

    found = sorted(glob.glob("/usr/lib/postgresql/*/bin/initdb"), key=version)
    return Path(found[-1]) if found else None


def _as_postgres(cmd: list[str]) -> list[str]:
    """initdb/pg_ctl refuse to run as root: drop to the postgres user when root."""
    if hasattr(os, "geteuid") and os.geteuid() == 0:
        return ["runuser", "-u", "postgres", "--", *cmd]
    return cmd


def _run(cmd: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(
        _as_postgres(cmd), capture_output=True, text=True, timeout=120, check=False
    )


def database_url(url: str, dbname: str) -> str:
    """*url* pointing at database *dbname* instead."""
    parts = urlsplit(url)
    return urlunsplit((parts.scheme, parts.netloc, f"/{dbname}", parts.query, parts.fragment))


@pytest.fixture(scope="session")
def pg_url() -> Iterator[str]:
    """URL of a throwaway PostgreSQL cluster (unix socket only), stopped at session end."""
    initdb = _initdb_binary()
    if initdb is None:
        pytest.skip("PostgreSQL server binaries not found under /usr/lib/postgresql")
    try:
        import psycopg  # noqa: F401
    except ImportError:
        pytest.skip("psycopg is not installed")
    is_root = hasattr(os, "geteuid") and os.geteuid() == 0
    if is_root and not shutil.which("runuser"):
        pytest.skip("running as root but runuser is unavailable")
    pg_ctl = str(initdb.parent / "pg_ctl")

    # A short path under /tmp keeps the socket path within the 107-byte limit and
    # is reachable by the postgres user.
    tmp = Path(tempfile.mkdtemp(prefix="dbmig-pg-", dir="/tmp" if os.path.isdir("/tmp") else None))
    started = False
    data = tmp / "data"
    try:
        if is_root:
            try:
                shutil.chown(tmp, "postgres", "postgres")
            except (LookupError, PermissionError, OSError) as exc:
                pytest.skip(f"cannot hand the cluster directory to the postgres user: {exc}")
        proc = _run([str(initdb), "-D", str(data), "-A", "trust", "-U", "postgres",
                     "-E", "UTF8", "--no-locale"])
        if proc.returncode != 0:
            pytest.skip(f"initdb failed: {proc.stderr.strip() or proc.stdout.strip()}")
        port = _free_port()
        options = f"-k {tmp} -p {port} -c listen_addresses='' -c fsync=off"
        proc = _run([pg_ctl, "-D", str(data), "-l", str(tmp / "server.log"), "-w", "-t", "60",
                     "-o", options, "start"])
        if proc.returncode != 0:
            log = (tmp / "server.log").read_text() if (tmp / "server.log").exists() else ""
            pytest.skip(f"pg_ctl start failed: {proc.stderr.strip()} {log[-500:]}")
        started = True
        yield f"postgresql://postgres@/postgres?host={tmp}&port={port}"
    finally:
        if started:
            stop = [pg_ctl, "-D", str(data), "-w", "stop", "-m"]
            if _run([*stop, "fast"]).returncode != 0:
                _run([*stop, "immediate"])
        shutil.rmtree(tmp, ignore_errors=True)


@pytest.fixture
def pg_database(pg_url: str) -> Iterator[str]:
    """URL of a new, empty database (``t_<uuid>``) on the throwaway cluster."""
    import psycopg

    name = f"t_{uuid.uuid4().hex}"
    with psycopg.connect(pg_url, autocommit=True) as conn:
        conn.execute(f'CREATE DATABASE "{name}"')
    try:
        yield database_url(pg_url, name)
    finally:
        with psycopg.connect(pg_url, autocommit=True) as conn:
            conn.execute(f'DROP DATABASE IF EXISTS "{name}" WITH (FORCE)')
