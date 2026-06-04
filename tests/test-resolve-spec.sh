#!/usr/bin/env bash
set -euo pipefail

# Test suite for resolve-spec logic
# Tests the new separated input parameters: spec, file, issue

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASSED=0
FAILED=0

# Helper: run a test case
run_test() {
    local name="$1"
    local spec="${2:-}"
    local file="${3:-}"
    local issue="${4:-}"
    local expected_exit="${5:-0}"
    local expected_contains="${6:-}"

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

    # Write the resolve-spec script to a temp file
    cat > "$TMP_DIR/resolve-spec.sh" << 'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

SPEC="${SPEC_INPUT:-}"
FILE="${FILE_INPUT:-}"
ISSUE="${ISSUE_INPUT:-}"
OUTPUT=""

# Branch 1: File input
if [ -n "$FILE" ]; then
  if [ ! -f "$FILE" ]; then
    echo "ERROR: Spec file not found: $FILE" >&2
    exit 1
  fi
  OUTPUT="${OUTPUT}$(cat "$FILE")"$'\n'
fi

# Branch 2: Issue input
if [ -n "$ISSUE" ]; then
  if ! command -v gh &> /dev/null; then
    echo "ERROR: GitHub CLI (gh) is required to fetch issues. Install and authenticate with 'gh auth login'." >&2
    exit 1
  fi
  ISSUE_CONTENT=$(gh issue view "$ISSUE" --json title,body --jq '"# " + .title + "\n\n" + .body' 2>&1)
  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to fetch issue #$ISSUE. Ensure the issue exists and gh is authenticated." >&2
    exit 1
  fi
  OUTPUT="${OUTPUT}${ISSUE_CONTENT}"$'\n'
fi

# Branch 3: Plain text spec
if [ -n "$SPEC" ]; then
  OUTPUT="${OUTPUT}${SPEC}"$'\n'
fi

# Fail if no input provided
if [ -z "$OUTPUT" ]; then
  echo "ERROR: No specification provided. Set at least one of: --input spec, --input file, or --input issue." >&2
  exit 1
fi

echo "$OUTPUT"
SCRIPT
    chmod +x "$TMP_DIR/resolve-spec.sh"

    # Run the script with mocked inputs
    local actual_output
    local actual_exit=0
    if ! actual_output=$(PATH="$TMP_DIR:$PATH" SPEC_INPUT="$spec" FILE_INPUT="$file" ISSUE_INPUT="$issue" bash "$TMP_DIR/resolve-spec.sh" 2>&1); then
        actual_exit=$?
    fi

    # Check exit code
    if [ "$actual_exit" -ne "$expected_exit" ]; then
        echo "FAIL: $name — expected exit $expected_exit, got $actual_exit"
        echo "  Output: $actual_output"
        ((FAILED++)) || true
        return
    fi

    # Check expected content
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

echo "=== Test Suite: resolve-spec logic ==="
echo ""

# Test 1: Plain text spec only
run_test "Plain text spec" "Build a REST API" "" "" 0 "Build a REST API"

# Test 2: File input only
echo "File content here" > "$TMP_DIR/test-spec.md"
run_test "File input" "" "$TMP_DIR/test-spec.md" "" 0 "File content here"

# Test 3: Issue input only
run_test "Issue input" "" "" "42" 0 "Mock Issue Title for #42"

# Test 4: Missing file
run_test "Missing file" "" "$TMP_DIR/nonexistent.md" "" 1 "ERROR: Spec file not found"

# Test 5: No inputs provided
run_test "No inputs" "" "" "" 1 "ERROR: No specification provided"

# Test 6: Spec + file combined
run_test "Spec and file combined" "Plain text" "$TMP_DIR/test-spec.md" "" 0 "Plain text"

# Test 7: Spec + issue combined
run_test "Spec and issue combined" "Plain text" "" "42" 0 "Mock Issue Title"

# Test 8: File + issue combined
run_test "File and issue combined" "" "$TMP_DIR/test-spec.md" "42" 0 "File content here"

# Test 9: All three combined
run_test "All three combined" "Plain text" "$TMP_DIR/test-spec.md" "42" 0 "Plain text"

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
