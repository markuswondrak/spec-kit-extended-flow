#!/usr/bin/env bash
set -euo pipefail

# Test suite for extract-verdict.sh
# Tests filename-based verdict extraction with iteration numbers.

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"
SCRIPT_FILE="$PROJECT_DIR/scripts/extract-verdict.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASSED=0
FAILED=0

# Helper: create a test project structure
create_test_project() {
    local test_root="$1"
    local feature_dir="${2:-001-test-feature}"
    mkdir -p "$test_root/specs/$feature_dir"
    mkdir -p "$test_root/.specify/workflows/runs/test-run"
    cat > "$test_root/.specify/feature.json" << EOF
{"feature_directory": "specs/$feature_dir"}
EOF
}

echo "=== Test Suite: extract-verdict.sh ==="
echo ""

# Test 1: PASS verdict file detected
test_root="$TMP_DIR/test_pass"
create_test_project "$test_root"
touch "$test_root/specs/001-test-feature/review-findings-1-PASS.md"
output=$(cd "$test_root" && bash "$SCRIPT_FILE" "test-run" 2>&1) && exit_code=$? || exit_code=$?
if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "PASS"; then
    echo "PASS: PASS verdict detected"
    ((PASSED++)) || true
else
    echo "FAIL: PASS verdict — exit=$exit_code output=$output"
    ((FAILED++)) || true
fi

# Test 2: FAIL verdict file detected
test_root="$TMP_DIR/test_fail"
create_test_project "$test_root"
touch "$test_root/specs/001-test-feature/review-findings-1-FAIL.md"
output=$(cd "$test_root" && bash "$SCRIPT_FILE" "test-run" 2>&1) && exit_code=$? || exit_code=$?
if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "FAIL"; then
    echo "PASS: FAIL verdict detected"
    ((PASSED++)) || true
else
    echo "FAIL: FAIL verdict — exit=$exit_code output=$output"
    ((FAILED++)) || true
fi

# Test 3: Multiple iterations - picks highest number
test_root="$TMP_DIR/test_multiple"
create_test_project "$test_root"
touch "$test_root/specs/001-test-feature/review-findings-1-FAIL.md"
touch "$test_root/specs/001-test-feature/review-findings-2-PASS.md"
output=$(cd "$test_root" && bash "$SCRIPT_FILE" "test-run" 2>&1) && exit_code=$? || exit_code=$?
if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "PASS"; then
    echo "PASS: Multiple iterations picks highest"
    ((PASSED++)) || true
else
    echo "FAIL: Multiple iterations — exit=$exit_code output=$output"
    ((FAILED++)) || true
fi

# Test 4: Missing feature.json
test_root="$TMP_DIR/test_missing_json"
mkdir -p "$test_root/specs/001-test-feature"
output=$(cd "$test_root" && bash "$SCRIPT_FILE" 2>&1) && exit_code=$? || exit_code=$?
if [ "$exit_code" -eq 1 ]; then
    echo "PASS: Missing feature.json errors"
    ((PASSED++)) || true
else
    echo "FAIL: Missing feature.json — expected exit 1, got $exit_code"
    ((FAILED++)) || true
fi

# Test 5: Missing verdict file
test_root="$TMP_DIR/test_missing_verdict"
create_test_project "$test_root"
output=$(cd "$test_root" && bash "$SCRIPT_FILE" 2>&1) && exit_code=$? || exit_code=$?
if [ "$exit_code" -eq 1 ]; then
    echo "PASS: Missing verdict file errors"
    ((PASSED++)) || true
else
    echo "FAIL: Missing verdict file — expected exit 1, got $exit_code"
    ((FAILED++)) || true
fi

# Test 6: Invalid verdict in filename
test_root="$TMP_DIR/test_invalid"
create_test_project "$test_root"
touch "$test_root/specs/001-test-feature/review-findings-1-MAYBE.md"
output=$(cd "$test_root" && bash "$SCRIPT_FILE" 2>&1) && exit_code=$? || exit_code=$?
if [ "$exit_code" -eq 1 ]; then
    echo "PASS: Invalid verdict errors"
    ((PASSED++)) || true
else
    echo "FAIL: Invalid verdict — expected exit 1, got $exit_code"
    ((FAILED++)) || true
fi

# Test 7: Run artifact written when run_id provided
test_root="$TMP_DIR/test_artifact"
create_test_project "$test_root"
touch "$test_root/specs/001-test-feature/review-findings-1-PASS.md"
cd "$test_root" && bash "$SCRIPT_FILE" "test-run" > /dev/null 2>&1
if [ -f "$test_root/.specify/workflows/runs/test-run/review-verdict.txt" ]; then
    artifact_content=$(cat "$test_root/.specify/workflows/runs/test-run/review-verdict.txt")
    if [ "$artifact_content" = "PASS" ]; then
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
