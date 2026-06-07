#!/usr/bin/env bash
set -euo pipefail

# verify-spec.sh — Verifies that a specification was successfully created
#
# Usage: verify-spec.sh
#
# Checks:
#   1. .specify/feature.json exists and is readable
#   2. The feature_directory referenced in feature.json exists
#   3. spec.md exists inside the feature directory
#
# Exit codes:
#   0 — Spec verification passed
#   1 — Spec verification failed (missing feature.json, directory, or spec.md)

FEATURE_JSON=".specify/feature.json"

# ---------------------------------------------------------------------------
# Check 1: feature.json exists
# ---------------------------------------------------------------------------
if [ ! -f "$FEATURE_JSON" ]; then
    echo "ERROR: $FEATURE_JSON not found. The specify step did not create a feature directory." >&2
    echo "       This usually happens when the before_specify hook (speckit.git.feature)" >&2
    echo "       could not execute. If you are using an integration that does not support" >&2
    echo "       EXECUTE_COMMAND (e.g., opencode), disable the git extension before running" >&2
    echo "       this workflow: specify extension disable git" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Check 2: feature.json is valid JSON with feature_directory
# ---------------------------------------------------------------------------
feature_dir=""
if command -v jq &> /dev/null; then
    feature_dir=$(jq -r '.feature_directory // .dir // .name // .path // empty' "$FEATURE_JSON" 2>/dev/null || true)
else
    # Fallback: sed-based extraction for environments without jq
    feature_dir=$(sed -n 's/.*"feature_directory"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p; s/.*"dir"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p; s/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p; s/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$FEATURE_JSON" | head -n 1 || true)
fi

if [ -z "$feature_dir" ]; then
    echo "ERROR: $FEATURE_JSON does not contain a valid feature_directory." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Check 3: Feature directory exists
# ---------------------------------------------------------------------------
if [ ! -d "$feature_dir" ]; then
    echo "ERROR: Feature directory '$feature_dir' does not exist." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Check 4: spec.md exists in the feature directory
# ---------------------------------------------------------------------------
spec_file="$feature_dir/spec.md"
if [ ! -f "$spec_file" ]; then
    echo "ERROR: Spec file '$spec_file' not found. The specify step did not write a specification." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Success
# ---------------------------------------------------------------------------
echo "Spec verification passed: $spec_file"
exit 0
