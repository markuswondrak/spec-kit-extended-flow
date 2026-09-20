#!/usr/bin/env python3
"""Create or check out an issue branch from the current repository."""

import json
import re
import shutil
import subprocess
import sys
from pathlib import Path


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


def slugify(value: str, maximum: int = 50) -> str:
    value = value.translate(str.maketrans("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz"))
    slug = re.sub(r"[^a-z0-9]", "-", value)
    slug = re.sub(r"-+", "-", slug).strip("-")
    return slug[:maximum].rstrip("-")


def main() -> int:
    run_id = sys.argv[1] if len(sys.argv) > 1 else ""
    prefix = sys.argv[2] if len(sys.argv) > 2 else ""
    prefix = prefix or "feature"
    if not run_id:
        return error("Run id is required.")

    try:
        inputs = load_run_inputs(run_id)
    except InputError as exc:
        return error(str(exc))
    issue = inputs.get("issue") or ""
    if not isinstance(issue, str):
        return error("Workflow input 'issue' must be a string.")
    if not issue:
        return error("Issue number is required.")
    if not ISSUE_PATTERN.fullmatch(issue):
        return error(f"Invalid issue number: {issue!r}.")

    if shutil.which("gh") is None:
        return error(
            "GitHub CLI (gh) is required to create a branch from an issue. Install and "
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
            "GitHub CLI (gh) is required to create a branch from an issue. Install and "
            "authenticate with 'gh auth login'."
        )
    if result.returncode != 0:
        return error(f"Failed to fetch issue #{issue}. Ensure the issue exists and gh is authenticated.")

    title = result.stdout.decode(errors="surrogateescape").rstrip("\n")
    branch_name = f"{prefix.rstrip('/')}/{issue}-{slugify(title)}"
    if shutil.which("git") is None:
        return error("Git CLI (git) is required to create an issue branch. Install Git and try again.")
    try:
        exists = subprocess.run(
            ["git", "show-ref", "--verify", "--quiet", f"refs/heads/{branch_name}"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        ).returncode == 0
        command = ["git", "checkout", branch_name] if exists else ["git", "checkout", "-b", branch_name]
        if subprocess.run(command, check=False).returncode != 0:
            return 1
    except OSError:
        return error("Git CLI (git) is required to create an issue branch. Install Git and try again.")

    print(branch_name)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: Unexpected error: {exc}", file=sys.stderr)
        raise SystemExit(1)
