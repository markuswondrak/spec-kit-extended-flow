#!/usr/bin/env python3
"""Initialize a Quick Flow directory and feature pointer from the current directory."""

import json
from pathlib import Path
import re
import shutil
import subprocess
import sys


def error(message: str) -> int:
    print(f"ERROR: {message}", file=sys.stderr)
    return 1


def slugify(value: str, maximum: int = 50) -> str:
    value = value.translate(str.maketrans("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz"))
    slug = re.sub(r"[^a-z0-9]", "-", value)
    return re.sub(r"-+", "-", slug).strip("-")[:maximum].rstrip("-")


def main() -> int:
    issue = sys.argv[1] if len(sys.argv) > 1 else ""
    spec_text = sys.argv[2] if len(sys.argv) > 2 else ""
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
        return error(f"Feature directory already exists: {feature_dir}")
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
