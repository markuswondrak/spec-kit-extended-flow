#!/usr/bin/env bash
set -euo pipefail

# Test suite for check-converge.sh
# Verifies deterministic detection of speckit.converge appending new tasks.

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"
SCRIPT_FILE="$PROJECT_DIR/scripts/check-converge.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASSED=0
FAILED=0

# Helper: create a test project structure with a tasks.md
create_test_project() {
    local test_root="$1"
    local feature_dir="${2:-001-test-feature}"
    mkdir -p "$test_root/specs/$feature_dir"
    mkdir -p "$test_root/.specify/workflows/runs/test-run"
    cat > "$test_root/.specify/feature.json" << EOF
{"feature_directory": "specs/$feature_dir"}
EOF
    cat > "$test_root/specs/$feature_dir/tasks.md" << 'EOF'
# Tasks

- [x] T001 First task
- [ ] T002 Second task
EOF
}

echo "=== Test Suite: check-converge.sh ==="
echo ""

# Test 1: snapshot then unchanged check reports CONVERGED
test_root="$TMP_DIR/test_converged"
create_test_project "$test_root"
(cd "$test_root" && bash "$SCRIPT_FILE" snapshot "test-run" > /dev/null)
output=$(cd "$test_root" && bash "$SCRIPT_FILE" check "test-run" 2>&1) && exit_code=$? || exit_code=$?
if [ "$exit_code" -eq 0 ] && [ "$output" = "CONVERGED" ]; then
    echo "PASS: Unchanged tasks.md reports CONVERGED"
    ((PASSED++)) || true
else
    echo "FAIL: Unchanged tasks.md — exit=$exit_code output=$output"
    ((FAILED++)) || true
fi

# Test 2: appended Convergence phase reports TASKS_APPENDED
test_root="$TMP_DIR/test_appended"
create_test_project "$test_root"
(cd "$test_root" && bash "$SCRIPT_FILE" snapshot "test-run" > /dev/null)
cat >> "$test_root/specs/001-test-feature/tasks.md" << 'EOF'

## Phase 2: Convergence

- [ ] T003 Remaining work per FR-003 (missing)
EOF
output=$(cd "$test_root" && bash "$SCRIPT_FILE" check "test-run" 2>&1) && exit_code=$? || exit_code=$?
if [ "$exit_code" -eq 0 ] && [ "$output" = "TASKS_APPENDED" ]; then
    echo "PASS: Appended convergence phase reports TASKS_APPENDED"
    ((PASSED++)) || true
else
    echo "FAIL: Appended convergence phase — exit=$exit_code output=$output"
    ((FAILED++)) || true
fi

# Test 3: State artifact written
test_root="$TMP_DIR/test_artifact"
create_test_project "$test_root"
(cd "$test_root" && bash "$SCRIPT_FILE" snapshot "test-run" > /dev/null)
(cd "$test_root" && bash "$SCRIPT_FILE" check "test-run" > /dev/null)
if [ -f "$test_root/.specify/workflows/runs/test-run/converge-state.txt" ]; then
    state=$(cat "$test_root/.specify/workflows/runs/test-run/converge-state.txt")
    if [ "$state" = "CONVERGED" ]; then
        echo "PASS: Run artifact written with verdict"
        ((PASSED++)) || true
    else
        echo "FAIL: Run artifact has wrong content: $state"
        ((FAILED++)) || true
    fi
else
    echo "FAIL: Run artifact not written"
    ((FAILED++)) || true
fi

# Test 4: Missing run_id errors
test_root="$TMP_DIR/test_missing_runid"
create_test_project "$test_root"
output=$(cd "$test_root" && bash "$SCRIPT_FILE" snapshot 2>&1) && exit_code=$? || exit_code=$?
if [ "$exit_code" -eq 1 ]; then
    echo "PASS: Missing run_id errors"
    ((PASSED++)) || true
else
    echo "FAIL: Missing run_id — expected exit 1, got $exit_code"
    ((FAILED++)) || true
fi

# Test 5: Invalid mode errors
test_root="$TMP_DIR/test_invalid_mode"
create_test_project "$test_root"
output=$(cd "$test_root" && bash "$SCRIPT_FILE" bogus "test-run" 2>&1) && exit_code=$? || exit_code=$?
if [ "$exit_code" -eq 1 ]; then
    echo "PASS: Invalid mode errors"
    ((PASSED++)) || true
else
    echo "FAIL: Invalid mode — expected exit 1, got $exit_code"
    ((FAILED++)) || true
fi

# Test 6: check without snapshot errors
test_root="$TMP_DIR/test_no_snapshot"
create_test_project "$test_root"
output=$(cd "$test_root" && bash "$SCRIPT_FILE" check "test-run" 2>&1) && exit_code=$? || exit_code=$?
if [ "$exit_code" -eq 1 ]; then
    echo "PASS: check without snapshot errors"
    ((PASSED++)) || true
else
    echo "FAIL: check without snapshot — expected exit 1, got $exit_code"
    ((FAILED++)) || true
fi

# Test 7: Missing feature.json errors
test_root="$TMP_DIR/test_missing_json"
mkdir -p "$test_root/.specify/workflows/runs/test-run"
output=$(cd "$test_root" && bash "$SCRIPT_FILE" snapshot "test-run" 2>&1) && exit_code=$? || exit_code=$?
if [ "$exit_code" -eq 1 ]; then
    echo "PASS: Missing feature.json errors"
    ((PASSED++)) || true
else
    echo "FAIL: Missing feature.json — expected exit 1, got $exit_code"
    ((FAILED++)) || true
fi

# Test 8: Missing tasks.md errors
test_root="$TMP_DIR/test_missing_tasks"
create_test_project "$test_root"
rm "$test_root/specs/001-test-feature/tasks.md"
output=$(cd "$test_root" && bash "$SCRIPT_FILE" snapshot "test-run" 2>&1) && exit_code=$? || exit_code=$?
if [ "$exit_code" -eq 1 ]; then
    echo "PASS: Missing tasks.md errors"
    ((PASSED++)) || true
else
    echo "FAIL: Missing tasks.md — expected exit 1, got $exit_code"
    ((FAILED++)) || true
fi

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
