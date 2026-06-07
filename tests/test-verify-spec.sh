#!/usr/bin/env bash
set -euo pipefail

# Test suite for verify-spec.sh
# Validates that the script correctly detects missing or present specs

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"
SCRIPT_FILE="$PROJECT_DIR/scripts/verify-spec.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASSED=0
FAILED=0

# Helper: run a test case
run_test() {
    local name="$1"
    local expected_exit="${2:-0}"
    local expected_contains="${3:-}"

    local actual_output
    local actual_exit=0
    set +e
    actual_output=$(cd "$TMP_DIR" && bash "$SCRIPT_FILE" 2>&1)
    actual_exit=$?
    set -e

    # Check exit code
    if [ "$actual_exit" -ne "$expected_exit" ]; then
        echo "FAIL: $name — expected exit $expected_exit, got $actual_exit"
        echo "  Output: $actual_output"
        ((FAILED++)) || true
        return
    fi

    # Check expected content
    if [ -n "$expected_contains" ]; then
        if ! echo "$actual_output" | grep -q "$expected_contains"; then
            echo "FAIL: $name — expected output to contain '$expected_contains'"
            echo "  Actual output: $actual_output"
            ((FAILED++)) || true
            return
        fi
    fi

    echo "PASS: $name"
    ((PASSED++)) || true
}

echo "=== Test Suite: verify-spec.sh ==="
echo ""

# Test 1: No feature.json at all
run_test "Missing feature.json" 1 "feature.json not found"

# Test 2: feature.json exists but no feature_directory
mkdir -p "$TMP_DIR/.specify"
echo '{}' > "$TMP_DIR/.specify/feature.json"
run_test "Empty feature.json" 1 "does not contain a valid feature_directory"

# Test 3: feature_directory points to non-existent directory
echo '{"feature_directory": "specs/001-test"}' > "$TMP_DIR/.specify/feature.json"
run_test "Missing feature directory" 1 "Feature directory 'specs/001-test' does not exist"

# Test 4: Feature directory exists but no spec.md
mkdir -p "$TMP_DIR/specs/001-test"
echo '{"feature_directory": "specs/001-test"}' > "$TMP_DIR/.specify/feature.json"
run_test "Missing spec.md" 1 "Spec file 'specs/001-test/spec.md' not found"

# Test 5: Everything present — success
echo "# Test Spec" > "$TMP_DIR/specs/001-test/spec.md"
run_test "Valid spec exists" 0 "Spec verification passed"

# Test 6: Alternative JSON keys (dir, name, path)
mkdir -p "$TMP_DIR/specs/002-alt"
echo "# Alt Spec" > "$TMP_DIR/specs/002-alt/spec.md"
echo '{"dir": "specs/002-alt"}' > "$TMP_DIR/.specify/feature.json"
run_test "Alternative 'dir' key" 0 "Spec verification passed"

echo '{"name": "specs/002-alt"}' > "$TMP_DIR/.specify/feature.json"
run_test "Alternative 'name' key" 0 "Spec verification passed"

echo '{"path": "specs/002-alt"}' > "$TMP_DIR/.specify/feature.json"
run_test "Alternative 'path' key" 0 "Spec verification passed"

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
