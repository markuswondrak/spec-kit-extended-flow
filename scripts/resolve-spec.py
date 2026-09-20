#!/usr/bin/env python3
"""Resolve Extended Flow specification inputs from a workflow run."""

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

    User-supplied text is read from the run's ``inputs.json`` file rather than
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


def read_input(inputs: dict, key: str) -> str:
    value = inputs.get(key, "")
    if value is None:
        return ""
    if not isinstance(value, str):
        raise InputError(f"Workflow input {key!r} must be a string.")
    return value


def main() -> int:
    run_id = sys.argv[1] if len(sys.argv) > 1 else ""
    if not run_id:
        return error("Run id is required.")

    try:
        inputs = load_run_inputs(run_id)
        spec = read_input(inputs, "spec")
        file_path = read_input(inputs, "file")
        issue = read_input(inputs, "issue")
    except InputError as exc:
        return error(str(exc))

    if issue and not ISSUE_PATTERN.fullmatch(issue):
        return error(f"Invalid issue number: {issue!r}.")

    output = b""

    if file_path:
        path = Path(file_path)
        if not path.is_file():
            return error(f"Spec file not found: {file_path}")
        try:
            with path.open("rb") as spec_file:
                file_content = spec_file.read()
        except OSError:
            return error(f"Spec file not found: {file_path}")
        output += file_content.rstrip(b"\n") + b"\n"

    if issue:
        if shutil.which("gh") is None:
            return error(
                "GitHub CLI (gh) is required to fetch issues. Install and "
                "authenticate with 'gh auth login'."
            )
        try:
            result = subprocess.run(
                ["gh", "issue", "view", issue, "--json", "title,body", "--jq", '"# " + .title + "\\n\\n" + .body'],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                check=False,
            )
        except OSError:
            return error(
                "GitHub CLI (gh) is required to fetch issues. Install and "
                "authenticate with 'gh auth login'."
            )
        if result.returncode != 0:
            return error(
                f"Failed to fetch issue #{issue}. Ensure the issue exists and gh is authenticated."
            )
        output += result.stdout.rstrip(b"\n") + b"\n"

    if spec:
        output += spec.encode(errors="surrogateescape") + b"\n"

    if not output:
        return error(
            "No specification provided. Set at least one of: --input spec, --input file, or --input issue."
        )

    # Command substitution in the shell implementation strips trailing newlines
    # from each input before it appends one, then echo appends this final newline.
    resolved = output + b"\n"

    # Persist the resolved instruction for shell steps that cannot receive free
    # text as an argument without exposing it to shell interpretation (see the
    # Quick Flow's init-quick step).
    try:
        (RUNS_DIR / run_id / "resolved-spec.txt").write_bytes(resolved)
    except OSError as exc:
        return error(f"Failed to persist resolved spec: {exc}")

    sys.stdout.buffer.write(resolved)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except BrokenPipeError:
        raise SystemExit(1)
    except Exception as exc:
        print(f"ERROR: Unexpected error: {exc}", file=sys.stderr)
        raise SystemExit(1)
