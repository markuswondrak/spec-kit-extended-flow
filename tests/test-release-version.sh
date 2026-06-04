#!/usr/bin/env bash
set -euo pipefail

# Test suite for release-version.sh
# Validates version bumping, git tagging, and error handling.

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"
SCRIPT_FILE="$PROJECT_DIR/scripts/release-version.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASSED=0
FAILED=0

pass() {
    echo "PASS: $1"
    ((PASSED++)) || true
}

fail() {
    echo "FAIL: $1"
    if [ "${2:-}" != "" ]; then
        echo "  $2"
    fi
    ((FAILED++)) || true
}

# Helper: create a temporary git repo with a preset.yml
setup_git_repo() {
    local repo_dir="$1"
    local version="${2:-0.1.0}"

    mkdir -p "$repo_dir"
    cd "$repo_dir"
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"

    cat > preset.yml << EOF
schema_version: "1.0"

preset:
  id: "test-preset"
  name: "Test Preset"
  version: "$version"
  description: "A test preset."
EOF

    git add preset.yml
    git commit -m "Initial commit"
    cd - >/dev/null
}

# Helper: run the release script from within a repo and capture exit code + output
run_release() {
    local repo_dir="$1"
    shift
    local output
    local exit_code=0
    set +e
    output=$(cd "$repo_dir" && bash "$SCRIPT_FILE" "$@" 2>&1)
    exit_code=$?
    set -e
    echo "$output"
    return $exit_code
}

echo "=== Test Suite: release-version.sh ==="
echo ""

# --- Precondition checks ---

echo "--- Precondition checks ---"

if [ -f "$SCRIPT_FILE" ]; then
    pass "Script exists"
else
    fail "Script exists" "File not found: $SCRIPT_FILE"
fi

if [ -x "$SCRIPT_FILE" ]; then
    pass "Script is executable"
else
    fail "Script is executable" "File not executable: $SCRIPT_FILE"
fi

# --- Error case tests ---

echo ""
echo "--- Error case tests ---"

# Test: missing argument
mkdir -p "$TMP_DIR/repo-missing"
output=$(run_release "$TMP_DIR/repo-missing" 2>&1) || true
if echo "$output" | grep -q "Usage:"; then
    pass "Missing argument shows usage"
else
    fail "Missing argument shows usage" "Output: $output"
fi

# Test: invalid version format
REPO="$TMP_DIR/repo-invalid"
setup_git_repo "$REPO" "0.1.0"
output=$(run_release "$REPO" "not-a-version" 2>&1) || true
if echo "$output" | grep -q "Invalid version format"; then
    pass "Invalid version format rejected"
else
    fail "Invalid version format rejected" "Output: $output"
fi

# Test: non-git directory
REPO="$TMP_DIR/not-a-repo"
mkdir -p "$REPO"
cp "$PROJECT_DIR/preset.yml" "$REPO/preset.yml"
output=$(cd "$REPO" && bash "$SCRIPT_FILE" "1.0.0" 2>&1) || true
if echo "$output" | grep -q "Not a git repository"; then
    pass "Non-git directory rejected"
else
    fail "Non-git directory rejected" "Output: $output"
fi

# Test: dirty working tree
REPO="$TMP_DIR/repo-dirty"
setup_git_repo "$REPO" "0.1.0"
echo "dirty" > "$REPO/dirty.txt"
output=$(run_release "$REPO" "1.0.0" 2>&1) || true
if echo "$output" | grep -q "Working tree is not clean"; then
    pass "Dirty working tree rejected"
else
    fail "Dirty working tree rejected" "Output: $output"
fi

# Test: version already at target
REPO="$TMP_DIR/repo-same"
setup_git_repo "$REPO" "1.0.0"
output=$(run_release "$REPO" "1.0.0" 2>&1) || true
if echo "$output" | grep -q "Version is already"; then
    pass "Same version rejected"
else
    fail "Same version rejected" "Output: $output"
fi

# Test: tag already exists
REPO="$TMP_DIR/repo-tag-exists"
setup_git_repo "$REPO" "0.1.0"
git -C "$REPO" tag -a "v1.0.0" -m "Existing tag"
output=$(run_release "$REPO" "1.0.0" 2>&1) || true
if echo "$output" | grep -q "Tag already exists"; then
    pass "Existing tag rejected"
else
    fail "Existing tag rejected" "Output: $output"
fi

# --- Success case tests ---

echo ""
echo "--- Success case tests ---"

# Test: successful release with plain semver
REPO="$TMP_DIR/repo-success"
setup_git_repo "$REPO" "0.1.0"
output=$(run_release "$REPO" "1.0.0" 2>&1)
if [ $? -eq 0 ]; then
    pass "Successful release exits 0"
else
    fail "Successful release exits 0" "Output: $output"
fi

# Verify preset.yml was updated
updated_version=$(grep -E '^  version:' "$REPO/preset.yml" | sed -E 's/.*"([^"]+)".*/\1/')
if [ "$updated_version" = "1.0.0" ]; then
    pass "Version updated in preset.yml"
else
    fail "Version updated in preset.yml" "Expected 1.0.0, got $updated_version"
fi

# Verify commit was created
if git -C "$REPO" log --oneline -1 | grep -q "bump version to 1.0.0"; then
    pass "Version bump commit created"
else
    fail "Version bump commit created"
fi

# Verify tag was created
if git -C "$REPO" tag -l "v1.0.0" | grep -q "v1.0.0"; then
    pass "Git tag v1.0.0 created"
else
    fail "Git tag v1.0.0 created"
fi

# Test: successful release with v-prefix input
REPO="$TMP_DIR/repo-vprefix"
setup_git_repo "$REPO" "0.1.0"
output=$(run_release "$REPO" "v2.0.0" 2>&1)
if [ $? -eq 0 ]; then
    pass "v-prefix input accepted"
else
    fail "v-prefix input accepted" "Output: $output"
fi

updated_version=$(grep -E '^  version:' "$REPO/preset.yml" | sed -E 's/.*"([^"]+)".*/\1/')
if [ "$updated_version" = "2.0.0" ]; then
    pass "v-prefix stripped from preset.yml version"
else
    fail "v-prefix stripped from preset.yml version" "Expected 2.0.0, got $updated_version"
fi

if git -C "$REPO" tag -l "v2.0.0" | grep -q "v2.0.0"; then
    pass "Git tag v2.0.0 created from v-prefix input"
else
    fail "Git tag v2.0.0 created from v-prefix input"
fi

# Test: patch version bump
REPO="$TMP_DIR/repo-patch"
setup_git_repo "$REPO" "1.0.0"
output=$(run_release "$REPO" "1.0.1" 2>&1)
if [ $? -eq 0 ]; then
    pass "Patch version bump succeeds"
else
    fail "Patch version bump succeeds" "Output: $output"
fi

# Test: minor version bump
REPO="$TMP_DIR/repo-minor"
setup_git_repo "$REPO" "1.0.0"
output=$(run_release "$REPO" "1.1.0" 2>&1)
if [ $? -eq 0 ]; then
    pass "Minor version bump succeeds"
else
    fail "Minor version bump succeeds" "Output: $output"
fi

# Test: major version bump
REPO="$TMP_DIR/repo-major"
setup_git_repo "$REPO" "1.0.0"
output=$(run_release "$REPO" "2.0.0" 2>&1)
if [ $? -eq 0 ]; then
    pass "Major version bump succeeds"
else
    fail "Major version bump succeeds" "Output: $output"
fi

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
