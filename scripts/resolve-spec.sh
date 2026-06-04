#!/usr/bin/env bash
set -euo pipefail

# resolve-spec.sh — Resolves specification inputs for the Spec-Kit Extended Flow workflow.
#
# Usage: resolve-spec.sh <spec> <file> <issue>
#
# Arguments:
#   spec   — Plain-text specification description (optional)
#   file   — Path to a local spec file (optional)
#   issue  — GitHub issue number from the current repository (optional)
#
# At least one argument must be non-empty. Outputs the resolved specification
# content to stdout. If multiple inputs are provided, their contents are
# concatenated in order: file, issue, spec.
#
# Exit codes:
#   0 — Success
#   1 — Error (missing file, gh CLI unavailable, issue fetch failed,
#       or no inputs provided)

SPEC="${1:-}"
FILE="${2:-}"
ISSUE="${3:-}"
OUTPUT=""

# ---------------------------------------------------------------------------
# Branch 1: File input
# ---------------------------------------------------------------------------
resolve_file() {
    local file_path="$1"

    if [ ! -f "$file_path" ]; then
        echo "ERROR: Spec file not found: $file_path" >&2
        return 1
    fi

    cat "$file_path"
}

if [ -n "$FILE" ]; then
    FILE_CONTENT=$(resolve_file "$FILE") || exit 1
    OUTPUT="${OUTPUT}${FILE_CONTENT}"$'\n'
fi

# ---------------------------------------------------------------------------
# Branch 2: Issue input
# ---------------------------------------------------------------------------
resolve_issue() {
    local issue_num="$1"

    if ! command -v gh &> /dev/null; then
        echo "ERROR: GitHub CLI (gh) is required to fetch issues. Install and authenticate with 'gh auth login'." >&2
        return 1
    fi

    local issue_content
    issue_content=$(gh issue view "$issue_num" --json title,body --jq '"# " + .title + "\n\n" + .body' 2>&1) || {
        echo "ERROR: Failed to fetch issue #$issue_num. Ensure the issue exists and gh is authenticated." >&2
        return 1
    }

    echo "$issue_content"
}

if [ -n "$ISSUE" ]; then
    ISSUE_CONTENT=$(resolve_issue "$ISSUE") || exit 1
    OUTPUT="${OUTPUT}${ISSUE_CONTENT}"$'\n'
fi

# ---------------------------------------------------------------------------
# Branch 3: Plain text spec
# ---------------------------------------------------------------------------
if [ -n "$SPEC" ]; then
    OUTPUT="${OUTPUT}${SPEC}"$'\n'
fi

# ---------------------------------------------------------------------------
# Validation: at least one input must be provided
# ---------------------------------------------------------------------------
if [ -z "$OUTPUT" ]; then
    echo "ERROR: No specification provided. Set at least one of: --input spec, --input file, or --input issue." >&2
    exit 1
fi

echo "$OUTPUT"
