#!/usr/bin/env bash
set -euo pipefail

# check-converge.sh — Detects whether speckit.converge appended new tasks.
#
# Usage:
#   check-converge.sh snapshot <run_id>   # record the current tasks.md hash
#   check-converge.sh check    <run_id>   # compare; print TASKS_APPENDED or CONVERGED
#
# Spec-Kit's speckit.converge command appends a new "## Phase N: Convergence"
# section to tasks.md when remaining work is found, and leaves tasks.md
# byte-for-byte unchanged when the implementation already satisfies the spec,
# plan, and tasks. This script turns that documented contract into a
# deterministic workflow signal — no parsing of agent prose.
#
# The workflow runs `snapshot` immediately before converge and `check`
# immediately after. `check` prints exactly one of:
#   TASKS_APPENDED — tasks.md changed since the snapshot (run implement again)
#   CONVERGED      — tasks.md unchanged (the feature is done)
#
# Exit codes:
#   0 — Success (check prints TASKS_APPENDED or CONVERGED)
#   1 — Error (missing run_id, feature.json, tasks.md, or missing snapshot)

USAGE="Usage: check-converge.sh {snapshot|check} <run_id>"

MODE="${1:-}"
RUN_ID="${2:-}"

# ---------------------------------------------------------------------------
# Validate arguments
# ---------------------------------------------------------------------------
case "$MODE" in
    snapshot|check) ;;
    *)
        echo "ERROR: first argument must be 'snapshot' or 'check'." >&2
        echo "$USAGE" >&2
        exit 1
        ;;
esac

if [ -z "$RUN_ID" ]; then
    echo "ERROR: run_id is required." >&2
    echo "$USAGE" >&2
    exit 1
fi

RUN_DIR=".specify/workflows/runs/$RUN_ID"
BASELINE_FILE="$RUN_DIR/converge-baseline.txt"

# ---------------------------------------------------------------------------
# Resolve the feature directory and tasks.md from feature.json
# ---------------------------------------------------------------------------
FEATURE_JSON=".specify/feature.json"

if [ ! -f "$FEATURE_JSON" ]; then
    echo "ERROR: $FEATURE_JSON not found." >&2
    exit 1
fi

feature_dir=""
if command -v jq &> /dev/null; then
    feature_dir=$(jq -r '.feature_directory // .dir // .name // .path // empty' "$FEATURE_JSON" 2>/dev/null || true)
else
    feature_dir=$(sed -n 's/.*"feature_directory"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p; s/.*"dir"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p; s/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p; s/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$FEATURE_JSON" | head -n 1 || true)
fi

if [ -z "$feature_dir" ]; then
    echo "ERROR: Could not determine feature directory from $FEATURE_JSON." >&2
    exit 1
fi

# feature_directory is usually "specs/<name>" but tolerate a bare "<name>".
tasks_file=""
if [ -f "$feature_dir/tasks.md" ]; then
    tasks_file="$feature_dir/tasks.md"
elif [ -f "specs/$feature_dir/tasks.md" ]; then
    tasks_file="specs/$feature_dir/tasks.md"
else
    echo "ERROR: tasks.md not found for feature directory '$feature_dir'." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Portable content hash
# ---------------------------------------------------------------------------
hash_file() {
    local file="$1"
    if command -v sha256sum &> /dev/null; then
        sha256sum "$file" | awk '{print $1}'
    elif command -v shasum &> /dev/null; then
        shasum -a 256 "$file" | awk '{print $1}'
    elif command -v md5sum &> /dev/null; then
        md5sum "$file" | awk '{print $1}'
    else
        cksum "$file" | awk '{print $1 "-" $2}'
    fi
}

mkdir -p "$RUN_DIR"

case "$MODE" in
    snapshot)
        hash_file "$tasks_file" > "$BASELINE_FILE"
        echo "OK: recorded baseline for $tasks_file"
        ;;
    check)
        if [ ! -f "$BASELINE_FILE" ]; then
            echo "ERROR: No converge baseline found at $BASELINE_FILE. Run snapshot first." >&2
            exit 1
        fi

        baseline=$(cat "$BASELINE_FILE")
        current=$(hash_file "$tasks_file")

        if [ "$current" = "$baseline" ]; then
            verdict="CONVERGED"
        else
            verdict="TASKS_APPENDED"
        fi

        printf '%s\n' "$verdict" > "$RUN_DIR/converge-state.txt"
        printf '%s\n' "$verdict"
        ;;
esac
