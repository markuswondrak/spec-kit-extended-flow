#!/usr/bin/env bash
set -euo pipefail

# Test suite: resolve-pr-template.sh
# Verifies that the script discovers PR templates in GitHub-standard locations
# and returns empty string when none exist.

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"
SCRIPT="$PROJECT_DIR/scripts/resolve-pr-template.sh"

PASSED=0
FAILED=0

echo "=== Test Suite: resolve-pr-template.sh ==="
echo ""

# --- Test 1: no template -> empty stdout, exit 0 ---
echo "Test 1: No template found"
tmpdir=$(mktemp -d)
pushd "$tmpdir" >/dev/null
result=$(bash "$SCRIPT")
popd >/dev/null
rm -rf "$tmpdir"
if [ -z "$result" ]; then
    echo "PASS: empty stdout when no template exists"
    ((PASSED++)) || true
else
    echo "FAIL: expected empty stdout, got: $result"
    ((FAILED++)) || true
fi

# --- Test 2: top-level PULL_REQUEST_TEMPLATE.md ---
echo "Test 2: Top-level template"
tmpdir=$(mktemp -d)
pushd "$tmpdir" >/dev/null
echo "# Top" > PULL_REQUEST_TEMPLATE.md
result=$(bash "$SCRIPT")
popd >/dev/null
rm -rf "$tmpdir"
if [ "$result" = "$tmpdir/PULL_REQUEST_TEMPLATE.md" ]; then
    echo "PASS: found top-level template"
    ((PASSED++)) || true
else
    echo "FAIL: expected $tmpdir/PULL_REQUEST_TEMPLATE.md, got: $result"
    ((FAILED++)) || true
fi

# --- Test 3: docs/PULL_REQUEST_TEMPLATE.md (takes precedence over top-level) ---
echo "Test 3: docs/ template precedence over top-level"
tmpdir=$(mktemp -d)
pushd "$tmpdir" >/dev/null
mkdir -p docs
echo "# Docs" > docs/PULL_REQUEST_TEMPLATE.md
echo "# Top" > PULL_REQUEST_TEMPLATE.md
result=$(bash "$SCRIPT")
popd >/dev/null
rm -rf "$tmpdir"
if [ "$result" = "$tmpdir/docs/PULL_REQUEST_TEMPLATE.md" ]; then
    echo "PASS: docs/ template wins over top-level"
    ((PASSED++)) || true
else
    echo "FAIL: expected $tmpdir/docs/PULL_REQUEST_TEMPLATE.md, got: $result"
    ((FAILED++)) || true
fi

# --- Test 4: .github/PULL_REQUEST_TEMPLATE.md (takes precedence over docs/) ---
echo "Test 4: .github/ single template precedence"
tmpdir=$(mktemp -d)
pushd "$tmpdir" >/dev/null
mkdir -p .github docs
echo "# GitHub" > .github/PULL_REQUEST_TEMPLATE.md
echo "# Docs" > docs/PULL_REQUEST_TEMPLATE.md
result=$(bash "$SCRIPT")
popd >/dev/null
rm -rf "$tmpdir"
if [ "$result" = "$tmpdir/.github/PULL_REQUEST_TEMPLATE.md" ]; then
    echo "PASS: .github/ single template wins"
    ((PASSED++)) || true
else
    echo "FAIL: expected $tmpdir/.github/PULL_REQUEST_TEMPLATE.md, got: $result"
    ((FAILED++)) || true
fi

# --- Test 5: .github/PULL_REQUEST_TEMPLATE/*.md (highest precedence) ---
echo "Test 5: Variant template highest precedence"
tmpdir=$(mktemp -d)
pushd "$tmpdir" >/dev/null
mkdir -p .github/PULL_REQUEST_TEMPLATE docs
echo "# Variant" > .github/PULL_REQUEST_TEMPLATE/feature.md
echo "# GitHub" > .github/PULL_REQUEST_TEMPLATE.md
echo "# Docs" > docs/PULL_REQUEST_TEMPLATE.md
result=$(bash "$SCRIPT")
popd >/dev/null
rm -rf "$tmpdir"
if [ "$result" = "$tmpdir/.github/PULL_REQUEST_TEMPLATE/feature.md" ]; then
    echo "PASS: variant template wins over all others"
    ((PASSED++)) || true
else
    echo "FAIL: expected $tmpdir/.github/PULL_REQUEST_TEMPLATE/feature.md, got: $result"
    ((FAILED++)) || true
fi

# --- Test 6: multiple variants -> first alphabetically ---
echo "Test 6: Multiple variants -> first alphabetically"
tmpdir=$(mktemp -d)
pushd "$tmpdir" >/dev/null
mkdir -p .github/PULL_REQUEST_TEMPLATE
echo "# Zulu" > .github/PULL_REQUEST_TEMPLATE/zulu.md
echo "# Alpha" > .github/PULL_REQUEST_TEMPLATE/alpha.md
echo "# Beta" > .github/PULL_REQUEST_TEMPLATE/beta.md
result=$(bash "$SCRIPT")
popd >/dev/null
rm -rf "$tmpdir"
if [ "$result" = "$tmpdir/.github/PULL_REQUEST_TEMPLATE/alpha.md" ]; then
    echo "PASS: first alphabetical variant selected"
    ((PASSED++)) || true
else
    echo "FAIL: expected $tmpdir/.github/PULL_REQUEST_TEMPLATE/alpha.md, got: $result"
    ((FAILED++)) || true
fi

# --- Test 7: empty variant dir -> fall through to single template ---
echo "Test 7: Empty variant dir fall-through"
tmpdir=$(mktemp -d)
pushd "$tmpdir" >/dev/null
mkdir -p .github/PULL_REQUEST_TEMPLATE
echo "# GitHub" > .github/PULL_REQUEST_TEMPLATE.md
result=$(bash "$SCRIPT")
popd >/dev/null
rm -rf "$tmpdir"
if [ "$result" = "$tmpdir/.github/PULL_REQUEST_TEMPLATE.md" ]; then
    echo "PASS: falls through when variant dir is empty"
    ((PASSED++)) || true
else
    echo "FAIL: expected $tmpdir/.github/PULL_REQUEST_TEMPLATE.md, got: $result"
    ((FAILED++)) || true
fi

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
