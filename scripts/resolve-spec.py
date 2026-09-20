#!/usr/bin/env python3
"""Resolve Extended Flow specification inputs from the current directory."""

import shutil
import subprocess
import sys


def error(message: str) -> int:
    print(f"ERROR: {message}", file=sys.stderr)
    return 1


def main() -> int:
    spec = sys.argv[1] if len(sys.argv) > 1 else ""
    file_path = sys.argv[2] if len(sys.argv) > 2 else ""
    issue = sys.argv[3] if len(sys.argv) > 3 else ""
    output = b""

    if file_path:
        try:
            with open(file_path, "rb") as spec_file:
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
    sys.stdout.buffer.write(output + b"\n")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except BrokenPipeError:
        raise SystemExit(1)
    except Exception as exc:
        print(f"ERROR: Unexpected error: {exc}", file=sys.stderr)
        raise SystemExit(1)
