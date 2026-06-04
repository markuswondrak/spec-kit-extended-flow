#!/usr/bin/env bash
set -euo pipefail

# Test suite for workflow.yml resolve-spec refactoring
# Validates that the workflow uses an external shell script with
# separate input parameters (spec, file, issue) instead of a single
# monolithic input with regex-based format detection.

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"
WORKFLOW_FILE="$PROJECT_DIR/workflow.yml"
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

echo "=== Test Suite: workflow.yml resolve-spec refactoring ==="
echo ""

# --- External script checks ---

echo "--- Checking external script ---"
assert_file_exists "$SCRIPT_FILE" "External script exists"
assert_executable "$SCRIPT_FILE" "External script is executable"
assert_contains "$SCRIPT_FILE" "resolve_file()" "Script has resolve_file function"
assert_contains "$SCRIPT_FILE" "resolve_issue()" "Script has resolve_issue function"
assert_contains "$SCRIPT_FILE" "SPEC=""" "Script handles SPEC input"
assert_contains "$SCRIPT_FILE" "FILE=""" "Script handles FILE input"
assert_contains "$SCRIPT_FILE" "ISSUE=""" "Script handles ISSUE input"
assert_contains "$SCRIPT_FILE" "ERROR: Spec file not found" "Script has file error handling"
assert_contains "$SCRIPT_FILE" "ERROR: No specification provided" "Script has no-input error handling"

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
