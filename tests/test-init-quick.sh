#!/usr/bin/env bash
set -euo pipefail

# Test suite for init-quick.sh

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"
SCRIPT_FILE="$PROJECT_DIR/scripts/init-quick.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASSED=0
FAILED=0

run_test() {
    local name="$1"
    local issue="${2:-}"
    local spec_text="${3:-}"
    local expected_exit="${4:-0}"
    local expected_contains="${5:-}"
    local expected_not_contains="${6:-}"
    local mock_gh="${7:-}"

    local actual_output
    local actual_exit=0

    # Setup a clean working directory for each test
    local work_dir="$TMP_DIR/${name// /_}"
    mkdir -p "$work_dir"

    # Setup PATH with mocks
    local mock_dir="$TMP_DIR/${name// /_}_bin"
    mkdir -p "$mock_dir"

    if [ -n "$mock_gh" ]; then
        cat > "$mock_dir/gh" <<< "$mock_gh"
        chmod +x "$mock_dir/gh"
    fi

    set +e
    actual_output=$(cd "$work_dir" && PATH="$mock_dir:$PATH" bash "$SCRIPT_FILE" "$issue" "$spec_text" 2>&1)
    actual_exit=$?
    set -e

    if [ "$actual_exit" -ne "$expected_exit" ]; then
        echo "FAIL: $name — expected exit $expected_exit, got $actual_exit"
        echo "  Output: $actual_output"
        ((FAILED++)) || true
        return
    fi

    if [ -n "$expected_contains" ]; then
        if ! echo "$actual_output" | grep -q "$expected_contains"; then
            echo "FAIL: $name — expected output to contain '$expected_contains'"
            echo "  Actual output: $actual_output"
            ((FAILED++)) || true
            return
        fi
    fi

    if [ -n "$expected_not_contains" ]; then
        if echo "$actual_output" | grep -q "$expected_not_contains"; then
            echo "FAIL: $name — expected output NOT to contain '$expected_not_contains'"
            echo "  Actual output: $actual_output"
            ((FAILED++)) || true
            return
        fi
    fi

    echo "PASS: $name"
    ((PASSED++)) || true
}

# Helper: verify feature.json was created with correct content
verify_feature_json() {
    local name="$1"
    local work_dir="$TMP_DIR/${name// /_}"
    local expected_dir="$2"
    local expected_type="${3:-quick}"

    local feature_json="$work_dir/.specify/feature.json"

    if [ ! -f "$feature_json" ]; then
        echo "FAIL: $name — feature.json not created"
        ((FAILED++)) || true
        return
    fi

    local actual_dir
    actual_dir=$(grep -o '"feature_directory"[[:space:]]*:[[:space:]]*"[^"]*"' "$feature_json" | sed 's/.*"\([^"]*\)"$/\1/')

    if [ "$actual_dir" != "$expected_dir" ]; then
        echo "FAIL: $name — feature_directory expected '$expected_dir', got '$actual_dir'"
        ((FAILED++)) || true
        return
    fi

    if ! grep -q "\"type\": \"$expected_type\"" "$feature_json"; then
        echo "FAIL: $name — feature.json missing type: $expected_type"
        ((FAILED++)) || true
        return
    fi

    echo "PASS: $name — feature.json correct"
    ((PASSED++)) || true
}

# Helper: verify directory was created
verify_directory() {
    local name="$1"
    local work_dir="$TMP_DIR/${name// /_}"
    local expected_dir="$2"

    if [ ! -d "$work_dir/$expected_dir" ]; then
        echo "FAIL: $name — directory $expected_dir not created"
        ((FAILED++)) || true
        return
    fi

    echo "PASS: $name — directory created"
    ((PASSED++)) || true
}

echo "=== Test Suite: init-quick.sh ==="
echo ""

# Test 1: No inputs — should fail
run_test "No inputs" "" "" 1 "ERROR: At least one" "" ""

# Test 2: Issue-based directory creation
mock_gh='#!/bin/bash
if [[ "$1" == "issue" && "$2" == "view" && "$3" == "42" && "$4" == "--json" && "$5" == "title" && "$6" == "--jq" && "$7" == ".title" ]]; then
    echo "Change login label"
    exit 0
