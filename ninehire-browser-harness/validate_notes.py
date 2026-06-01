"""Validate all STAGE 2 notes before posting.

Usage:
    NINEHIRE_RUN_DIR=ninehire-browser-harness/batch_runs/<timestamp> \
        python3 ninehire-browser-harness/validate_notes.py
"""

from __future__ import annotations

import json
import os
from pathlib import Path

from note_quality import validate_run_notes


def main() -> None:
    run_dir_raw = os.environ.get("NINEHIRE_RUN_DIR")
    if not run_dir_raw:
        raise SystemExit("Set NINEHIRE_RUN_DIR to the batch run folder.")

    run_dir = Path(run_dir_raw)
    if not run_dir.exists():
        raise SystemExit(f"Run dir not found: {run_dir}")

    failures = validate_run_notes(run_dir)
    summary = {
        "run_dir": str(run_dir),
        "checked": len(list(run_dir.glob("*/metadata.json"))),
        "failed": len(failures),
        "failures": failures,
    }
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
