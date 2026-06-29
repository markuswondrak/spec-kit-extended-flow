#!/usr/bin/env bash
set -euo pipefail

# Test suite: verify bundle.yml manifest structure, consistency,
# and component references.

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"
BUNDLE_FILE="$PROJECT_DIR/bundle.yml"
PRESET_FILE="$PROJECT_DIR/preset.yml"
EXTENSION_FILE="$PROJECT_DIR/extension.yml"
WORKFLOWS_DIR="$PROJECT_DIR/workflows"

PASSED=0
FAILED=0

assert_file_exists() {
    local file="$1"
    local msg="$2"
    if [ -f "$file" ]; then
        echo "PASS: $msg"
        ((PASSED++)) || true
    else
        echo "FAIL: $msg"
        echo "  File not found: $file"
        ((FAILED++)) || true
    fi
}

assert_contains() {
    local file="$1"
    local pattern="$2"
    local msg="$3"
    if grep -q "$pattern" "$file"; then
        echo "PASS: $msg"
        ((PASSED++)) || true
    else
        echo "FAIL: $msg"
        echo "  Expected pattern: $pattern"
        ((FAILED++)) || true
    fi
}

assert_not_contains() {
    local file="$1"
    local pattern="$2"
    local msg="$3"
    if grep -q "$pattern" "$file"; then
        echo "FAIL: $msg"
        echo "  Found unwanted pattern: $pattern"
        ((FAILED++)) || true
    else
        echo "PASS: $msg"
        ((PASSED++)) || true
    fi
}

assert_equals() {
    local actual="$1"
    local expected="$2"
    local msg="$3"
    if [ "$actual" = "$expected" ]; then
        echo "PASS: $msg"
        ((PASSED++)) || true
    else
        echo "FAIL: $msg"
        echo "  Expected: '$expected'"
        echo "  Actual:   '$actual'"
        ((FAILED++)) || true
    fi
}

echo "=== Test Suite: bundle.yml manifest ==="
echo ""

# --- File existence ---
assert_file_exists "$BUNDLE_FILE" "bundle.yml exists in project root"

# --- Schema and bundle metadata ---
assert_contains "$BUNDLE_FILE" 'schema_version: "1.0"' "bundle.yml has schema_version 1.0"
assert_contains "$BUNDLE_FILE" 'id: "spec-kit-extended-flow"' "bundle.id is spec-kit-extended-flow"
assert_contains "$BUNDLE_FILE" 'name: "Spec-Kit Extended Flow"' "bundle.name matches project"
assert_contains "$BUNDLE_FILE" 'role: "developer"' "bundle.role is developer"
assert_contains "$BUNDLE_FILE" 'license: "MIT"' "bundle.license is MIT"

# --- Version consistency ---
BUNDLE_VERSION=$(grep -E '^  version:' "$BUNDLE_FILE" | sed -E 's/.*"([^"]+)".*/\1/' | head -n1)
PRESET_VERSION=$(grep -E '^  version:' "$PRESET_FILE" | sed -E 's/.*"([^"]+)".*/\1/' | head -n1)
EXTENSION_VERSION=$(grep -E '^  version:' "$EXTENSION_FILE" | sed -E 's/.*"([^"]+)".*/\1/' | head -n1)

assert_equals "$BUNDLE_VERSION" "$PRESET_VERSION" "bundle.version matches preset.version"
assert_equals "$BUNDLE_VERSION" "$EXTENSION_VERSION" "bundle.version matches extension.version"

# --- Requirements ---
assert_contains "$BUNDLE_FILE" 'speckit_version: ">=0.9.0"' "bundle requires speckit >= 0.9.0"

# --- Component references: extension ---
assert_contains "$BUNDLE_FILE" 'id: "extendedflow"' "bundle references extendedflow extension"
assert_contains "$BUNDLE_FILE" 'extensions:' "bundle has extensions section"

# --- Component references: preset ---
assert_contains "$BUNDLE_FILE" 'id: "spec-kit-extended-flow"' "bundle references spec-kit-extended-flow preset"
assert_contains "$BUNDLE_FILE" 'presets:' "bundle has presets section"
assert_contains "$BUNDLE_FILE" 'priority: 10' "bundle preset has priority 10"
assert_contains "$BUNDLE_FILE" 'strategy: "append"' "bundle preset uses append strategy"

# --- Component references: workflows ---
assert_contains "$BUNDLE_FILE" 'workflows:' "bundle has workflows section"
assert_contains "$BUNDLE_FILE" 'id: "spec-kit-extended-flow"' "bundle references feature workflow"
assert_contains "$BUNDLE_FILE" 'id: "spec-kit-bugfix-flow"' "bundle references bugfix workflow"
assert_contains "$BUNDLE_FILE" 'id: "spec-kit-quick-flow"' "bundle references quick workflow"

# Verify workflow versions match the actual workflow files
FEATURE_WF_VERSION=$(grep -E '^  version:' "$WORKFLOWS_DIR/workflow.yml" | sed -E 's/.*"([^"]+)".*/\1/' | head -n1)
BUGFIX_WF_VERSION=$(grep -E '^  version:' "$WORKFLOWS_DIR/bugfix-workflow.yml" | sed -E 's/.*"([^"]+)".*/\1/' | head -n1)
QUICK_WF_VERSION=$(grep -E '^  version:' "$WORKFLOWS_DIR/quick-flow.yml" | sed -E 's/.*"([^"]+)".*/\1/' | head -n1)

assert_contains "$BUNDLE_FILE" "version: \"$FEATURE_WF_VERSION\"" "bundle references feature workflow version $FEATURE_WF_VERSION"
assert_contains "$BUNDLE_FILE" "version: \"$BUGFIX_WF_VERSION\"" "bundle references bugfix workflow version $BUGFIX_WF_VERSION"
assert_contains "$BUNDLE_FILE" "version: \"$QUICK_WF_VERSION\"" "bundle references quick workflow version $QUICK_WF_VERSION"

# --- Tags ---
assert_contains "$BUNDLE_FILE" 'tags:' "bundle has tags section"
assert_contains "$BUNDLE_FILE" '"qa"' "bundle has qa tag"
assert_contains "$BUNDLE_FILE" '"review"' "bundle has review tag"
assert_contains "$BUNDLE_FILE" '"documentation"' "bundle has documentation tag"
assert_contains "$BUNDLE_FILE" '"workflow"' "bundle has workflow tag"

# --- Negative checks ---
# bundle.yml should NOT contain inline component definitions (it's a meta-manifest)
assert_not_contains "$BUNDLE_FILE" 'commands:' "bundle.yml does not define commands inline"
assert_not_contains "$BUNDLE_FILE" 'templates:' "bundle.yml does not define templates inline"
assert_not_contains "$BUNDLE_FILE" 'steps:' "bundle.yml does not define steps inline (Extended Flow has no standalone steps)"

# --- Physical workflow files exist ---
assert_file_exists "$WORKFLOWS_DIR/workflow.yml" "Feature workflow file exists"
assert_file_exists "$WORKFLOWS_DIR/bugfix-workflow.yml" "Bugfix workflow file exists"
assert_file_exists "$WORKFLOWS_DIR/quick-flow.yml" "Quick workflow file exists"

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
