#!/usr/bin/env bash
set -euo pipefail

# check-bug-verdict.sh — Fail the workflow unless speckit.bug.test verified the fix.

FEATURE_JSON=".specify/feature.json"

if [ ! -f "$FEATURE_JSON" ]; then
    echo "ERROR: $FEATURE_JSON not found." >&2
    exit 1
fi

bug_dir=""
if command -v jq >/dev/null 2>&1; then
    bug_dir=$(jq -r '.feature_directory // empty' "$FEATURE_JSON" 2>/dev/null || true)
else
    bug_dir=$(sed -n 's/.*"feature_directory"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$FEATURE_JSON" | head -n 1)
fi

if [ -z "$bug_dir" ]; then
    echo "ERROR: Could not determine bug directory from $FEATURE_JSON." >&2
    exit 1
fi

test_file="$bug_dir/test.md"
if [ ! -f "$test_file" ]; then
    echo "ERROR: Bug verification report not found: $test_file" >&2
    exit 1
fi

result=$(sed -n 's/^[[:space:]]*-[[:space:]]*\*\*Result\*\*:[[:space:]]*//p' "$test_file" | head -n 1)
case "$result" in
    verified)
        printf 'verified\n'
        ;;
    partial|failed)
        printf '%s\n' "$result" >&2
        echo "ERROR: Bug verification result is '$result'." >&2
        exit 1
        ;;
    *)
        echo "ERROR: Missing or invalid Result field in $test_file." >&2
        exit 1
        ;;
esac
