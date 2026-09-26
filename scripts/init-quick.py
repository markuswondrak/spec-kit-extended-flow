#!/usr/bin/env python3
"""Initialize a Quick Flow directory and feature pointer from a workflow run."""

import json
from pathlib import Path
import re
import shutil
import subprocess
import sys


RUNS_DIR = Path(".specify") / "workflows" / "runs"
RUN_ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]+$")
ISSUE_PATTERN = re.compile(r"^[0-9]+$")


def error(message: str) -> int:
    print(f"ERROR: {message}", file=sys.stderr)
    return 1


class InputError(Exception):
    """Raised when the workflow run inputs cannot be read."""


def load_run_inputs(run_id: str) -> dict:
    """Load the ``inputs`` object the engine wrote for *run_id*.

    The issue number is read from the run's ``inputs.json`` file rather than
    from the command line, so it is never interpreted by the shell executing
    this script.
    """
    if not RUN_ID_PATTERN.fullmatch(run_id):
        raise InputError(f"Invalid run id: {run_id!r}.")
    inputs_path = RUNS_DIR / run_id / "inputs.json"
    try:
        document = json.loads(inputs_path.read_text(encoding="utf-8"))
    except OSError:
        raise InputError(f"Workflow inputs not found: {inputs_path}")
    except json.JSONDecodeError:
        raise InputError(f"Workflow inputs are not valid JSON: {inputs_path}")
    if not isinstance(document, dict) or not isinstance(document.get("inputs"), dict):
        raise InputError(f"Workflow inputs are malformed: {inputs_path}")
    return document["inputs"]


def read_resolved_spec(run_id: str) -> str:
    """Read the instruction resolved by the ``resolve-spec`` step.

    The resolved text is read from the run directory instead of a command-line
    argument so it is never interpreted by the shell executing this script.
    """
    resolved_path = RUNS_DIR / run_id / "resolved-spec.txt"
    try:
        return resolved_path.read_bytes().decode(errors="surrogateescape")
    except OSError:
        raise InputError(f"Resolved spec not found: {resolved_path}")


def slugify(value: str, maximum: int = 50) -> str:
    value = value.translate(str.maketrans("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz"))
    slug = re.sub(r"[^a-z0-9]", "-", value)
    return re.sub(r"-+", "-", slug).strip("-")[:maximum].rstrip("-")


def main() -> int:
    run_id = sys.argv[1] if len(sys.argv) > 1 else ""
    if not run_id:
        return error("Run id is required.")

    try:
        inputs = load_run_inputs(run_id)
        issue = inputs.get("issue") or ""
        if not isinstance(issue, str):
            return error("Workflow input 'issue' must be a string.")
        if issue and not ISSUE_PATTERN.fullmatch(issue):
            return error(f"Invalid issue number: {issue!r}.")
        spec_text = "" if issue else read_resolved_spec(run_id)
    except InputError as exc:
        return error(str(exc))

    if not issue and not spec_text:
        return error("At least one of issue or spec text is required.")

    if issue:
        if shutil.which("gh") is None:
            return error(
                "GitHub CLI (gh) is required to create a directory from an issue. Install and "
                "authenticate with 'gh auth login'."
            )
        try:
            result = subprocess.run(
                ["gh", "issue", "view", issue, "--json", "title", "--jq", ".title"],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                check=False,
            )
        except OSError:
            return error(
                "GitHub CLI (gh) is required to create a directory from an issue. Install and "
                "authenticate with 'gh auth login'."
            )
        if result.returncode != 0:
            return error(f"Failed to fetch issue #{issue}. Ensure the issue exists and gh is authenticated.")
        directory_name = f"{issue}-quick-{slugify(result.stdout.decode(errors='surrogateescape').rstrip(chr(10)))}"
    else:
        slug = slugify(spec_text[:30], 30) or "change"
        directory_name = f"quick-{slug}"

    feature_dir = Path("specs") / directory_name
    if feature_dir.is_dir():
        for stale in feature_dir.glob("review-findings-*.md"):
            stale.unlink()
        for generated in ("instruction.md", "plan.md", "approved-scope.json", "doc-check.md"):
            stale = feature_dir / generated
            if stale.is_file():
                stale.unlink()
    else:
        feature_dir.mkdir(parents=True)
    Path(".specify").mkdir(parents=True, exist_ok=True)
    Path(".specify/feature.json").write_text(
        json.dumps({"feature_directory": str(feature_dir), "type": "quick"}, separators=(", ", ": ")) + "\n"
    )
    print(feature_dir)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: Unexpected error: {exc}", file=sys.stderr)
        raise SystemExit(1)
