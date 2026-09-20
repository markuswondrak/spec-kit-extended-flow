#!/usr/bin/env python3
"""Create or check out an issue branch from the current repository."""

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
    slug = re.sub(r"-+", "-", slug).strip("-")
    return slug[:maximum].rstrip("-")


def main() -> int:
    issue = sys.argv[1] if len(sys.argv) > 1 else ""
    prefix = sys.argv[2] if len(sys.argv) > 2 else "feature"
    if not issue:
        return error("Issue number is required.")
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
