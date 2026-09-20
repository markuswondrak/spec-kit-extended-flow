#!/usr/bin/env bash
set -euo pipefail

# Test suite for unified-flow.yml structure
# Validates that the unified workflow triages and dispatches to the three flows.

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"
UNIFIED_WORKFLOW="$PROJECT_DIR/workflows/unified-flow.yml"

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

assert_executable() {
    local file="$1"
    local msg="$2"
    if [ -x "$file" ]; then
        echo "PASS: $msg"
        ((PASSED++)) || true
    else
        echo "FAIL: $msg"
        echo "  File not executable: $file"
        ((FAILED++)) || true
    fi
}

echo "=== Test Suite: unified-flow.yml structure ==="
echo ""

assert_file_exists "$PROJECT_DIR/workflows/unified-flow.yml" "unified-flow.yml is in workflows/ directory"
assert_not_contains "$PROJECT_DIR/unified-flow.yml" "schema_version" "No unified-flow.yml at root"

# --- Workflow identity ---
echo "--- Checking workflow identity ---"
assert_contains "$UNIFIED_WORKFLOW" 'id: "spec-kit-unified-flow"' "Workflow has correct id"
assert_contains "$UNIFIED_WORKFLOW" "Unified Flow" "Workflow references Unified Flow in name or description"

# --- Inputs ---
echo "--- Checking inputs ---"
assert_contains "$UNIFIED_WORKFLOW" "spec:" "Has spec input"
assert_contains "$UNIFIED_WORKFLOW" "file:" "Has file input"
assert_contains "$UNIFIED_WORKFLOW" "issue:" "Has issue input"
assert_contains "$UNIFIED_WORKFLOW" "flow:" "Has flow input"
assert_contains "$UNIFIED_WORKFLOW" 'enum: \["", "feature", "bugfix", "quick"\]' "flow input has constrained enum"
assert_contains "$UNIFIED_WORKFLOW" 'default: "auto"' "Integration input uses auto default for spec-kit resolution"
assert_contains "$UNIFIED_WORKFLOW" 'integration: "{{ inputs.integration }}"' "Steps reference integration input"
assert_not_contains "$UNIFIED_WORKFLOW" 'integration: "auto"' "No literal integration: auto on steps (resolved via input)"

# --- Shared steps ---
echo "--- Checking shared steps ---"
assert_contains "$UNIFIED_WORKFLOW" "resolve-spec" "Workflow has resolve-spec step"
assert_contains "$UNIFIED_WORKFLOW" "resolve-spec.sh" "Workflow calls resolve-spec.sh"
assert_contains "$UNIFIED_WORKFLOW" "triage" "Workflow has triage step"
assert_contains "$UNIFIED_WORKFLOW" "speckit.extendedflow.triage" "Workflow calls triage command"
assert_contains "$UNIFIED_WORKFLOW" "triage-verdict" "Workflow has triage-verdict step"
assert_contains "$UNIFIED_WORKFLOW" "extract-triage.sh" "Workflow calls extract-triage.sh"
assert_contains "$UNIFIED_WORKFLOW" "finish" "Workflow has finish step"
assert_contains "$UNIFIED_WORKFLOW" "speckit.extendedflow.finish" "Workflow calls finish command"

# --- Dispatch ---
echo "--- Checking switch dispatch ---"
assert_contains "$UNIFIED_WORKFLOW" "type: switch" "Workflow has switch dispatch step"
assert_contains "$UNIFIED_WORKFLOW" "id: dispatch" "Switch step has id dispatch"
assert_contains "$UNIFIED_WORKFLOW" 'expression: "{{ inputs.flow | default(steps.triage-verdict.output.stdout) }}"' "Switch expression uses flow override with triage fallback"
assert_contains "$UNIFIED_WORKFLOW" "feature:" "Switch has feature case"
assert_contains "$UNIFIED_WORKFLOW" "bugfix:" "Switch has bugfix case"
assert_contains "$UNIFIED_WORKFLOW" "quick:" "Switch has quick case"
assert_contains "$UNIFIED_WORKFLOW" "default:" "Switch has default case"

