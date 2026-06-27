#!/usr/bin/env bash
set -euo pipefail

# Test suite for workflow.yml resolve-spec refactoring
# Validates that the workflow uses an external shell script with
# separate input parameters (spec, file, issue) instead of a single
# monolithic input with regex-based format detection.

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"
WORKFLOW_FILE="$PROJECT_DIR/workflows/workflow.yml"
SCRIPT_FILE="$PROJECT_DIR/scripts/resolve-spec.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

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

assert_file_not_exists() {
    local file="$1"
    local msg="$2"
    if [ ! -f "$file" ]; then
        echo "PASS: $msg"
        ((PASSED++)) || true
    else
        echo "FAIL: $msg"
        echo "  File still exists: $file"
        ((FAILED++)) || true
    fi
}

CREATE_BRANCH_SCRIPT="$PROJECT_DIR/scripts/create-branch.sh"
EXTRACT_VERDICT_SCRIPT="$PROJECT_DIR/scripts/extract-verdict.sh"
REVIEWER_FILE="$PROJECT_DIR/commands/speckit.extendedflow.review.md"
FIXER_FILE="$PROJECT_DIR/commands/speckit.extendedflow.fix.md"
FINISH_FILE="$PROJECT_DIR/commands/speckit.extendedflow.finish.md"

echo "=== Test Suite: workflow.yml structure ==="
echo ""

assert_file_exists "$PROJECT_DIR/workflows/workflow.yml" "workflow.yml is in workflows/ directory"
assert_not_contains "$PROJECT_DIR/workflow.yml" "schema_version" "No workflow.yml at root"

# --- External script checks ---

echo "--- Checking external scripts ---"
assert_file_exists "$SCRIPT_FILE" "resolve-spec.sh exists"
assert_executable "$SCRIPT_FILE" "resolve-spec.sh is executable"
assert_contains "$SCRIPT_FILE" "resolve_file()" "Script has resolve_file function"
assert_contains "$SCRIPT_FILE" "resolve_issue()" "Script has resolve_issue function"
assert_contains "$SCRIPT_FILE" "SPEC=""" "Script handles SPEC input"
assert_contains "$SCRIPT_FILE" "FILE=""" "Script handles FILE input"
assert_contains "$SCRIPT_FILE" "ISSUE=""" "Script handles ISSUE input"
assert_contains "$SCRIPT_FILE" "ERROR: Spec file not found" "Script has file error handling"
assert_contains "$SCRIPT_FILE" "ERROR: No specification provided" "Script has no-input error handling"

assert_file_exists "$CREATE_BRANCH_SCRIPT" "create-branch.sh exists"
assert_executable "$CREATE_BRANCH_SCRIPT" "create-branch.sh is executable"
assert_contains "$CREATE_BRANCH_SCRIPT" "feature/" "create-branch.sh creates feature branches"

assert_file_exists "$EXTRACT_VERDICT_SCRIPT" "extract-verdict.sh exists"
assert_executable "$EXTRACT_VERDICT_SCRIPT" "extract-verdict.sh is executable"
assert_contains "$EXTRACT_VERDICT_SCRIPT" "review-findings-" "extract-verdict.sh reads review-findings-*-*.md"
assert_contains "$EXTRACT_VERDICT_SCRIPT" "PASS|FAIL" "extract-verdict.sh validates PASS/FAIL verdict"

VERIFY_SPEC_SCRIPT="$PROJECT_DIR/scripts/verify-spec.sh"
assert_file_exists "$VERIFY_SPEC_SCRIPT" "verify-spec.sh exists"
assert_executable "$VERIFY_SPEC_SCRIPT" "verify-spec.sh is executable"
assert_contains "$VERIFY_SPEC_SCRIPT" "feature.json" "verify-spec.sh checks feature.json"
assert_contains "$VERIFY_SPEC_SCRIPT" "spec.md" "verify-spec.sh checks spec.md"

assert_file_exists "$FIXER_FILE" "speckit.extendedflow.fix.md exists"
assert_contains "$FIXER_FILE" "surgical" "Fixer makes surgical fixes"
assert_contains "$FIXER_FILE" "Do NOT re-implement from scratch" "Fixer does not re-implement"

