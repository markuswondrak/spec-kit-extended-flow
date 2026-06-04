#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"
README_FILE="$PROJECT_DIR/README.md"

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

assert_contains() {
    local pattern="$1"
    local msg="$2"
    if grep -Fq -- "$pattern" "$README_FILE"; then
        pass "$msg"
    else
        fail "$msg" "Expected pattern: $pattern"
    fi
}

assert_not_matches() {
    local pattern="$1"
    local msg="$2"
    if grep -Eq -- "$pattern" "$README_FILE"; then
        fail "$msg" "Found unwanted pattern: $pattern"
    else
        pass "$msg"
    fi
}

echo "=== Test Suite: install documentation ==="
echo ""

assert_contains "releases/latest/download/spec-kit-extended-flow.zip" "Quickstart uses latest release ZIP asset"
assert_contains "releases/download/v2.1.0/spec-kit-extended-flow.zip" "Docs show version-pinned release ZIP asset"
assert_contains "specify preset add --dev ." "Docs include local development install"
assert_contains '--from` expects a ZIP package URL' "Docs explain --from ZIP requirement"

assert_not_matches "specify preset add --from https://github\\.com/markuswondrak/spec-kit-extended-flow([[:space:]]|$)" "Docs do not use bare repository URL with --from"
assert_not_matches "/archive/refs/" "Docs do not rely on generated source archives"

while IFS= read -r line; do
    if [[ "$line" != *".zip"* ]]; then
        fail "Every remote --from install command points to a ZIP" "Line: $line"
    else
        pass "Remote --from install command points to a ZIP"
    fi
done < <(grep -F "specify preset add --from https://github.com/markuswondrak/spec-kit-extended-flow" "$README_FILE" || true)

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
