#!/usr/bin/env bash
set -euo pipefail

# Test suite for bugfix-workflow.yml structure
# Validates that the bugfix workflow follows TDD-RED-GREEN-REVIEW pattern

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
assert_contains "$BUGFIX_WORKFLOW" "TDD" "Workflow references TDD in name or description"

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

# --- Steps: bug-analyze + analysis-gate ---
echo "--- Checking bug-analyze and analysis-gate ---"
assert_contains "$BUGFIX_WORKFLOW" "bug-analyze" "Workflow has bug-analyze step"
assert_contains "$BUGFIX_WORKFLOW" "speckit.extendedflow.bug-analyze" "Workflow calls bug-analyze command"
assert_contains "$BUGFIX_WORKFLOW" "analysis-gate" "Workflow has analysis-gate"
assert_contains "$BUGFIX_WORKFLOW" "type: gate" "Workflow has gate step"

# --- Steps: bug-test (RED phase) ---
echo "--- Checking bug-test (RED phase) ---"
assert_contains "$BUGFIX_WORKFLOW" "bug-test" "Workflow has bug-test step"
assert_contains "$BUGFIX_WORKFLOW" "speckit.extendedflow.bug-test" "Workflow calls bug-test command"

# --- Steps: bug-fix (GREEN phase) ---
echo "--- Checking bug-fix (GREEN phase) ---"
assert_contains "$BUGFIX_WORKFLOW" "bug-fix" "Workflow has bug-fix step"
assert_contains "$BUGFIX_WORKFLOW" "speckit.extendedflow.bug-fix" "Workflow calls bug-fix command"

# --- Steps: bug-review (REVIEW phase) ---
echo "--- Checking bug-review (REVIEW phase) ---"
assert_contains "$BUGFIX_WORKFLOW" "bug-review" "Workflow has bug-review step"
assert_contains "$BUGFIX_WORKFLOW" "speckit.extendedflow.bug-review" "Workflow calls bug-review command"

# --- Steps: verdict extraction ---
echo "--- Checking verdict extraction ---"
assert_contains "$BUGFIX_WORKFLOW" "extract-verdict.sh" "Workflow calls extract-verdict.sh"
assert_contains "$BUGFIX_WORKFLOW" "bug-review-verdict" "Workflow has bug-review-verdict step"

# --- Steps: review loop ---
echo "--- Checking review loop ---"
assert_contains "$BUGFIX_WORKFLOW" "type: do-while" "Workflow has do-while loop"
assert_contains "$BUGFIX_WORKFLOW" "max_iterations: 5" "Loop has max 5 iterations"
assert_contains "$BUGFIX_WORKFLOW" "fix-if-needed" "Workflow has fix-if-needed gate"

# --- Steps: finish ---
echo "--- Checking finish step ---"
assert_contains "$BUGFIX_WORKFLOW" "finish" "Workflow has finish step"
assert_contains "$BUGFIX_WORKFLOW" "speckit.extendedflow.finish" "Workflow calls finish command"

# --- Finish step: single-expression args (regression: expression engine bug) ---
echo ""
echo "--- Checking finish step args ---"
assert_not_contains "$BUGFIX_WORKFLOW" 'context.run_id }} {{ inputs.issue' "Finish step does not use two-expression template (regression guard)"
assert_contains "$BUGFIX_WORKFLOW" 'args: "{{ context.run_id }}"$' "Finish step uses single-expression args"

# --- Absence checks: no spec/plan/tasks ---
echo "--- Checking absence of feature-flow steps ---"
assert_not_contains "$BUGFIX_WORKFLOW" "speckit.specify" "No specify command"
assert_not_contains "$BUGFIX_WORKFLOW" "speckit.plan" "No plan command"
assert_not_contains "$BUGFIX_WORKFLOW" "speckit.tasks" "No tasks command"
assert_not_contains "$BUGFIX_WORKFLOW" "speckit.implement" "No implement command"
assert_not_contains "$BUGFIX_WORKFLOW" "speckit.extendedflow.fix" "No feature-flow fix command"
assert_not_contains "$BUGFIX_WORKFLOW" "speckit.extendedflow.documentation" "No documentation step in bugfix flow"
assert_not_contains "$BUGFIX_WORKFLOW" "verify-spec" "No verify-spec step"

# --- Agent command files ---
echo "--- Checking agent command files ---"
assert_file_exists "$PROJECT_DIR/commands/speckit.extendedflow.bug-analyze.md" "bug-analyze command exists"
assert_file_exists "$PROJECT_DIR/commands/speckit.extendedflow.bug-test.md" "bug-test command exists"
assert_file_exists "$PROJECT_DIR/commands/speckit.extendedflow.bug-fix.md" "bug-fix command exists"
assert_file_exists "$PROJECT_DIR/commands/speckit.extendedflow.bug-review.md" "bug-review command exists"

# --- Template file ---
echo "--- Checking template file ---"
assert_file_exists "$PROJECT_DIR/templates/bug-analysis.md" "bug-analysis template exists"

# --- Extension registration ---
echo "--- Checking extension registration ---"
assert_contains "$PROJECT_DIR/extension.yml" "speckit.extendedflow.bug-analyze" "Extension registers bug-analyze"
assert_contains "$PROJECT_DIR/extension.yml" "speckit.extendedflow.bug-test" "Extension registers bug-test"
assert_contains "$PROJECT_DIR/extension.yml" "speckit.extendedflow.bug-fix" "Extension registers bug-fix"
assert_contains "$PROJECT_DIR/extension.yml" "speckit.extendedflow.bug-review" "Extension registers bug-review"

# --- Preset registration ---
echo "--- Checking preset registration ---"
assert_contains "$PROJECT_DIR/preset.yml" "bug-analysis" "Preset registers bug-analysis template"

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