# Verify dotted-namespace command files exist
DOCUMENTATION_FILE="$PROJECT_DIR/commands/speckit.extendedflow.documentation.md"
DOCUMENTATION_INIT_FILE="$PROJECT_DIR/commands/speckit.extendedflow.documentation-init.md"
assert_file_exists "$DOCUMENTATION_FILE" "speckit.extendedflow.documentation.md exists"
assert_file_exists "$DOCUMENTATION_INIT_FILE" "speckit.extendedflow.documentation-init.md exists"
assert_file_exists "$FINISH_FILE" "speckit.extendedflow.finish.md exists"
assert_contains "$FINISH_FILE" "feature_directory" "Finish agent reads feature_directory from feature.json"

# Verify old hyphenated command files no longer exist
OLD_REVIEWER_FILE="$PROJECT_DIR/commands/speckit-extendedflow.review.md"
OLD_FIXER_FILE="$PROJECT_DIR/commands/speckit-extendedflow.fix.md"
OLD_DOCUMENTATION_FILE="$PROJECT_DIR/commands/speckit-extendedflow.documentation.md"
OLD_DOCUMENTATION_INIT_FILE="$PROJECT_DIR/commands/speckit-extendedflow.documentation-init.md"
assert_file_not_exists "$OLD_REVIEWER_FILE" "Old hyphenated reviewer file removed"
assert_file_not_exists "$OLD_FIXER_FILE" "Old hyphenated fixer file removed"
assert_file_not_exists "$OLD_DOCUMENTATION_FILE" "Old hyphenated documentation file removed"
assert_file_not_exists "$OLD_DOCUMENTATION_INIT_FILE" "Old hyphenated documentation-init file removed"

# --- Workflow checks ---

echo ""
echo "--- Checking workflow structure ---"

# The workflow should call the external script using the preset-relative path
assert_contains "$WORKFLOW_FILE" ".specify/presets/spec-kit-extended-flow/scripts/resolve-spec.sh" "Workflow calls external script with preset-relative path"

# The old inline shell should be gone
assert_not_contains "$WORKFLOW_FILE" "grep -qE" "No regex-based format detection in workflow"
assert_not_contains "$WORKFLOW_FILE" "owner/repo#" "No cross-repo issue support in workflow"
assert_not_contains "$WORKFLOW_FILE" "https://github.com" "No full GitHub URL support in workflow"
assert_not_contains "$WORKFLOW_FILE" 'INPUT="{{ inputs.spec }}"' "No monolithic INPUT variable"

# New input parameters should exist
assert_contains "$WORKFLOW_FILE" "file:" "Has 'file' input parameter"
assert_contains "$WORKFLOW_FILE" "issue:" "Has 'issue' input parameter"
assert_contains "$WORKFLOW_FILE" "required: false" "Inputs are optional"

# Downstream contract preserved
assert_contains "$WORKFLOW_FILE" "steps.resolve-spec.output.stdout" "Preserves downstream contract"

# New workflow steps for issue-to-PR flow
assert_contains "$WORKFLOW_FILE" "create-branch" "Workflow has create-branch step"
assert_contains "$WORKFLOW_FILE" "verify-spec" "Workflow has verify-spec step"
assert_contains "$WORKFLOW_FILE" "verify-spec.sh" "Workflow calls verify-spec.sh"
assert_contains "$WORKFLOW_FILE" "speckit.extendedflow.finish" "Workflow calls finish command"
assert_contains "$WORKFLOW_FILE" "finish" "Workflow has finish step"
assert_not_contains "$WORKFLOW_FILE" "cleanup-feature.sh" "Workflow no longer calls cleanup-feature.sh"
assert_not_contains "$WORKFLOW_FILE" "commit-and-pr.sh" "Workflow no longer calls commit-and-pr.sh"

# Review output path updated
assert_contains "$REVIEWER_FILE" "specs/" "Review command writes to specs/<feature>/"
assert_contains "$REVIEWER_FILE" ".specify/feature.json" "Review command reads feature.json for path"
assert_contains "$REVIEWER_FILE" "review-findings-{iteration}-{VERDICT}.md" "Review command writes verdict-encoded filename"

