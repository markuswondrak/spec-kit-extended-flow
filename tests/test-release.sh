#!/usr/bin/env bash
set -euo pipefail

# Test suite for release.sh
# Validates full release flow: commit, merge to main, auto minor version bump, tag.

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"
SCRIPT_FILE="$PROJECT_DIR/scripts/release.sh"
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

# Helper: create a temporary git repo with main branch and preset.yml / extension.yml
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

    cat > extension.yml << EOF
schema_version: "1.0"

extension:
  id: test-extension
  name: "Test Extension"
  version: "$version"
  description: "A test extension."
EOF

    git add preset.yml extension.yml
    git commit -m "Initial commit"
    git checkout -b main
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

echo "=== Test Suite: release.sh ==="
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

# Test: non-git directory
REPO="$TMP_DIR/not-a-repo"
mkdir -p "$REPO"
cp "$PROJECT_DIR/preset.yml" "$REPO/preset.yml"
output=$(cd "$REPO" && bash "$SCRIPT_FILE" 2>&1) || true
if echo "$output" | grep -q "Not a git repository"; then
    pass "Non-git directory rejected"
else
    fail "Non-git directory rejected" "Output: $output"
fi

# --- Success case tests ---

echo ""
echo "--- Success case tests ---"

# Test: on main branch with clean tree, auto minor bump
REPO="$TMP_DIR/repo-main-clean"
setup_git_repo "$REPO" "0.1.0"
output=$(run_release "$REPO" 2>&1)
if [ $? -eq 0 ]; then
    pass "Clean main branch release exits 0"
else
    fail "Clean main branch release exits 0" "Output: $output"
fi

# Verify preset.yml was bumped to next minor
updated_version=$(grep -E '^  version:' "$REPO/preset.yml" | sed -E 's/.*"([^"]+)".*/\1/')
if [ "$updated_version" = "0.2.0" ]; then
    pass "Version auto-bumped to next minor in preset.yml"
else
    fail "Version auto-bumped to next minor in preset.yml" "Expected 0.2.0, got $updated_version"
fi

# Verify extension.yml was also updated
updated_ext_version=$(grep -E '^  version:' "$REPO/extension.yml" | sed -E 's/.*"([^"]+)".*/\1/')
if [ "$updated_ext_version" = "0.2.0" ]; then
    pass "Version auto-bumped to next minor in extension.yml"
else
    fail "Version auto-bumped to next minor in extension.yml" "Expected 0.2.0, got $updated_ext_version"
fi

# Verify commit was created
if git -C "$REPO" log --oneline -1 | grep -q "bump version to 0.2.0"; then
    pass "Version bump commit created"
else
    fail "Version bump commit created"
fi

# Verify tag was created
if git -C "$REPO" tag -l "v0.2.0" | grep -q "v0.2.0"; then
    pass "Git tag v0.2.0 created"
else
    fail "Git tag v0.2.0 created"
fi

# Test: on feature branch with uncommitted changes
REPO="$TMP_DIR/repo-feature-dirty"
setup_git_repo "$REPO" "1.0.0"
git -C "$REPO" checkout -b feature/test
echo "new feature" > "$REPO/feature.txt"
git -C "$REPO" add feature.txt
# Intentionally not committing — script should commit it
output=$(run_release "$REPO" 2>&1)
if [ $? -eq 0 ]; then
    pass "Feature branch with uncommitted changes release exits 0"
else
    fail "Feature branch with uncommitted changes release exits 0" "Output: $output"
fi

# Verify we are on main after release
branch=$(git -C "$REPO" branch --show-current)
if [ "$branch" = "main" ]; then
    pass "Switched to main branch after release"
else
    fail "Switched to main branch after release" "Current branch: $branch"
fi

# Verify feature branch was merged into main (commit message is "chore: prepare release")
if git -C "$REPO" log --oneline main | grep -q "prepare release"; then
    pass "Feature branch merged into main"
else
    fail "Feature branch merged into main"
fi

# Verify version bumped to next minor (1.0.0 -> 1.1.0)
updated_version=$(grep -E '^  version:' "$REPO/preset.yml" | sed -E 's/.*"([^"]+)".*/\1/')
if [ "$updated_version" = "1.1.0" ]; then
    pass "Version auto-bumped to 1.1.0 on feature branch release"
else
    fail "Version auto-bumped to 1.1.0 on feature branch release" "Expected 1.1.0, got $updated_version"
fi

# Verify tag v1.1.0 exists
if git -C "$REPO" tag -l "v1.1.0" | grep -q "v1.1.0"; then
    pass "Git tag v1.1.0 created from feature branch"
else
    fail "Git tag v1.1.0 created from feature branch"
fi

# Test: patch version bump (0.1.1 -> 0.1.2)
REPO="$TMP_DIR/repo-patch"
setup_git_repo "$REPO" "0.1.1"
output=$(run_release "$REPO" 2>&1)
updated_version=$(grep -E '^  version:' "$REPO/preset.yml" | sed -E 's/.*"([^"]+)".*/\1/')
if [ "$updated_version" = "0.2.0" ]; then
    pass "Patch base still bumps minor (0.1.1 -> 0.2.0)"
else
    fail "Patch base still bumps minor (0.1.1 -> 0.2.0)" "Expected 0.2.0, got $updated_version"
fi

# Test: major version bump (2.0.0 -> 2.1.0)
REPO="$TMP_DIR/repo-major"
setup_git_repo "$REPO" "2.0.0"
output=$(run_release "$REPO" 2>&1)
updated_version=$(grep -E '^  version:' "$REPO/preset.yml" | sed -E 's/.*"([^"]+)".*/\1/')
if [ "$updated_version" = "2.1.0" ]; then
    pass "Major base bumps minor (2.0.0 -> 2.1.0)"
else
    fail "Major base bumps minor (2.0.0 -> 2.1.0)" "Expected 2.1.0, got $updated_version"
fi

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
