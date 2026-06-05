#!/usr/bin/env bash
set -euo pipefail

# Test suite for cleanup-feature.sh

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"
SCRIPT_FILE="$PROJECT_DIR/scripts/cleanup-feature.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASSED=0
FAILED=0

run_test() {
    local name="$1"
    local run_id="${2:-}"
    local expected_exit="${3:-0}"
    local expected_contains="${4:-}"
    local setup_fn="${5:-}"

    local work_dir="$TMP_DIR/${name// /_}_wd"
    mkdir -p "$work_dir"
    cd "$work_dir"

    # Run optional setup
    if [ -n "$setup_fn" ]; then
        "$setup_fn" "$work_dir"
    fi

    local actual_output
    local actual_exit=0

    set +e
    actual_output=$(bash "$SCRIPT_FILE" "$run_id" 2>&1)
    actual_exit=$?
    set -e

    if [ "$actual_exit" -ne "$expected_exit" ]; then
        echo "FAIL: $name — expected exit $expected_exit, got $actual_exit"
        echo "  Output: $actual_output"
        ((FAILED++)) || true
        cd "$TMP_DIR"
        return
    fi

    if [ -n "$expected_contains" ]; then
        if ! echo "$actual_output" | grep -q "$expected_contains"; then
            echo "FAIL: $name — expected output to contain '$expected_contains'"
            echo "  Actual output: $actual_output"
            ((FAILED++)) || true
            cd "$TMP_DIR"
            return
        fi
    fi

    echo "PASS: $name"
    ((PASSED++)) || true
    cd "$TMP_DIR"
}

setup_full_feature() {
    local wd="$1"
    mkdir -p "$wd/specs/001-my-feature"
    mkdir -p "$wd/.specify"
    echo '{"dir":"001-my-feature"}' > "$wd/.specify/feature.json"
    mkdir -p "$wd/.specify/workflows/runs/run-123"
    touch "$wd/specs/001-my-feature/spec.md"
    touch "$wd/specs/001-my-feature/review-findings.md"
    touch "$wd/.specify/workflows/runs/run-123/review-verdict.txt"
}

setup_no_feature_json() {
    local wd="$1"
    mkdir -p "$wd/specs/001-my-feature"
    mkdir -p "$wd/.specify/workflows/runs/run-456"
}

setup_installed_config() {
    local wd="$1"
    mkdir -p "$wd/.specify/presets/some-preset"
    mkdir -p "$wd/.specify/templates"
    mkdir -p "$wd/.specify/scripts/bash"
    mkdir -p "$wd/.specify/extensions"
    touch "$wd/.specify/extensions.yml"
    touch "$wd/.specify/init-options.json"
    mkdir -p "$wd/.specify/memory"
    mkdir -p "$wd/.specify/workflows/some-id"
    touch "$wd/.specify/workflows/some-id/workflow.yml"
    mkdir -p "$wd/.specify"
    echo '{"dir":"002-other"}' > "$wd/.specify/feature.json"
    mkdir -p "$wd/specs/002-other"
    mkdir -p "$wd/.specify/workflows/runs/run-789"
}

echo "=== Test Suite: cleanup-feature.sh ==="
echo ""

# Test 1: Missing run_id
run_test "Missing run_id" "" 1 "ERROR: Run ID is required" ""

# Test 2: Full cleanup
run_test "Full cleanup" "run-123" 0 "Removing feature directory" "setup_full_feature"

# Verify full cleanup actually removed things
work_dir="$TMP_DIR/Full_cleanup_wd"
if [ -d "$work_dir/specs/001-my-feature" ]; then
    echo "FAIL: Full cleanup — feature directory still exists"
    ((FAILED++)) || true
else
    echo "PASS: Full cleanup — feature directory removed"
    ((PASSED++)) || true
fi
if [ -f "$work_dir/.specify/feature.json" ]; then
    echo "FAIL: Full cleanup — feature.json still exists"
    ((FAILED++)) || true
else
    echo "PASS: Full cleanup — feature.json removed"
    ((PASSED++)) || true
fi
if [ -d "$work_dir/.specify/workflows/runs/run-123" ]; then
    echo "FAIL: Full cleanup — run state still exists"
    ((FAILED++)) || true
else
    echo "PASS: Full cleanup — run state removed"
    ((PASSED++)) || true
fi

# Test 3: No feature.json (graceful)
run_test "No feature.json" "run-456" 0 "Could not determine feature directory" "setup_no_feature_json"

# Test 4: Preserves installed config
run_test "Preserves installed config" "run-789" 0 "Removing feature directory" "setup_installed_config"

work_dir="$TMP_DIR/Preserves_installed_config_wd"
 preserved=0
for path in "$work_dir/.specify/presets" "$work_dir/.specify/templates" "$work_dir/.specify/scripts" "$work_dir/.specify/extensions" "$work_dir/.specify/extensions.yml" "$work_dir/.specify/init-options.json" "$work_dir/.specify/memory" "$work_dir/.specify/workflows/some-id/workflow.yml"; do
    if [ -e "$path" ]; then
        ((preserved++)) || true
    else
        echo "FAIL: Preserves installed config — $path was removed"
        ((FAILED++)) || true
    fi
done
if [ "$preserved" -eq 8 ]; then
    echo "PASS: Preserves installed config — all 8 installed config paths preserved"
    ((PASSED++)) || true
fi

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