# Verdict extraction uses external script
assert_contains "$WORKFLOW_FILE" "extract-verdict.sh" "Workflow calls extract-verdict.sh"
assert_not_contains "$WORKFLOW_FILE" "sed -n 's/^> \\*\\*" "No inline sed verdict parsing in workflow"

# No gate between tasks and implement — implementation runs automatically
assert_not_contains "$WORKFLOW_FILE" "id: tasks-gate" "No gate between tasks and implement"

# No gate after implementation — go straight to documentation
assert_not_contains "$WORKFLOW_FILE" "id: review-gate" "No gate after implementation"

# New QA structure: implement outside loop, fix loop gated by if
assert_contains "$WORKFLOW_FILE" "id: implement" "Workflow has implement step"
assert_contains "$WORKFLOW_FILE" "id: fix-if-needed" "Workflow has fix-if-needed gate"
assert_contains "$WORKFLOW_FILE" "id: fix-loop" "Workflow has fix-loop"
assert_contains "$WORKFLOW_FILE" "type: do-while" "Workflow has do-while loop"
assert_contains "$WORKFLOW_FILE" "id: fix" "Workflow has fix step"
assert_contains "$WORKFLOW_FILE" "id: fix-verdict" "Workflow has fix-verdict step"
assert_contains "$WORKFLOW_FILE" "speckit.extendedflow.fix" "Workflow calls fix command"
assert_contains "$WORKFLOW_FILE" "speckit.extendedflow.review" "Workflow uses dotted namespace for review"
assert_contains "$WORKFLOW_FILE" "speckit.extendedflow.documentation" "Workflow uses dotted namespace for documentation"
assert_not_contains "$WORKFLOW_FILE" "speckit-extendedflow.review" "Workflow does not use hyphenated namespace for review"
assert_not_contains "$WORKFLOW_FILE" "speckit-extendedflow.fix" "Workflow does not use hyphenated namespace for fix"
assert_not_contains "$WORKFLOW_FILE" "speckit-extendedflow.documentation" "Workflow does not use hyphenated namespace for documentation"

# Verify extension.yml uses dotted namespace for commands
EXTENSION_FILE="$PROJECT_DIR/extension.yml"
PRESET_FILE="$PROJECT_DIR/preset.yml"
assert_contains "$EXTENSION_FILE" 'name: speckit.extendedflow.review' "Extension registers review command with dotted namespace"
assert_contains "$EXTENSION_FILE" 'name: speckit.extendedflow.fix' "Extension registers fix command with dotted namespace"
assert_contains "$EXTENSION_FILE" 'name: speckit.extendedflow.documentation' "Extension registers documentation command with dotted namespace"
assert_contains "$EXTENSION_FILE" 'name: speckit.extendedflow.documentation-init' "Extension registers documentation-init command with dotted namespace"
assert_not_contains "$EXTENSION_FILE" 'name: speckit-extendedflow.review' "Extension does not use hyphenated namespace for review"
assert_not_contains "$EXTENSION_FILE" 'name: speckit-extendedflow.fix' "Extension does not use hyphenated namespace for fix"
assert_not_contains "$EXTENSION_FILE" 'name: speckit-extendedflow.documentation' "Extension does not use hyphenated namespace for documentation"

# Verify preset.yml does NOT contain command registrations (commands moved to extension)
assert_not_contains "$PRESET_FILE" 'type: "command"' "Preset does not register commands (moved to extension)"
assert_not_contains "$PRESET_FILE" 'name: "speckit.extendedflow.review"' "Preset does not register review command"
assert_not_contains "$PRESET_FILE" 'name: "speckit.extendedflow.fix"' "Preset does not register fix command"
assert_not_contains "$PRESET_FILE" 'name: "speckit.extendedflow.documentation"' "Preset does not register documentation command"
assert_contains "$WORKFLOW_FILE" "steps.fix-verdict.output.stdout" "Fix loop condition references fix-verdict"

# --- Per-step integration and model literals ---

echo ""
echo "--- Checking per-step integration and model literals ---"

