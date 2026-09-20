#!/usr/bin/env bash
set -euo pipefail

# extract-triage.sh — Extracts the triage verdict from the triage filename.
#
# Usage: extract-triage.sh <run_id>
#
# The triage command writes .specify/workflows/runs/<run_id>/triage-{VERDICT}.md
# (e.g. triage-feature.md, triage-bugfix.md, triage-quick.md).
# This script finds the triage file, extracts the verdict from the filename,
# and writes it to stdout.
#
# Exit codes:
#   0 — Success
#   1 — Error (missing run_id, run directory not found, no triage file,
#       or invalid verdict)

RUN_ID="${1:-}"

# ---------------------------------------------------------------------------
# Validate run_id
# ---------------------------------------------------------------------------
if [ -z "$RUN_ID" ]; then
    echo "ERROR: run_id is required." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Resolve run directory
# ---------------------------------------------------------------------------
RUN_DIR=".specify/workflows/runs/$RUN_ID"

if [ ! -d "$RUN_DIR" ]; then
    echo "ERROR: Run directory not found: $RUN_DIR" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Find the triage file
# ---------------------------------------------------------------------------
triage_file=""
for f in "$RUN_DIR"/triage-*.md; do
    [ -e "$f" ] || continue
    triage_file="$f"
    break
done

if [ -z "$triage_file" ]; then
    echo "ERROR: No triage-*.md found in $RUN_DIR" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Extract verdict from filename: triage-feature.md → feature
# ---------------------------------------------------------------------------
filename=$(basename "$triage_file")
verdict=$(echo "$filename" | sed 's/^triage-//' | sed 's/\.md$//')

case "$verdict" in
    feature|bugfix|quick)
        printf '%s\n' "$verdict"
        ;;
    *)
        echo "ERROR: Unexpected triage verdict '$verdict' in filename: $filename" >&2
        exit 1
        ;;
esac

# ---------------------------------------------------------------------------
# Write verdict to run artifact
# ---------------------------------------------------------------------------
printf '%s\n' "$verdict" > "$RUN_DIR/triage-verdict.txt"
