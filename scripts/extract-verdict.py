#!/usr/bin/env python3
"""Extract the latest PASS or FAIL verdict from review findings filenames."""

import json
from pathlib import Path
import re
import sys


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


def main() -> int:
    run_id = sys.argv[1] if len(sys.argv) > 1 else ""
    feature_json = Path(".specify/feature.json")
    if not feature_json.is_file():
        return error(f"{feature_json} not found.")
    feature_dir = feature_directory(feature_json)
    if not feature_dir:
        return error(f"Could not determine feature directory from {feature_json}")
    if feature_dir.startswith("specs/"):
        feature_dir = feature_dir[len("specs/"):]

    review_dir = Path("specs") / feature_dir
    if not review_dir.is_dir():
        return error(f"Feature directory not found: {review_dir}")
    candidates = list(review_dir.glob("review-findings-*-*.md"))
    if not candidates:
        return error(f"No review-findings-*-*.md found in {review_dir}")

    matches = []
    for candidate in candidates:
        match = re.fullmatch(r"review-findings-(\d+)-(.*)\.md", candidate.name)
        if match:
            matches.append((int(match.group(1)), candidate, match.group(2)))
    if not matches:
        return error("Could not determine latest review findings file")
    _, verdict_file, verdict = max(matches, key=lambda item: item[0])
    if verdict not in ("PASS", "FAIL"):
        return error(f"Unexpected verdict '{verdict}' in filename: {verdict_file.name}")

    print(verdict)
    if run_id:
        run_dir = Path(".specify/workflows/runs") / run_id
        run_dir.mkdir(parents=True, exist_ok=True)
        (run_dir / "review-verdict.txt").write_text(f"{verdict}\n")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: Unexpected error: {exc}", file=sys.stderr)
        raise SystemExit(1)