assert_not_contains "$WORKFLOW_FILE" "inputs.integration" "No references to old monolithic integration input"
assert_not_contains "$WORKFLOW_FILE" "plan_integration:" "No plan_integration input variable"
assert_not_contains "$WORKFLOW_FILE" "implement_integration:" "No implement_integration input variable"
assert_not_contains "$WORKFLOW_FILE" "plan_model:" "No plan_model input variable"
assert_not_contains "$WORKFLOW_FILE" "implement_model:" "No implement_model input variable"

assert_contains "$WORKFLOW_FILE" 'integration: "auto"' "Steps use literal integration auto"
assert_contains "$WORKFLOW_FILE" 'model: ""' "Steps use literal empty model"

# Count occurrences: 9 command steps should have integration + model
INTEGRATION_COUNT=$(grep -c 'integration: "auto"' "$WORKFLOW_FILE" || true)
MODEL_COUNT=$(grep -c 'model: ""' "$WORKFLOW_FILE" || true)

if [ "$INTEGRATION_COUNT" -eq 9 ]; then
    echo "PASS: Exactly 9 command steps have integration: auto"
    ((PASSED++)) || true
else
    echo "FAIL: Expected 9 integration: auto occurrences, found $INTEGRATION_COUNT"
    ((FAILED++)) || true
fi

if [ "$MODEL_COUNT" -eq 9 ]; then
    echo "PASS: Exactly 9 command steps have model: \"\""
    ((PASSED++)) || true
else
    echo "FAIL: Expected 9 model: \"\" occurrences, found $MODEL_COUNT"
    ((FAILED++)) || true
fi

# --- Functional tests for the external script ---

echo ""
echo "--- Functional tests for resolve-spec.sh ---"

# Create mock gh command
cat > "$TMP_DIR/gh" << 'EOF'
#!/usr/bin/env bash
if [[ "$1" == "issue" && "$2" == "view" ]]; then
    ISSUE_NUM="$3"
    echo "# Mock Issue Title for #$ISSUE_NUM"
    echo ""
    echo "This is the mock body for issue #$ISSUE_NUM."
    exit 0
fi
echo "Unknown gh command" >&2
exit 1
EOF
chmod +x "$TMP_DIR/gh"

run_script_test() {
    local name="$1"
    local spec="${2:-}"
    local file="${3:-}"
    local issue="${4:-}"
    local expected_exit="${5:-0}"
    local expected_contains="${6:-}"

    local actual_output
    local actual_exit=0
    local output_file="$TMP_DIR/${name// /_}.out"

    # Run script and capture both stdout and stderr to file, then capture exit code
    PATH="$TMP_DIR:$PATH" bash "$SCRIPT_FILE" "$spec" "$file" "$issue" > "$output_file" 2>&1 || actual_exit=$?
    actual_output=$(cat "$output_file")

    if [ "$actual_exit" -ne "$expected_exit" ]; then
        echo "FAIL: $name — expected exit $expected_exit, got $actual_exit"
        echo "  Output: $actual_output"
        ((FAILED++)) || true
        return
    fi

    if [ -n "$expected_contains" ]; then
        if ! echo "$actual_output" | grep -q "$expected_contains"; then
            echo "FAIL: $name — expected output to contain '$expected_contains'"
            echo "  Actual output: $actual_output"
            ((FAILED++)) || true
            return
        fi
    fi

    echo "PASS: $name"
    ((PASSED++)) || true
}

# Test plain text spec
run_script_test "Plain text spec" "Build a REST API" "" "" 0 "Build a REST API"

# Test file input
echo "File content here" > "$TMP_DIR/test-spec.md"
run_script_test "File input" "" "$TMP_DIR/test-spec.md" "" 0 "File content here"

# Test issue input
run_script_test "Issue input" "" "" "42" 0 "Mock Issue Title for #42"

# Test missing file
run_script_test "Missing file" "" "$TMP_DIR/nonexistent.md" "" 1 "ERROR: Spec file not found"

# Test no inputs
run_script_test "No inputs" "" "" "" 1 "ERROR: No specification provided"

# Test combined inputs
run_script_test "All three combined" "Plain text" "$TMP_DIR/test-spec.md" "42" 0 "Plain text"

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
