#!/usr/bin/env python3
"""Record the active assessed bug directory in the feature pointer."""

import json
from pathlib import Path
import re
import sys


def error(message: str) -> int:
    print(f"ERROR: {message}", file=sys.stderr)
    return 1


def main() -> int:
    requested_slug = sys.argv[1] if len(sys.argv) > 1 else ""
    bugs_dir = Path(".specify/bugs")
    feature_json = Path(".specify/feature.json")
    if not bugs_dir.is_dir():
        return error(f"{bugs_dir} not found. Has speckit.bug.assess run?")

    if requested_slug:
        if not re.fullmatch(r"[a-z0-9](?:[a-z0-9-]*[a-z0-9])?", requested_slug):
            return error(f"Invalid bug slug: {requested_slug}")
        bug_dir = bugs_dir / requested_slug
        if not (bug_dir / "assessment.md").is_file():
            return error(f"Assessment not found for bug slug: {requested_slug}")
    else:
        assessments = [path for path in bugs_dir.glob("*/assessment.md") if path.is_file()]
        if not assessments:
            return error(f"No assessment.md found in {bugs_dir}")
        # The shell script favors the later glob entry when mtimes tie.
        bug_dir = max(assessments, key=lambda path: (path.stat().st_mtime, str(path))).parent

    feature_json.parent.mkdir(parents=True, exist_ok=True)
    feature_json.write_text(json.dumps({"feature_directory": str(bug_dir), "type": "bug"}, separators=(",", ":")) + "\n")
    print(bug_dir.name)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: Unexpected error: {exc}", file=sys.stderr)
        raise SystemExit(1)
