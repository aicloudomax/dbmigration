"""Console + file logging via Rich."""

from __future__ import annotations

import logging
from pathlib import Path

from rich.logging import RichHandler


def get_logger(name: str = "dbmigration", logfile: Path | None = None) -> logging.Logger:
    logger = logging.getLogger(name)
    if logger.handlers:
        return logger
    logger.setLevel(logging.INFO)

    logger.addHandler(RichHandler(rich_tracebacks=True, show_path=False))
    if logfile:
        logfile.parent.mkdir(parents=True, exist_ok=True)
        fh = logging.FileHandler(logfile)
        fh.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
        logger.addHandler(fh)
    return logger
