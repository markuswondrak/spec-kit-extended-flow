#!/usr/bin/env bash
set -euo pipefail

# Test suite for create-branch.sh prefix parameter

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
    local prefix="${3:-}"
    local expected_exit="${4:-0}"
    local expected_contains="${5:-}"
    local mock_gh="${6:-}"
    local mock_git="${7:-}"

    local actual_output
    local actual_exit=0

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
    actual_output=$(PATH="$mock_dir:$PATH" bash "$SCRIPT_FILE" "$issue" "$prefix" 2>&1)
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

echo "=== Test Suite: create-branch.sh prefix parameter ==="
echo ""

# Mock gh for issue 42
mock_gh='#!/bin/bash
if [[ "$1" == "issue" && "$2" == "view" && "$3" == "42" && "$4" == "--json" && "$5" == "title" && "$6" == "--jq" && "$7" == ".title" ]]; then
    echo "Add user auth"
    exit 0
fi
exit 1
'

# Mock git: branch does not exist
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

# Test 1: Default prefix (feature/)
run_test "Default prefix (no arg)" "42" "" 0 "feature/42-add-user-auth" "$mock_gh" "$mock_git"

# Test 2: Custom prefix (fix/)
run_test "Custom prefix fix/" "42" "fix" 0 "fix/42-add-user-auth" "$mock_gh" "$mock_git"

# Test 3: Custom prefix (hotfix/)
run_test "Custom prefix hotfix/" "42" "hotfix" 0 "hotfix/42-add-user-auth" "$mock_gh" "$mock_git"

# Test 4: Custom prefix with trailing slash (fix/)
run_test "Prefix with trailing slash" "42" "fix/" 0 "fix/42-add-user-auth" "$mock_gh" "$mock_git"

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
