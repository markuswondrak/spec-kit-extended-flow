#!/usr/bin/env bash
set -euo pipefail

# Test suite: verify that agent commands reference spec artifacts
# from the correct downstream location (specs/<feature-dir>/) and
# NOT from the stale .specify/ root.

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"
COMMANDS_DIR="$PROJECT_DIR/commands"

PASSED=0
FAILED=0

# Patterns that must NOT appear in command files
BAD_PATTERNS=(
    ".specify/spec.md"
    ".specify/plan.md"
    ".specify/tasks.md"
)

echo "=== Test Suite: command path correctness ==="
echo ""

for cmd_file in "$COMMANDS_DIR"/*.md; do
    [ -e "$cmd_file" ] || continue
    filename=$(basename "$cmd_file")

    for pattern in "${BAD_PATTERNS[@]}"; do
        if grep -q "$pattern" "$cmd_file"; then
            echo "FAIL: $filename contains stale path '$pattern'"
            ((FAILED++)) || true
        else
            echo "PASS: $filename — no stale path '$pattern'"
            ((PASSED++)) || true
        fi
    done

    # Verify bug-analysis commands reference correct paths
    if [[ "$filename" == *"bug-analyze"* || "$filename" == *"bug-test"* || "$filename" == *"bug-fix"* || "$filename" == *"bug-review"* ]]; then
        if grep -q "specs/" "$cmd_file"; then
            echo "PASS: $filename references specs/ directory"
            ((PASSED++)) || true
        else
            echo "FAIL: $filename should reference specs/ directory"
            ((FAILED++)) || true
        fi
    fi
done

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
