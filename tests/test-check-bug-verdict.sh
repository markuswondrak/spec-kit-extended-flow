#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"
SCRIPT_FILE="$PROJECT_DIR/scripts/check-bug-verdict.sh"
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

run_result_test() {
    local result="$1"
    local expected_exit="$2"
    local test_root="$TMP_DIR/$result"
    mkdir -p "$test_root/.specify/bugs/example"
    printf '{"feature_directory":".specify/bugs/example","type":"bug"}\n' > "$test_root/.specify/feature.json"
    printf -- '- **Result**: %s\n' "$result" > "$test_root/.specify/bugs/example/test.md"

    output=$(cd "$test_root" && bash "$SCRIPT_FILE" 2>&1) && exit_code=$? || exit_code=$?
    if [ "$exit_code" -eq "$expected_exit" ]; then
        pass "$result result returns exit $expected_exit"
    else
        fail "$result result returns exit $expected_exit" "Expected $expected_exit, got $exit_code: $output"
    fi
}

echo "=== Test Suite: check-bug-verdict.sh ==="
echo ""

run_result_test verified 0
run_result_test partial 1
run_result_test failed 1

missing_root="$TMP_DIR/missing"
mkdir -p "$missing_root/.specify"
printf '{"feature_directory":".specify/bugs/example","type":"bug"}\n' > "$missing_root/.specify/feature.json"
output=$(cd "$missing_root" && bash "$SCRIPT_FILE" 2>&1) && exit_code=$? || exit_code=$?
if [ "$exit_code" -eq 1 ] && printf '%s' "$output" | grep -q "not found"; then
    pass "Missing test report errors"
else
    fail "Missing test report errors" "Expected exit 1, got $exit_code: $output"
fi

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

[ "$FAILED" -eq 0 ]
