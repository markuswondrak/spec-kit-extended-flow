#!/usr/bin/env bash
set -euo pipefail

# Test suite: verify that every script referenced in AGENTS.md exists and is executable.

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"
SCRIPTS_DIR="$PROJECT_DIR/scripts"
AGENTS_MD="$PROJECT_DIR/AGENTS.md"

PASSED=0
FAILED=0

echo "=== Test Suite: script existence and executability ==="
echo ""

# Extract script filenames from the AGENTS.md Scripts table.
# Expected format: | `scripts/name.sh` | Description |
script_names=()
while IFS= read -r line; do
    # Match backtick-quoted script references like `scripts/resolve-spec.sh`
    if [[ "$line" =~ \`scripts/([a-zA-Z0-9_-]+\.sh)\` ]]; then
        script_names+=("${BASH_REMATCH[1]}")
    fi
done < "$AGENTS_MD"

if [ ${#script_names[@]} -eq 0 ]; then
    echo "FAIL: No scripts found in AGENTS.md table"
    exit 1
fi

for name in "${script_names[@]}"; do
    script_path="$SCRIPTS_DIR/$name"

    if [ ! -f "$script_path" ]; then
        echo "FAIL: $name — file does not exist"
        ((FAILED++)) || true
        continue
    fi

    if [ ! -x "$script_path" ]; then
        echo "FAIL: $name — file is not executable"
        ((FAILED++)) || true
        continue
    fi

    echo "PASS: $name — exists and is executable"
    ((PASSED++)) || true
done

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
