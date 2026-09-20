#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"
SCRIPT_FILE="$PROJECT_DIR/scripts/resolve-bug-context.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASSED=0
FAILED=0

pass() {
    echo "PASS: $1"
    ((PASSED++)) || true
}

fail() {
    echo "FAIL: $1"
    echo "  $2"
    ((FAILED++)) || true
}

echo "=== Test Suite: resolve-bug-context.sh ==="
echo ""

test_root="$TMP_DIR/valid"
mkdir -p "$test_root/.specify/bugs/login-timeout"
printf '# Assessment\n' > "$test_root/.specify/bugs/login-timeout/assessment.md"
output=$(cd "$test_root" && bash "$SCRIPT_FILE")
if [ "$output" = "login-timeout" ]; then
    pass "Resolves assessment slug"
else
    fail "Resolves assessment slug" "Expected login-timeout, got $output"
fi

pointer=$(cd "$test_root" && sed -n 's/.*"feature_directory":"\([^"]*\)".*"type":"\([^"]*\)".*/\1:\2/p' .specify/feature.json)
if [ "$pointer" = ".specify/bugs/login-timeout:bug" ]; then
    pass "Writes bug feature pointer"
else
    fail "Writes bug feature pointer" "Unexpected pointer: $pointer"
fi

explicit_root="$TMP_DIR/explicit"
mkdir -p "$explicit_root/.specify/bugs/explicit-bug"
printf '# Assessment\n' > "$explicit_root/.specify/bugs/explicit-bug/assessment.md"
output=$(cd "$explicit_root" && bash "$SCRIPT_FILE" explicit-bug)
if [ "$output" = "explicit-bug" ]; then
    pass "Accepts explicit slug"
else
    fail "Accepts explicit slug" "Expected explicit-bug, got $output"
fi

missing_root="$TMP_DIR/missing"
mkdir -p "$missing_root"
output=$(cd "$missing_root" && bash "$SCRIPT_FILE" 2>&1) && exit_code=$? || exit_code=$?
if [ "$exit_code" -eq 1 ] && printf '%s' "$output" | grep -q "not found"; then
    pass "Missing bug directory errors"
else
    fail "Missing bug directory errors" "Expected exit 1, got $exit_code: $output"
fi

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

[ "$FAILED" -eq 0 ]
