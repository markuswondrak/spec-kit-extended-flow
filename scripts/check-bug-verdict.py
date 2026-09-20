#!/usr/bin/env python3
"""Fail unless the active bug verification report says verified."""

import json
from pathlib import Path
import re
import sys


def error(message: str) -> int:
    print(f"ERROR: {message}", file=sys.stderr)
    return 1


def main() -> int:
    feature_json = Path(".specify/feature.json")
    if not feature_json.is_file():
        return error(f"{feature_json} not found.")
    try:
        data = json.loads(feature_json.read_text())
    except (OSError, ValueError):
        data = {}
    bug_dir = data.get("feature_directory") if isinstance(data, dict) else ""
    if not isinstance(bug_dir, str) or not bug_dir:
        return error(f"Could not determine bug directory from {feature_json}.")

    test_file = Path(bug_dir) / "test.md"
    if not test_file.is_file():
        return error(f"Bug verification report not found: {test_file}")
    try:
        content = test_file.read_text()
    except OSError:
        return error(f"Bug verification report not found: {test_file}")
    match = re.search(r"^[ \t]*-[ \t]*\*\*Result\*\*:[ \t]*(.*)$", content, re.MULTILINE)
    result = match.group(1) if match else ""
    if result == "verified":
        print("verified")
        return 0
    if result in ("partial", "failed"):
        print(result, file=sys.stderr)
        return error(f"Bug verification result is '{result}'.")
    return error(f"Missing or invalid Result field in {test_file}.")


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: Unexpected error: {exc}", file=sys.stderr)
        raise SystemExit(1)
