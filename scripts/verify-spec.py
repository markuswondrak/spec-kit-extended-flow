#!/usr/bin/env python3
"""Verify that a specify command created the active specification."""

import json
from pathlib import Path
import sys


def error(message: str) -> int:
    print(f"ERROR: {message}", file=sys.stderr)
    return 1


def main() -> int:
    feature_json = Path(".specify/feature.json")
    if not feature_json.is_file():
        print(
            f"ERROR: {feature_json} not found. The specify step did not create a feature directory.",
            file=sys.stderr,
        )
        print("       This usually happens when the before_specify hook (speckit.git.feature)", file=sys.stderr)
        print("       could not execute. If you are using an integration that does not support", file=sys.stderr)
        print("       EXECUTE_COMMAND (e.g., opencode), disable the git extension before running", file=sys.stderr)
        print("       this workflow: specify extension disable git", file=sys.stderr)
        return 1
    try:
        data = json.loads(feature_json.read_text())
    except (OSError, ValueError):
        data = {}
    feature_dir = ""
    if isinstance(data, dict):
        for key in ("feature_directory", "dir", "name", "path"):
            value = data.get(key)
            if isinstance(value, str) and value:
                feature_dir = value
                break
    if not feature_dir:
        return error(f"{feature_json} does not contain a valid feature_directory.")
    directory = Path(feature_dir)
    if not directory.is_dir():
        return error(f"Feature directory '{feature_dir}' does not exist.")
    spec_file = directory / "spec.md"
    if not spec_file.is_file():
        return error(f"Spec file '{spec_file}' not found. The specify step did not write a specification.")
    print(f"Spec verification passed: {spec_file}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: Unexpected error: {exc}", file=sys.stderr)
        raise SystemExit(1)
