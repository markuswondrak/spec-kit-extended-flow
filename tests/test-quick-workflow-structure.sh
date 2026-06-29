#!/usr/bin/env bash
set -euo pipefail

# Test suite for quick-flow.yml structure
# Validates that the quick workflow follows the lightweight implement-review-finish pattern

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"
QUICK_WORKFLOW="$PROJECT_DIR/workflows/quick-flow.yml"

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

echo "=== Test Suite: quick-flow.yml structure ==="
echo ""

assert_file_exists "$PROJECT_DIR/workflows/workflow.yml" "workflow.yml is in workflows/ directory"
assert_file_exists "$PROJECT_DIR/workflows/quick-flow.yml" "quick-flow.yml is in workflows/ directory"
assert_not_contains "$PROJECT_DIR/quick-flow.yml" "schema_version" "No quick-flow.yml at root"

# --- Workflow identity ---
echo "--- Checking workflow identity ---"
assert_contains "$QUICK_WORKFLOW" 'id: "spec-kit-quick-flow"' "Workflow has correct id"
assert_contains "$QUICK_WORKFLOW" "Quick Flow" "Workflow references Quick Flow in name or description"

# --- Inputs ---
echo "--- Checking inputs ---"
assert_contains "$QUICK_WORKFLOW" "spec:" "Has spec input"
assert_contains "$QUICK_WORKFLOW" "file:" "Has file input"
assert_contains "$QUICK_WORKFLOW" "issue:" "Has issue input"
assert_contains "$QUICK_WORKFLOW" 'default: "auto"' "Integration input uses auto default for spec-kit resolution"
assert_contains "$QUICK_WORKFLOW" 'integration: "{{ inputs.integration }}"' "Steps reference integration input"
assert_not_contains "$QUICK_WORKFLOW" 'integration: "auto"' "No literal integration: auto on steps (resolved via input)"

# --- Steps: resolve + branch ---
echo "--- Checking resolve and branch steps ---"
assert_contains "$QUICK_WORKFLOW" "resolve-spec" "Workflow has resolve-spec step"
assert_contains "$QUICK_WORKFLOW" "resolve-spec.sh" "Workflow calls resolve-spec.sh"
assert_contains "$QUICK_WORKFLOW" "create-branch" "Workflow has create-branch step"
assert_contains "$QUICK_WORKFLOW" "create-branch.sh" "Workflow calls create-branch.sh"

# --- Steps: init-quick ---
echo "--- Checking init-quick step ---"
assert_contains "$QUICK_WORKFLOW" "init-quick" "Workflow has init-quick step"
assert_contains "$QUICK_WORKFLOW" "init-quick.sh" "Workflow calls init-quick.sh"

# --- Steps: quick-implement ---
echo "--- Checking quick-implement step ---"
assert_contains "$QUICK_WORKFLOW" "quick-implement" "Workflow has quick-implement step"
assert_contains "$QUICK_WORKFLOW" "speckit.extendedflow.quick-implement" "Workflow calls quick-implement command"

# --- Steps: quick-review (self-fixing) ---
echo "--- Checking quick-review step ---"
assert_contains "$QUICK_WORKFLOW" "quick-review" "Workflow has quick-review step"
assert_contains "$QUICK_WORKFLOW" "speckit.extendedflow.quick-review" "Workflow calls quick-review command"

# --- Steps: verdict extraction ---
echo "--- Checking verdict extraction ---"
assert_contains "$QUICK_WORKFLOW" "extract-verdict.sh" "Workflow calls extract-verdict.sh"
assert_contains "$QUICK_WORKFLOW" "quick-review-verdict" "Workflow has quick-review-verdict step"

# --- Steps: stop on fail ---
echo "--- Checking stop-on-fail ---"
assert_contains "$QUICK_WORKFLOW" "stop-on-review-fail" "Workflow has stop-on-review-fail step"
assert_contains "$QUICK_WORKFLOW" "Feature Flow" "Stop message references Feature Flow escalation"

# --- Steps: doc-check ---
echo "--- Checking doc-check step ---"
assert_contains "$QUICK_WORKFLOW" "doc-check" "Workflow has doc-check step"
assert_contains "$QUICK_WORKFLOW" "speckit.extendedflow.doc-check" "Workflow calls doc-check command"

# --- Steps: finish ---
echo "--- Checking finish step ---"
assert_contains "$QUICK_WORKFLOW" "finish" "Workflow has finish step"
assert_contains "$QUICK_WORKFLOW" "speckit.extendedflow.finish" "Workflow calls finish command"

# --- Finish step: single-expression args (regression: expression engine bug) ---
echo ""
echo "--- Checking finish step args ---"
assert_not_contains "$QUICK_WORKFLOW" 'context.run_id }} {{ inputs.issue' "Finish step does not use two-expression template (regression guard)"
assert_contains "$QUICK_WORKFLOW" 'args: "{{ context.run_id }}"$' "Finish step uses single-expression args"

# --- Absence checks: no spec/plan/tasks/gates/loops ---
echo "--- Checking absence of heavy-flow steps ---"
assert_not_contains "$QUICK_WORKFLOW" "speckit.specify" "No specify command"
assert_not_contains "$QUICK_WORKFLOW" "speckit.plan" "No plan command"
assert_not_contains "$QUICK_WORKFLOW" "speckit.tasks" "No tasks command"
assert_not_contains "$QUICK_WORKFLOW" "speckit.implement" "No implement command"
assert_not_contains "$QUICK_WORKFLOW" "type: gate" "No human gates"
assert_not_contains "$QUICK_WORKFLOW" "type: do-while" "No review loop"
assert_not_contains "$QUICK_WORKFLOW" "speckit.extendedflow.documentation" "No full documentation step"
assert_not_contains "$QUICK_WORKFLOW" "verify-spec" "No verify-spec step"

# --- Agent command files ---
echo "--- Checking agent command files ---"
assert_file_exists "$PROJECT_DIR/commands/speckit.extendedflow.quick-implement.md" "quick-implement command exists"
assert_file_exists "$PROJECT_DIR/commands/speckit.extendedflow.quick-review.md" "quick-review command exists"
assert_file_exists "$PROJECT_DIR/commands/speckit.extendedflow.doc-check.md" "doc-check command exists"

# --- Script files ---
echo "--- Checking script files ---"
assert_file_exists "$PROJECT_DIR/scripts/init-quick.sh" "init-quick.sh script exists"

# --- Extension registration ---
echo "--- Checking extension registration ---"
assert_contains "$PROJECT_DIR/extension.yml" "speckit.extendedflow.quick-implement" "Extension registers quick-implement"
assert_contains "$PROJECT_DIR/extension.yml" "speckit.extendedflow.quick-review" "Extension registers quick-review"
assert_contains "$PROJECT_DIR/extension.yml" "speckit.extendedflow.doc-check" "Extension registers doc-check"

# --- Downstream contract ---
echo "--- Checking downstream contract ---"
assert_contains "$QUICK_WORKFLOW" "steps.resolve-spec.output.stdout" "Preserves downstream contract"

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
