#!/usr/bin/env bash
set -euo pipefail

# Test suite: verify project-init command and preset registration

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"
COMMAND_FILE="$PROJECT_DIR/commands/speckit.extendedflow.project-init.md"
PRESET_FILE="$PROJECT_DIR/preset.yml"
EXTENSION_FILE="$PROJECT_DIR/extension.yml"

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

assert_file_exists() {
    local file="$1"
    local msg="$2"
    if [ -f "$file" ]; then
        pass "$msg"
    else
        fail "$msg" "File not found: $file"
    fi
}

assert_contains() {
    local file="$1"
    local pattern="$2"
    local msg="$3"
    if grep -Fq -- "$pattern" "$file"; then
        pass "$msg"
    else
        fail "$msg" "Expected pattern: $pattern"
    fi
}

assert_not_contains() {
    local file="$1"
    local pattern="$2"
    local msg="$3"
    if grep -Fq -- "$pattern" "$file"; then
        fail "$msg" "Found unwanted pattern: $pattern"
    else
        pass "$msg"
    fi
}

echo "=== Test Suite: project-init command ==="
echo ""

# --- File existence checks ---

echo "--- Checking file existence ---"
assert_file_exists "$COMMAND_FILE" "project-init command file exists"

# --- Command structure checks ---

echo ""
echo "--- Checking command structure ---"
assert_contains "$COMMAND_FILE" "# Spec-Kit Extended Flow Project Init" "Command has correct header"
assert_contains "$COMMAND_FILE" "## Your Role" "Command defines agent role"
assert_contains "$COMMAND_FILE" "## Inputs" "Command defines inputs"
assert_contains "$COMMAND_FILE" "## Phase 1: Context Discovery" "Command has Phase 1"
assert_contains "$COMMAND_FILE" "## Phase 2: Template Tailoring" "Command has Phase 2"
assert_contains "$COMMAND_FILE" "## Phase 3: Persistence" "Command has Phase 3"
assert_contains "$COMMAND_FILE" "## Output Requirements" "Command has output requirements"
assert_contains "$COMMAND_FILE" ".specify/templates/overrides/" "Command references override directory"
assert_contains "$COMMAND_FILE" "spec-template.md" "Command references spec template"
assert_contains "$COMMAND_FILE" "plan-template.md" "Command references plan template"
assert_contains "$COMMAND_FILE" "tasks-template.md" "Command references tasks template"
assert_contains "$COMMAND_FILE" "constitution-template.md" "Command references constitution template"
assert_contains "$COMMAND_FILE" "checklist-template.md" "Command references checklist template"
assert_contains "$COMMAND_FILE" "interactive" "Command is interactive/dialog-based"
assert_contains "$COMMAND_FILE" "dialogue" "Command uses dialogue with user"
assert_not_contains "$COMMAND_FILE" "Produce output following the \`project-init\` template" "Command does not reference removed template"

# --- Extension registration checks ---

echo ""
echo "--- Checking extension.yml registration ---"
assert_contains "$EXTENSION_FILE" 'name: speckit.extendedflow.project-init' "Extension registers project-init command"
assert_contains "$EXTENSION_FILE" "commands/speckit.extendedflow.project-init.md" "Extension points to correct command file"
assert_not_contains "$EXTENSION_FILE" 'name: project-init' "Extension does not register project-init as bare name"

# Verify preset.yml does NOT contain command registrations (commands moved to extension)
assert_not_contains "$PRESET_FILE" 'name: "speckit.extendedflow.project-init"' "Preset does not register project-init command"
assert_not_contains "$PRESET_FILE" "commands/speckit.extendedflow.project-init.md" "Preset does not point to project-init command file"
assert_not_contains "$PRESET_FILE" "templates/project-init.md" "Preset does not point to removed template file"

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
