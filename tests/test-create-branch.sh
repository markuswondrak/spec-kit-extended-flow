#!/usr/bin/env bash
set -euo pipefail

# Test suite for create-branch.sh

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"
SCRIPT_FILE="$PROJECT_DIR/scripts/create-branch.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASSED=0
FAILED=0

run_test() {
    local name="$1"
    local issue="${2:-}"
    local expected_exit="${3:-0}"
    local expected_contains="${4:-}"
    local mock_gh="${5:-}"
    local mock_git="${6:-}"

    local actual_output
    local actual_exit=0

    # Setup PATH with mocks
    local mock_dir="$TMP_DIR/${name// /_}_bin"
    mkdir -p "$mock_dir"

    if [ -n "$mock_gh" ]; then
        cat > "$mock_dir/gh" <<< "$mock_gh"
        chmod +x "$mock_dir/gh"
    fi

    if [ -n "$mock_git" ]; then
        cat > "$mock_dir/git" <<< "$mock_git"
        chmod +x "$mock_dir/git"
    fi

    set +e
    actual_output=$(PATH="$mock_dir:$PATH" bash "$SCRIPT_FILE" "$issue" 2>&1)
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

    echo "PASS: $name"
    ((PASSED++)) || true
}

echo "=== Test Suite: create-branch.sh ==="
echo ""

# Test 1: Missing issue number
run_test "Missing issue number" "" 1 "ERROR: Issue number is required" "" ""

# Test 2: Missing gh CLI — strip /snap/bin from PATH so real gh is not found
set +e
actual_output=$(PATH="/usr/bin:/bin" bash "$SCRIPT_FILE" "42" 2>&1)
actual_exit=$?
set -e
if [ "$actual_exit" -ne 1 ]; then
    echo "FAIL: Missing gh CLI — expected exit 1, got $actual_exit"
    echo "  Output: $actual_output"
    ((FAILED++)) || true
elif ! echo "$actual_output" | grep -q "ERROR: GitHub CLI"; then
    echo "FAIL: Missing gh CLI — expected output to contain 'ERROR: GitHub CLI'"
    echo "  Actual output: $actual_output"
    ((FAILED++)) || true
else
    echo "PASS: Missing gh CLI"
    ((PASSED++)) || true
fi

# Test 3: Successful branch creation
mock_gh='#!/bin/bash
if [[ "$1" == "issue" && "$2" == "view" && "$3" == "42" && "$4" == "--json" && "$5" == "title" && "$6" == "--jq" && "$7" == ".title" ]]; then
    echo "Add user auth"
    exit 0
fi
exit 1
'
mock_git='#!/bin/bash
if [[ "$1" == "show-ref" && "$2" == "--verify" && "$3" == "--quiet" ]]; then
    exit 1  # branch does not exist
fi
if [[ "$1" == "checkout" && "$2" == "-b" ]]; then
    echo "Switched to branch $3"
    exit 0
fi
exit 0
'
run_test "Successful branch creation" "42" 0 "feature/42-add-user-auth" "$mock_gh" "$mock_git"

# Test 4: Branch already exists
mock_git_exists='#!/bin/bash
if [[ "$1" == "show-ref" && "$2" == "--verify" && "$3" == "--quiet" ]]; then
    exit 0  # branch exists
fi
exit 0
'
run_test "Branch already exists" "42" 1 "already exists" "$mock_gh" "$mock_git_exists"

# Test 5: Issue fetch failure
mock_gh_fail='#!/bin/bash
exit 1
'
run_test "Issue fetch failure" "99" 1 "Failed to fetch issue" "$mock_gh_fail" ""

# Test 6: Slugification with special characters
mock_gh_special='#!/bin/bash
if [[ "$1" == "issue" && "$2" == "view" && "$3" == "7" && "$4" == "--json" && "$5" == "title" && "$6" == "--jq" && "$7" == ".title" ]]; then
    echo "Fix API  v2  endpoint!!!"
    exit 0
fi
exit 1
'
mock_git_special='#!/bin/bash
if [[ "$1" == "show-ref" && "$2" == "--verify" && "$3" == "--quiet" ]]; then
    exit 1
fi
if [[ "$1" == "checkout" && "$2" == "-b" ]]; then
    exit 0
fi
exit 0
'
run_test "Slugification special chars" "7" 0 "feature/7-fix-api-v2-endpoint" "$mock_gh_special" "$mock_git_special"

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
