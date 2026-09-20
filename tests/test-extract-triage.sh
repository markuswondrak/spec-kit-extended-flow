#!/usr/bin/env bash
set -euo pipefail

# Test suite for extract-triage.sh
# Tests filename-based triage verdict extraction from the run directory.

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"
SCRIPT_FILE="$PROJECT_DIR/scripts/extract-triage.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASSED=0
FAILED=0

# Helper: create a test run structure
create_test_run() {
    local test_root="$1"
    mkdir -p "$test_root/.specify/workflows/runs/test-run"
}

echo "=== Test Suite: extract-triage.sh ==="
echo ""

# Test 1: feature verdict
for verdict in feature bugfix quick; do
    test_root="$TMP_DIR/test_${verdict}"
    create_test_run "$test_root"
    touch "$test_root/.specify/workflows/runs/test-run/triage-${verdict}.md"
    output=$(cd "$test_root" && bash "$SCRIPT_FILE" "test-run" 2>&1) && exit_code=$? || exit_code=$?
    if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "^${verdict}$"; then
        echo "PASS: ${verdict} verdict detected"
        ((PASSED++)) || true
    else
        echo "FAIL: ${verdict} verdict — exit=$exit_code output=$output"
        ((FAILED++)) || true
    fi
done

# Test 2: Missing run_id
test_root="$TMP_DIR/test_missing_run_id"
create_test_run "$test_root"
touch "$test_root/.specify/workflows/runs/test-run/triage-feature.md"
output=$(cd "$test_root" && bash "$SCRIPT_FILE" 2>&1) && exit_code=$? || exit_code=$?
if [ "$exit_code" -eq 1 ] && echo "$output" | grep -q "run_id is required"; then
    echo "PASS: Missing run_id errors"
    ((PASSED++)) || true
else
    echo "FAIL: Missing run_id — expected exit 1, got $exit_code"
    ((FAILED++)) || true
fi

# Test 3: Missing run directory
test_root="$TMP_DIR/test_missing_run_dir"
mkdir -p "$test_root/.specify"
output=$(cd "$test_root" && bash "$SCRIPT_FILE" "test-run" 2>&1) && exit_code=$? || exit_code=$?
if [ "$exit_code" -eq 1 ] && echo "$output" | grep -q "Run directory not found"; then
    echo "PASS: Missing run directory errors"
    ((PASSED++)) || true
else
    echo "FAIL: Missing run directory — expected exit 1, got $exit_code"
    ((FAILED++)) || true
fi

# Test 4: Missing triage file
test_root="$TMP_DIR/test_missing_file"
create_test_run "$test_root"
output=$(cd "$test_root" && bash "$SCRIPT_FILE" "test-run" 2>&1) && exit_code=$? || exit_code=$?
if [ "$exit_code" -eq 1 ] && echo "$output" | grep -q "No triage-\*.md found"; then
    echo "PASS: Missing triage file errors"
    ((PASSED++)) || true
else
    echo "FAIL: Missing triage file — expected exit 1, got $exit_code"
    ((FAILED++)) || true
fi

# Test 5: Invalid verdict in filename
test_root="$TMP_DIR/test_invalid"
create_test_run "$test_root"
touch "$test_root/.specify/workflows/runs/test-run/triage-unknown.md"
output=$(cd "$test_root" && bash "$SCRIPT_FILE" "test-run" 2>&1) && exit_code=$? || exit_code=$?
if [ "$exit_code" -eq 1 ] && echo "$output" | grep -q "Unexpected triage verdict"; then
    echo "PASS: Invalid verdict errors"
    ((PASSED++)) || true
else
    echo "FAIL: Invalid verdict — expected exit 1, got $exit_code"
    ((FAILED++)) || true
fi

# Test 6: Run artifact written
test_root="$TMP_DIR/test_artifact"
create_test_run "$test_root"
touch "$test_root/.specify/workflows/runs/test-run/triage-bugfix.md"
cd "$test_root" && bash "$SCRIPT_FILE" "test-run" > /dev/null 2>&1
if [ -f "$test_root/.specify/workflows/runs/test-run/triage-verdict.txt" ]; then
    artifact_content=$(cat "$test_root/.specify/workflows/runs/test-run/triage-verdict.txt")
    if [ "$artifact_content" = "bugfix" ]; then
        echo "PASS: Run artifact written"
        ((PASSED++)) || true
    else
        echo "FAIL: Run artifact has wrong content: $artifact_content"
        ((FAILED++)) || true
    fi
else
    echo "FAIL: Run artifact not written"
    ((FAILED++)) || true
fi

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
