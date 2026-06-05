#!/usr/bin/env bash
set -euo pipefail

# Test suite for commit-and-pr.sh

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"
SCRIPT_FILE="$PROJECT_DIR/scripts/commit-and-pr.sh"
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
    local setup_fn="${6:-}"

    local work_dir="$TMP_DIR/${name// /_}_wd"
    mkdir -p "$work_dir"
    cd "$work_dir"

    if [ -n "$setup_fn" ]; then
        "$setup_fn" "$work_dir"
    fi

    local mock_dir="$TMP_DIR/${name// /_}_bin"
    mkdir -p "$mock_dir"

    if [ -n "$mock_gh" ]; then
        cat > "$mock_dir/gh" <<< "$mock_gh"
        chmod +x "$mock_dir/gh"
    fi

    local actual_output
    local actual_exit=0

    set +e
    actual_output=$(PATH="$mock_dir:$PATH" bash "$SCRIPT_FILE" "$issue" 2>&1)
    actual_exit=$?
    set -e

    if [ "$actual_exit" -ne "$expected_exit" ]; then
        echo "FAIL: $name — expected exit $expected_exit, got $actual_exit"
        echo "  Output: $actual_output"
        ((FAILED++)) || true
        cd "$TMP_DIR"
        return
    fi

    if [ -n "$expected_contains" ]; then
        if ! echo "$actual_output" | grep -q "$expected_contains"; then
            echo "FAIL: $name — expected output to contain '$expected_contains'"
            echo "  Actual output: $actual_output"
            ((FAILED++)) || true
            cd "$TMP_DIR"
            return
        fi
    fi

    echo "PASS: $name"
    ((PASSED++)) || true
    cd "$TMP_DIR"
}

setup_git_repo() {
    local wd="$1"
    git init "$wd" --quiet
    git -C "$wd" config user.email "test@example.com"
    git -C "$wd" config user.name "Test User"
    echo "initial" > "$wd/README.md"
    git -C "$wd" add README.md
    git -C "$wd" commit -m "initial" --quiet
}

setup_with_changes() {
    local wd="$1"
    setup_git_repo "$wd"
    echo "new feature" > "$wd/feature.txt"
}

echo "=== Test Suite: commit-and-pr.sh ==="
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

# Test 3: No changes to commit
mock_gh='#!/bin/bash
if [[ "$1" == "issue" && "$2" == "view" && "$3" == "42" && "$4" == "--json" && "$5" == "title" && "$6" == "--jq" && "$7" == ".title" ]]; then
    echo "Add user auth"
    exit 0
fi
exit 1
'
run_test "No changes to commit" "42" 0 "No changes to commit" "$mock_gh" "setup_git_repo"

# Test 4: Successful commit and PR
mock_gh_pr='#!/bin/bash
if [[ "$1" == "issue" && "$2" == "view" && "$3" == "7" && "$4" == "--json" && "$5" == "title" && "$6" == "--jq" && "$7" == ".title" ]]; then
    echo "Fix login bug"
    exit 0
fi
if [[ "$1" == "pr" && "$2" == "create" ]]; then
    echo "https://github.com/owner/repo/pull/123"
    exit 0
fi
exit 1
'
run_test "Successful commit and PR" "7" 0 "PR created for issue" "$mock_gh_pr" "setup_with_changes"

# Verify commit was made
work_dir="$TMP_DIR/Successful_commit_and_PR_wd"
commit_msg=$(git -C "$work_dir" log -1 --pretty=%B)
if echo "$commit_msg" | grep -q "feat: Fix login bug (#7)"; then
    echo "PASS: Successful commit and PR — commit message correct"
    ((PASSED++)) || true
else
    echo "FAIL: Successful commit and PR — commit message incorrect: $commit_msg"
    ((FAILED++)) || true
fi

# Test 5: Issue fetch failure
mock_gh_fail='#!/bin/bash
exit 1
'
run_test "Issue fetch failure" "99" 1 "Failed to fetch issue" "$mock_gh_fail" "setup_git_repo"

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
