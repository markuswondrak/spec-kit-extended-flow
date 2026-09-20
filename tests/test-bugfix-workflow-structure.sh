#!/usr/bin/env bash
set -euo pipefail

# Test suite for bugfix-workflow.yml structure
# Validates that the bugfix workflow delegates bug handling to Spec-Kit's bug extension

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"
BUGFIX_WORKFLOW="$PROJECT_DIR/workflows/bugfix-workflow.yml"

PASSED=0
FAILED=0

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

echo "=== Test Suite: bugfix-workflow.yml structure ==="
echo ""

assert_file_exists "$PROJECT_DIR/workflows/workflow.yml" "workflow.yml is in workflows/ directory"
assert_file_exists "$PROJECT_DIR/workflows/bugfix-workflow.yml" "bugfix-workflow.yml is in workflows/ directory"
assert_not_contains "$PROJECT_DIR/bugfix-workflow.yml" "schema_version" "No bugfix-workflow.yml at root"

# --- Workflow identity ---
echo "--- Checking workflow identity ---"
assert_contains "$BUGFIX_WORKFLOW" 'id: "spec-kit-bugfix-flow"' "Workflow has correct id"
assert_contains "$BUGFIX_WORKFLOW" "standard bug" "Workflow references standard bug commands"

# --- Inputs ---
echo "--- Checking inputs ---"
assert_contains "$BUGFIX_WORKFLOW" "spec:" "Has spec input"
assert_contains "$BUGFIX_WORKFLOW" "file:" "Has file input"
assert_contains "$BUGFIX_WORKFLOW" "issue:" "Has issue input"
assert_contains "$BUGFIX_WORKFLOW" 'default: "auto"' "Integration input uses auto default for spec-kit resolution"
assert_contains "$BUGFIX_WORKFLOW" 'integration: "{{ inputs.integration }}"' "Steps reference integration input"
assert_not_contains "$BUGFIX_WORKFLOW" 'integration: "auto"' "No literal integration: auto on steps (resolved via input)"

# --- Steps: resolve + branch ---
echo "--- Checking resolve and branch steps ---"
assert_contains "$BUGFIX_WORKFLOW" "resolve-spec" "Workflow has resolve-spec step"
assert_contains "$BUGFIX_WORKFLOW" "resolve-spec.sh" "Workflow calls resolve-spec.sh"
assert_contains "$BUGFIX_WORKFLOW" "create-branch" "Workflow has create-branch step"
assert_contains "$BUGFIX_WORKFLOW" "create-branch.sh" "Workflow calls create-branch.sh"

# --- Steps: standard assess + context + gate ---
echo "--- Checking standard assess and assessment gate ---"
assert_contains "$BUGFIX_WORKFLOW" "bug-assess" "Workflow has bug-assess step"
assert_contains "$BUGFIX_WORKFLOW" "speckit.bug.assess" "Workflow calls standard bug assess command"
assert_contains "$BUGFIX_WORKFLOW" "resolve-bug-context" "Workflow resolves standard bug context"
assert_contains "$BUGFIX_WORKFLOW" "assessment-gate" "Workflow has assessment gate"
assert_contains "$BUGFIX_WORKFLOW" "type: gate" "Workflow has gate step"

# --- Steps: standard bug-test ---
echo "--- Checking standard bug-test ---"
assert_contains "$BUGFIX_WORKFLOW" "bug-test" "Workflow has bug-test step"
assert_contains "$BUGFIX_WORKFLOW" "speckit.bug.test" "Workflow calls standard bug test command"

# --- Steps: standard bug-fix ---
echo "--- Checking standard bug-fix ---"
assert_contains "$BUGFIX_WORKFLOW" "bug-fix" "Workflow has bug-fix step"
assert_contains "$BUGFIX_WORKFLOW" "speckit.bug.fix" "Workflow calls standard bug fix command"

# --- Steps: verdict extraction ---
echo "--- Checking verdict extraction ---"
assert_contains "$BUGFIX_WORKFLOW" "check-bug-verdict.sh" "Workflow checks standard bug verdict"
assert_contains "$BUGFIX_WORKFLOW" "bug-verification" "Workflow has bug-verification step"
assert_not_contains "$BUGFIX_WORKFLOW" "type: do-while" "Bugfix flow uses standard linear lifecycle"

# --- Steps: finish ---
echo "--- Checking finish step ---"
assert_contains "$BUGFIX_WORKFLOW" "finish" "Workflow has finish step"
assert_contains "$BUGFIX_WORKFLOW" "speckit.extendedflow.finish" "Workflow calls finish command"

# --- Finish step: single-expression args (regression: expression engine bug) ---
echo ""
echo "--- Checking finish step args ---"
assert_not_contains "$BUGFIX_WORKFLOW" 'context.run_id }} {{ inputs.issue' "Finish step does not use two-expression template (regression guard)"
assert_contains "$BUGFIX_WORKFLOW" 'args: "{{ context.run_id }}"$' "Finish step uses single-expression args"

# --- Absence checks: no custom bug commands or feature flow ---
echo "--- Checking absence of feature-flow steps ---"
assert_not_contains "$BUGFIX_WORKFLOW" "speckit.specify" "No specify command"
assert_not_contains "$BUGFIX_WORKFLOW" "speckit.plan" "No plan command"
assert_not_contains "$BUGFIX_WORKFLOW" "speckit.tasks" "No tasks command"
assert_not_contains "$BUGFIX_WORKFLOW" "speckit.implement" "No implement command"
assert_not_contains "$BUGFIX_WORKFLOW" "speckit.extendedflow.fix" "No feature-flow fix command"
assert_not_contains "$BUGFIX_WORKFLOW" "speckit.extendedflow.documentation" "No documentation step in bugfix flow"
assert_not_contains "$BUGFIX_WORKFLOW" "verify-spec" "No verify-spec step"

# --- Extension registration ---
echo "--- Checking extension registration ---"
assert_contains "$PROJECT_DIR/README.md" "specify extension add bug" "Docs require standard bug extension"
assert_contains "$PROJECT_DIR/extension.yml" 'speckit_version: ">=0.11.2"' "Extension requires a speckit version that includes the standard bug extension and converge"
assert_not_contains "$PROJECT_DIR/extension.yml" "speckit.extendedflow.bug-" "Extension does not register custom bug commands"

# --- Preset registration ---
echo "--- Checking preset registration ---"
assert_not_contains "$PROJECT_DIR/preset.yml" "bug-analysis" "Preset does not register duplicate bug template"

# --- Downstream contract ---
echo "--- Checking downstream contract ---"
assert_contains "$BUGFIX_WORKFLOW" "steps.resolve-spec.output.stdout" "Preserves downstream contract"

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
