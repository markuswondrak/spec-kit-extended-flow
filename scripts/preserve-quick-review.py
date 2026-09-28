#!/usr/bin/env python3
"""Commit Quick Flow work before a human resolves a failed review."""

import json
from pathlib import Path
import re
import shutil
import subprocess
import sys


RUNS_DIR = Path(".specify") / "workflows" / "runs"
RUN_ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]+$")


def error(message: str) -> int:
    print(f"ERROR: {message}", file=sys.stderr)
    return 1


def run(command: list[str]) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)


def main() -> int:
    run_id = sys.argv[1] if len(sys.argv) > 1 else ""
    if not RUN_ID_PATTERN.fullmatch(run_id):
        return error(f"Invalid run id: {run_id!r}.")
    if shutil.which("git") is None:
        return error("Git CLI (git) is required to preserve Quick Flow work.")
    try:
        pointer = json.loads(Path(".specify/feature.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return error("Could not read .specify/feature.json for the Quick Flow work.")
    if not isinstance(pointer, dict) or pointer.get("type") != "quick":
        return error("The active feature is not a Quick Flow feature.")
    try:
        inputs = json.loads((RUNS_DIR / run_id / "inputs.json").read_text(encoding="utf-8"))
    except OSError:
        return error(f"Workflow inputs not found: {RUNS_DIR / run_id / 'inputs.json'}")
    except json.JSONDecodeError:
        return error(f"Workflow inputs are not valid JSON: {RUNS_DIR / run_id / 'inputs.json'}")
    values = inputs.get("inputs") if isinstance(inputs, dict) else None
    issue = values.get("issue") if isinstance(values, dict) else ""
    if not isinstance(issue, str):
        return error("Workflow input 'issue' must be a string.")

    if run(["git", "add", "-A"]).returncode != 0:
        return error("Failed to stage Quick Flow work.")
    staged = run(["git", "diff", "--cached", "--quiet"])
    if staged.returncode == 0:
        print("NO_CHANGES")
        return 0
    if staged.returncode != 1:
        return error("Failed to inspect staged Quick Flow work.")
    message = "chore: preserve Quick Flow review failure"
    if issue:
        message += f" (#{issue})"
    result = run(["git", "commit", "-m", message])
    if result.returncode != 0:
        return error(result.stdout.decode(errors="surrogateescape").rstrip() or "Failed to preserve Quick Flow work.")
    print("PRESERVED")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: Unexpected error: {exc}", file=sys.stderr)
        raise SystemExit(1)
