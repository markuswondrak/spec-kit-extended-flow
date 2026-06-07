#!/usr/bin/env bash
set -euo pipefail

# extract-verdict.sh — Extracts the QA review verdict from the review findings filename.
#
# Usage: extract-verdict.sh <run_id>
#
# The review command writes review findings as review-findings-{N}-{VERDICT}.md
# (e.g. review-findings-1-FAIL.md, review-findings-2-PASS.md).
# This script finds the file with the highest iteration number, extracts
# the verdict from the filename, and writes it to stdout.
#
# Exit codes:
#   0 — Success
#   1 — Error (missing feature.json, no review findings, or invalid verdict)

RUN_ID="${1:-}"

# ---------------------------------------------------------------------------
# Resolve feature directory from feature.json
# ---------------------------------------------------------------------------
FEATURE_JSON=".specify/feature.json"

if [ ! -f "$FEATURE_JSON" ]; then
    echo "ERROR: $FEATURE_JSON not found." >&2
    exit 1
fi

# Try jq first, fall back to sed
feature_dir=""
if command -v jq &> /dev/null; then
    feature_dir=$(jq -r '.feature_directory // .dir // .name // .path' "$FEATURE_JSON" 2>/dev/null || true)
else
    feature_dir=$(sed -n 's/.*"feature_directory"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p; s/.*"dir"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p; s/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p; s/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$FEATURE_JSON" | head -n 1 || true)
fi

if [ -z "$feature_dir" ]; then
    echo "ERROR: Could not determine feature directory from $FEATURE_JSON" >&2
    exit 1
fi

# Strip leading specs/ if present
feature_dir=$(echo "$feature_dir" | sed 's|^specs/||')

# ---------------------------------------------------------------------------
# Find the review findings file with the highest iteration number
# ---------------------------------------------------------------------------
review_dir="specs/$feature_dir"

if [ ! -d "$review_dir" ]; then
    echo "ERROR: Feature directory not found: $review_dir" >&2
    exit 1
fi

# Find all review-findings-N-VERDICT.md files and sort by iteration number
verdict_file=""
for f in "$review_dir"/review-findings-*-*.md; do
    [ -e "$f" ] || continue
    verdict_file="$f"
done

if [ -z "$verdict_file" ]; then
    echo "ERROR: No review-findings-*-*.md found in $review_dir" >&2
    exit 1
fi

# Sort by iteration number (3rd field, numeric) and take the last one
verdict_file=$(ls -1 "$review_dir"/review-findings-*-*.md 2>/dev/null | sort -t- -k3 -n | tail -n 1)

if [ -z "$verdict_file" ]; then
    echo "ERROR: Could not determine latest review findings file" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Extract verdict from filename: review-findings-2-FAIL.md → FAIL
# ---------------------------------------------------------------------------
filename=$(basename "$verdict_file")
verdict=$(echo "$filename" | sed 's/^review-findings-[0-9]*-//' | sed 's/\.md$//')

case "$verdict" in
    PASS|FAIL)
        printf '%s\n' "$verdict"
        ;;
    *)
        echo "ERROR: Unexpected verdict '$verdict' in filename: $filename" >&2
        exit 1
        ;;
esac

# ---------------------------------------------------------------------------
# Write verdict to run artifact if run_id is provided
# ---------------------------------------------------------------------------
if [ -n "$RUN_ID" ]; then
    run_dir=".specify/workflows/runs/$RUN_ID"
    mkdir -p "$run_dir"
    printf '%s\n' "$verdict" > "$run_dir/review-verdict.txt"
fi
