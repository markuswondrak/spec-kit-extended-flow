#!/usr/bin/env python3
"""Resolve the first GitHub-standard pull-request template from the CWD."""

from pathlib import Path
import sys


def main() -> int:
    repo_root = Path.cwd()
    variant_dir = repo_root / ".github/PULL_REQUEST_TEMPLATE"
    if variant_dir.is_dir() and not variant_dir.is_symlink():
        variants = sorted(path for path in variant_dir.glob("*.md") if path.is_file() and not path.is_symlink())
        if variants:
            print(variants[0])
            return 0
    for candidate in (
        repo_root / ".github/PULL_REQUEST_TEMPLATE.md",
        repo_root / "docs/PULL_REQUEST_TEMPLATE.md",
        repo_root / "PULL_REQUEST_TEMPLATE.md",
    ):
        if candidate.is_file():
            print(candidate)
            return 0
    print()
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: Unexpected error: {exc}", file=sys.stderr)
        raise SystemExit(1)