fi
exit 1
'
run_test "Issue-based directory" "42" "" 0 "specs/42-quick-change-login-label" "" "$mock_gh"
verify_feature_json "Issue-based directory" "specs/42-quick-change-login-label"
verify_directory "Issue-based directory" "specs/42-quick-change-login-label"

# Test 3: Spec-text-based directory (no issue)
run_test "Spec-text directory" "" "Add validation message" 0 "specs/quick-add-validation-message" "" ""
verify_feature_json "Spec-text directory" "specs/quick-add-validation-message"
verify_directory "Spec-text directory" "specs/quick-add-validation-message"

# Test 4: Spec text truncation (long text)
run_test "Spec text truncation" "" "This is a very long specification text that should be truncated to thirty characters" 0 "specs/quick-this-is-a-very-long-specificat" "" ""
verify_feature_json "Spec text truncation" "specs/quick-this-is-a-very-long-specificat"

# Test 5: Special characters in issue title
mock_gh_special='#!/bin/bash
if [[ "$1" == "issue" && "$2" == "view" && "$3" == "7" && "$4" == "--json" && "$5" == "title" && "$6" == "--jq" && "$7" == ".title" ]]; then
    echo "Fix API  v2  endpoint!!!"
    exit 0
fi
exit 1
'
run_test "Special chars in title" "7" "" 0 "specs/7-quick-fix-api-v2-endpoint" "" "$mock_gh_special"
verify_feature_json "Special chars in title" "specs/7-quick-fix-api-v2-endpoint"

# Test 6: Issue fetch failure
mock_gh_fail='#!/bin/bash
exit 1
'
run_test "Issue fetch failure" "99" "" 1 "Failed to fetch issue" "" "$mock_gh_fail"

# Test 7: Missing gh CLI when issue provided
set +e
work_dir="$TMP_DIR/test_missing_gh"
mkdir -p "$work_dir"
actual_output=$(cd "$work_dir" && PATH="/usr/bin:/bin" bash "$SCRIPT_FILE" "42" "" 2>&1)
actual_exit=$?
set -e
if [ "$actual_exit" -ne 1 ]; then
    echo "FAIL: Missing gh CLI — expected exit 1, got $actual_exit"
    echo "  Output: $actual_output"
    ((FAILED++)) || true
elif ! echo "$actual_output" | grep -q "ERROR: GitHub CLI"; then
    echo "FAIL: Missing gh CLI — expected 'ERROR: GitHub CLI'"
    echo "  Output: $actual_output"
    ((FAILED++)) || true
else
    echo "PASS: Missing gh CLI"
    ((PASSED++)) || true
fi

# Test 8: Existing directory — should fail
work_dir="$TMP_DIR/test_existing_dir"
mkdir -p "$work_dir/specs/quick-existing"
set +e
actual_output=$(cd "$work_dir" && bash "$SCRIPT_FILE" "" "existing" 2>&1)
actual_exit=$?
set -e
if [ "$actual_exit" -ne 1 ]; then
    echo "FAIL: Existing directory — expected exit 1, got $actual_exit"
    echo "  Output: $actual_output"
    ((FAILED++)) || true
elif ! echo "$actual_output" | grep -q "already exists"; then
    echo "FAIL: Existing directory — expected 'already exists'"
    echo "  Output: $actual_output"
    ((FAILED++)) || true
else
    echo "PASS: Existing directory"
    ((PASSED++)) || true
fi

# Test 9: Empty spec text falls back to default slug
run_test "Empty spec fallback slug" "" "   " 0 "specs/quick-change" "" ""

# Test 10: feature.json type is "quick"
work_dir="$TMP_DIR/test_type_quick"
mkdir -p "$work_dir"
set +e
cd "$work_dir" && bash "$SCRIPT_FILE" "" "test change" > /dev/null 2>&1
set -e
if grep -q '"type": "quick"' "$work_dir/.specify/feature.json"; then
    echo "PASS: feature.json type is quick"
    ((PASSED++)) || true
else
    echo "FAIL: feature.json type is not quick"
    ((FAILED++)) || true
fi

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
