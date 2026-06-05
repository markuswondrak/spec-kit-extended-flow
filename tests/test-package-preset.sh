#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"
SCRIPT_FILE="$PROJECT_DIR/scripts/package-preset.sh"
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
    if [ "${2:-}" != "" ]; then
        echo "  $2"
    fi
    ((FAILED++)) || true
}

assert_file_exists() {
    local file="$1"
    local msg="$2"
    if [ -f "$file" ]; then
        pass "$msg"
    else
        fail "$msg" "File not found: $file"
    fi
}

assert_zip_contains() {
    local listing="$1"
    local path="$2"
    local msg="$3"
    if grep -Fxq "$path" "$listing"; then
        pass "$msg"
    else
        fail "$msg" "Missing ZIP path: $path"
    fi
}

assert_zip_not_contains_prefix() {
    local listing="$1"
    local prefix="$2"
    local msg="$3"
    if grep -Eq "^${prefix}" "$listing"; then
        fail "$msg" "Found unwanted ZIP path prefix: $prefix"
    else
        pass "$msg"
    fi
}

echo "=== Test Suite: preset package ==="
echo ""

assert_file_exists "$SCRIPT_FILE" "Package script exists"

PACKAGE_PATH="$(DIST_DIR="$TMP_DIR/dist" bash "$SCRIPT_FILE")"
LISTING_FILE="$TMP_DIR/listing.txt"
EXTRACT_DIR="$TMP_DIR/extract"

assert_file_exists "$PACKAGE_PATH" "Package ZIP created"

if unzip -t "$PACKAGE_PATH" >/dev/null; then
    pass "Package ZIP integrity check passes"
else
    fail "Package ZIP integrity check passes"
fi

unzip -Z1 "$PACKAGE_PATH" > "$LISTING_FILE"

assert_zip_contains "$LISTING_FILE" "preset.yml" "ZIP contains root preset.yml"
assert_zip_contains "$LISTING_FILE" "workflow.yml" "ZIP contains root workflow.yml"
assert_zip_contains "$LISTING_FILE" "README.md" "ZIP contains README"
assert_zip_contains "$LISTING_FILE" "commands/speckit-extendedflow.documentation-init.md" "ZIP contains documentation-init command"
assert_zip_contains "$LISTING_FILE" "commands/speckit-extendedflow.documentation.md" "ZIP contains documentation command"
assert_zip_contains "$LISTING_FILE" "commands/speckit-extendedflow.reviewer.md" "ZIP contains reviewer command"
assert_zip_contains "$LISTING_FILE" "templates/documentation-init.md" "ZIP contains documentation-init template"
assert_zip_contains "$LISTING_FILE" "templates/documentation.md" "ZIP contains documentation template"
assert_zip_contains "$LISTING_FILE" "templates/review-findings.md" "ZIP contains review template"
assert_zip_contains "$LISTING_FILE" "scripts/resolve-spec.sh" "ZIP contains resolve-spec script"

assert_zip_not_contains_prefix "$LISTING_FILE" "tests/" "ZIP excludes tests"
assert_zip_not_contains_prefix "$LISTING_FILE" ".git/" "ZIP excludes git metadata"
assert_zip_not_contains_prefix "$LISTING_FILE" "dist/" "ZIP excludes dist output"
assert_zip_not_contains_prefix "$LISTING_FILE" "scripts/package-preset.sh" "ZIP excludes package builder"

mkdir -p "$EXTRACT_DIR"
unzip -q "$PACKAGE_PATH" -d "$EXTRACT_DIR"
if [ -x "$EXTRACT_DIR/scripts/resolve-spec.sh" ]; then
    pass "resolve-spec remains executable after extraction"
else
    fail "resolve-spec remains executable after extraction"
fi

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
