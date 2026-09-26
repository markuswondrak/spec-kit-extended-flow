#!/usr/bin/env python3
"""Record the approved Quick Flow plan as an immutable review baseline."""

import hashlib
import json
from pathlib import Path
import re
import sys


RUNS_DIR = Path(".specify") / "workflows" / "runs"
RUN_ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]+$")


def error(message: str) -> int:
    print(f"ERROR: {message}", file=sys.stderr)
    return 1


def feature_directory() -> Path | None:
    try:
        pointer = json.loads(Path(".specify/feature.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    if not isinstance(pointer, dict) or pointer.get("type") != "quick":
        return None
    value = pointer.get("feature_directory")
    return Path(value) if isinstance(value, str) and value else None


def main() -> int:
    run_id = sys.argv[1] if len(sys.argv) > 1 else ""
    if not RUN_ID_PATTERN.fullmatch(run_id):
        return error(f"Invalid run id: {run_id!r}.")

    try:
        state = json.loads((RUNS_DIR / run_id / "state.json").read_text(encoding="utf-8"))
    except OSError:
        return error(f"Workflow state not found: {RUNS_DIR / run_id / 'state.json'}")
    except json.JSONDecodeError:
        return error(f"Workflow state is not valid JSON: {RUNS_DIR / run_id / 'state.json'}")
    steps = state.get("step_results") if isinstance(state, dict) else None
    gate = steps.get("quick-plan-gate") if isinstance(steps, dict) else None
    output = gate.get("output") if isinstance(gate, dict) else None
    if not isinstance(output, dict) or output.get("choice") != "approve":
        return error("Quick plan gate has not been approved.")

    directory = feature_directory()
    if directory is None:
        return error("Could not determine Quick Flow feature directory from .specify/feature.json.")
    plan = directory / "plan.md"
    try:
        digest = hashlib.sha256(plan.read_bytes()).hexdigest()
    except OSError:
        return error(f"Quick plan not found: {plan}")

    artifact = {
        "schema_version": 1,
        "plan": "plan.md",
        "plan_sha256": digest,
        "approved_by": "quick-plan-gate",
        "choice": "approve",
    }
    (directory / "approved-scope.json").write_text(
        json.dumps(artifact, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(directory / "approved-scope.json")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: Unexpected error: {exc}", file=sys.stderr)
        raise SystemExit(1)
