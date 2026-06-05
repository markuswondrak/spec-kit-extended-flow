#!/usr/bin/env bash
set -euo pipefail

# cleanup-feature.sh — Removes temporary files from the current implemented feature
#
# Usage: cleanup-feature.sh <run_id>
#
# Reads .specify/feature.json to determine the current feature directory,
# then removes:
#   - specs/<feature-dir>/  (entire feature directory, including review-findings.md)
#   - .specify/feature.json
#   - .specify/workflows/runs/<run_id>/
#
# Installed config (presets, templates, scripts, extensions, init-options,
# memory, workflow definitions) is never touched.
#
# Exit codes:
#   0 — Success (even if some paths were already absent)
#   1 — Error

RUN_ID="${1:-}"

if [ -z "$RUN_ID" ]; then
    echo "ERROR: Run ID is required." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Resolve feature directory from .specify/feature.json
# ---------------------------------------------------------------------------
feature_dir=""
if [ -f ".specify/feature.json" ]; then
    # Try common JSON field names: dir, name, path
    feature_dir=$(sed -n 's/.*"dir"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .specify/feature.json | head -n 1 || true)
    if [ -z "$feature_dir" ]; then
        feature_dir=$(sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .specify/feature.json | head -n 1 || true)
    fi
    if [ -z "$feature_dir" ]; then
        feature_dir=$(sed -n 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .specify/feature.json | head -n 1 || true)
    fi
fi

if [ -n "$feature_dir" ]; then
    # Strip leading specs/ if the JSON value already includes it
    feature_dir=$(echo "$feature_dir" | sed 's|^specs/||')

    feature_path="specs/$feature_dir"
    if [ -d "$feature_path" ]; then
        echo "Removing feature directory: $feature_path"
        rm -rf "$feature_path"
    else
        echo "Feature directory not found: $feature_path"
    fi
else
    echo "Warning: Could not determine feature directory from .specify/feature.json"
fi

# ---------------------------------------------------------------------------
# Remove feature pointer
# ---------------------------------------------------------------------------
if [ -f ".specify/feature.json" ]; then
    echo "Removing .specify/feature.json"
    rm -f ".specify/feature.json"
fi

# ---------------------------------------------------------------------------
# Remove workflow run state
# ---------------------------------------------------------------------------
run_path=".specify/workflows/runs/$RUN_ID"
if [ -d "$run_path" ]; then
    echo "Removing workflow run state: $run_path"
    rm -rf "$run_path"
else
    echo "Workflow run state not found: $run_path"
fi

echo "Cleanup complete."
