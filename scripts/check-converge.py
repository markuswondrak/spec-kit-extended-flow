#!/usr/bin/env python3
"""Record and compare a feature tasks.md content hash."""

import hashlib
import json
from pathlib import Path
import sys


USAGE = "Usage: check-converge.py {snapshot|check} <run_id>"


def error(message: str) -> int:
    print(f"ERROR: {message}", file=sys.stderr)
    return 1


def feature_directory(feature_json: Path) -> str:
    try:
        data = json.loads(feature_json.read_text())
    except (OSError, ValueError):
        return ""
    if not isinstance(data, dict):
        return ""
    for key in ("feature_directory", "dir", "name", "path"):
        value = data.get(key)
        if isinstance(value, str) and value:
            return value
    return ""


def hash_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    run_id = sys.argv[2] if len(sys.argv) > 2 else ""
    if mode not in ("snapshot", "check"):
        print("ERROR: first argument must be 'snapshot' or 'check'.", file=sys.stderr)
        print(USAGE, file=sys.stderr)
        return 1
    if not run_id:
        print("ERROR: run_id is required.", file=sys.stderr)
        print(USAGE, file=sys.stderr)
        return 1

    feature_json = Path(".specify/feature.json")
    if not feature_json.is_file():
        return error(f"{feature_json} not found.")
    feature_dir = feature_directory(feature_json)
    if not feature_dir:
        return error(f"Could not determine feature directory from {feature_json}.")

    direct_tasks = Path(feature_dir) / "tasks.md"
    prefixed_tasks = Path("specs") / feature_dir / "tasks.md"
    if direct_tasks.is_file():
        tasks_file = direct_tasks
    elif prefixed_tasks.is_file():
        tasks_file = prefixed_tasks
    else:
        return error(f"tasks.md not found for feature directory '{feature_dir}'.")

    run_dir = Path(".specify/workflows/runs") / run_id
    baseline_file = run_dir / "converge-baseline.txt"
    run_dir.mkdir(parents=True, exist_ok=True)
    if mode == "snapshot":
        baseline_file.write_text(f"{hash_file(tasks_file)}\n")
        print(f"OK: recorded baseline for {tasks_file}")
        return 0

    if not baseline_file.is_file():
        return error(f"No converge baseline found at {baseline_file}. Run snapshot first.")
    verdict = "CONVERGED" if hash_file(tasks_file) == baseline_file.read_text().rstrip("\n") else "TASKS_APPENDED"
    (run_dir / "converge-state.txt").write_text(f"{verdict}\n")
    print(verdict)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: Unexpected error: {exc}", file=sys.stderr)
        raise SystemExit(1)