# --- Feature branch ---
echo "--- Checking feature branch ---"
assert_contains "$UNIFIED_WORKFLOW" "feature-specify" "Feature branch has specify step"
assert_contains "$UNIFIED_WORKFLOW" "feature-plan" "Feature branch has plan step"
assert_contains "$UNIFIED_WORKFLOW" "feature-tasks" "Feature branch has tasks step"
assert_contains "$UNIFIED_WORKFLOW" "feature-analyze" "Feature branch has analyze step"
assert_contains "$UNIFIED_WORKFLOW" "feature-implement" "Feature branch has implement step"
assert_contains "$UNIFIED_WORKFLOW" "feature-converge-loop" "Feature branch has converge loop"
assert_contains "$UNIFIED_WORKFLOW" "feature-converge-check" "Feature branch has converge-check step"
assert_contains "$UNIFIED_WORKFLOW" "feature-documentation" "Feature branch has documentation step"
assert_contains "$UNIFIED_WORKFLOW" "check-converge.sh" "Feature branch calls check-converge.sh"
assert_contains "$UNIFIED_WORKFLOW" "speckit.specify" "Feature branch calls speckit.specify"
assert_contains "$UNIFIED_WORKFLOW" "speckit.plan" "Feature branch calls speckit.plan"
assert_contains "$UNIFIED_WORKFLOW" "speckit.tasks" "Feature branch calls speckit.tasks"
assert_contains "$UNIFIED_WORKFLOW" "speckit.analyze" "Feature branch calls speckit.analyze"
assert_contains "$UNIFIED_WORKFLOW" "speckit.implement" "Feature branch calls speckit.implement"
assert_contains "$UNIFIED_WORKFLOW" "speckit.converge" "Feature branch calls speckit.converge"
assert_contains "$UNIFIED_WORKFLOW" "speckit.extendedflow.documentation" "Feature branch calls documentation command"
assert_not_contains "$UNIFIED_WORKFLOW" "speckit.extendedflow.review" "Feature branch no longer calls review command"
assert_not_contains "$UNIFIED_WORKFLOW" "speckit.extendedflow.fix" "Feature branch no longer calls fix command"

# --- Bugfix branch ---
echo "--- Checking bugfix branch ---"
assert_contains "$UNIFIED_WORKFLOW" "bugfix-bug-assess" "Bugfix branch has bug-assess step"
assert_contains "$UNIFIED_WORKFLOW" "bugfix-bug-test" "Bugfix branch has bug-test step"
assert_contains "$UNIFIED_WORKFLOW" "bugfix-bug-fix" "Bugfix branch has bug-fix step"
assert_contains "$UNIFIED_WORKFLOW" "bugfix-resolve-bug-context" "Bugfix branch resolves bug context"
assert_contains "$UNIFIED_WORKFLOW" "speckit.bug.assess" "Bugfix branch calls standard bug assess command"
assert_contains "$UNIFIED_WORKFLOW" "speckit.bug.test" "Bugfix branch calls standard bug test command"
assert_contains "$UNIFIED_WORKFLOW" "speckit.bug.fix" "Bugfix branch calls standard bug fix command"
assert_contains "$UNIFIED_WORKFLOW" "check-bug-verdict.sh" "Bugfix branch checks standard bug verdict"

# --- Quick branch ---
echo "--- Checking quick branch ---"
assert_contains "$UNIFIED_WORKFLOW" "quick-init" "Quick branch has init-quick step"
assert_contains "$UNIFIED_WORKFLOW" "quick-implement" "Quick branch has quick-implement step"
assert_contains "$UNIFIED_WORKFLOW" "quick-review" "Quick branch has quick-review step"
assert_contains "$UNIFIED_WORKFLOW" "quick-doc-check" "Quick branch has doc-check step"
assert_contains "$UNIFIED_WORKFLOW" "init-quick.sh" "Quick branch calls init-quick.sh"
assert_contains "$UNIFIED_WORKFLOW" "speckit.extendedflow.quick-implement" "Quick branch calls quick-implement command"
assert_contains "$UNIFIED_WORKFLOW" "speckit.extendedflow.quick-review" "Quick branch calls quick-review command"
assert_contains "$UNIFIED_WORKFLOW" "speckit.extendedflow.doc-check" "Quick branch calls doc-check command"

# --- Downstream contract ---
echo "--- Checking downstream contract ---"
assert_contains "$UNIFIED_WORKFLOW" "steps.resolve-spec.output.stdout" "Preserves downstream contract"

# --- Finish step: single-expression args (regression guard) ---
echo "--- Checking finish step args ---"
assert_not_contains "$UNIFIED_WORKFLOW" 'context.run_id }} {{ inputs.issue' "Finish step does not use two-expression template"
assert_contains "$UNIFIED_WORKFLOW" 'args: "{{ context.run_id }}"$' "Finish step uses single-expression args"

# --- Agent command and script files ---
echo "--- Checking agent command and script files ---"
assert_file_exists "$PROJECT_DIR/commands/speckit.extendedflow.triage.md" "triage command exists"
assert_file_exists "$PROJECT_DIR/scripts/extract-triage.sh" "extract-triage.sh script exists"
assert_executable "$PROJECT_DIR/scripts/extract-triage.sh" "extract-triage.sh is executable"
assert_file_exists "$PROJECT_DIR/templates/triage.md" "triage template exists"

# --- Extension and preset registration ---
echo "--- Checking extension and preset registration ---"
assert_contains "$PROJECT_DIR/extension.yml" "speckit.extendedflow.triage" "Extension registers triage command"
assert_contains "$PROJECT_DIR/preset.yml" "name: \"triage\"" "Preset registers triage template"
assert_contains "$PROJECT_DIR/bundle.yml" "spec-kit-unified-flow" "Bundle registers unified workflow"

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
