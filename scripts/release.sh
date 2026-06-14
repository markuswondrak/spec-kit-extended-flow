#!/usr/bin/env bash
set -euo pipefail

# release.sh — Full release automation: commit, merge to main, auto minor version bump, tag, push.
#
# Usage: release.sh
#
# The script:
#   1. Validates we are inside a git repository
#   2. Commits any uncommitted changes
#   3. Switches to main branch (creates it if missing)
#   4. Merges the current feature branch into main (if not already on main)
#   5. Reads current version from preset.yml
#   6. Computes next minor version (MAJOR.MINOR+1.0)
#   7. Updates version in preset.yml and extension.yml
#   8. Commits the version bump
#   9. Creates an annotated git tag (v<version>)
#   10. Pushes main and tags to origin
#
# Exit codes:
#   0 — Success
#   1 — Error (not a git repo, no preset.yml/extension.yml, merge conflict, etc.)

error() {
    echo "ERROR: $*" >&2
    exit 1
}

info() {
    echo "INFO: $*"
}

# ---------------------------------------------------------------------------
# Discover project root from git
# ---------------------------------------------------------------------------
PROJECT_DIR=""
if command -v git >/dev/null 2>&1; then
    PROJECT_DIR=$(git rev-parse --show-toplevel 2>/dev/null) || true
fi
[ -n "$PROJECT_DIR" ] || error "Not a git repository. Run from inside a git repository."
[ -d "$PROJECT_DIR/.git" ] || error "Not a git repository. Run from inside a git repository."

cd "$PROJECT_DIR"

PRESET_FILE="$PROJECT_DIR/preset.yml"
EXTENSION_FILE="$PROJECT_DIR/extension.yml"

# ---------------------------------------------------------------------------
# Preset / extension file checks
# ---------------------------------------------------------------------------
[ -f "$PRESET_FILE" ] || error "preset.yml not found at $PRESET_FILE"
[ -f "$EXTENSION_FILE" ] || error "extension.yml not found at $EXTENSION_FILE"

# ---------------------------------------------------------------------------
# Determine current branch
# ---------------------------------------------------------------------------
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || true)
[ -n "$CURRENT_BRANCH" ] || error "Could not determine current branch. Ensure you are on a branch (not detached HEAD)."

info "Current branch: $CURRENT_BRANCH"

# ---------------------------------------------------------------------------
# Commit any uncommitted changes
# ---------------------------------------------------------------------------
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    info "Uncommitted changes detected. Committing..."
    git add -A
    git commit -m "chore: prepare release"
else
    info "Working tree is clean."
fi

# ---------------------------------------------------------------------------
# Ensure main branch exists and switch to it
# ---------------------------------------------------------------------------
MAIN_BRANCH="main"
if ! git show-ref --verify --quiet "refs/heads/$MAIN_BRANCH"; then
    if git show-ref --verify --quiet "refs/heads/master"; then
        MAIN_BRANCH="master"
    else
        # No main or master — create main from current branch
        git branch "$MAIN_BRANCH"
    fi
fi

if [ "$CURRENT_BRANCH" != "$MAIN_BRANCH" ]; then
    info "Switching to $MAIN_BRANCH and merging $CURRENT_BRANCH..."
    git checkout "$MAIN_BRANCH"
    git merge --no-ff "$CURRENT_BRANCH" -m "chore(release): merge $CURRENT_BRANCH into $MAIN_BRANCH"
else
    info "Already on $MAIN_BRANCH."
fi

# ---------------------------------------------------------------------------
# Read current version and compute next minor
# ---------------------------------------------------------------------------
CURRENT_VERSION=$(grep -E '^  version:' "$PRESET_FILE" | sed -E 's/.*"([^"]+)".*/\1/')
[ -n "$CURRENT_VERSION" ] || error "Could not extract current version from preset.yml"

info "Current version: $CURRENT_VERSION"

# Parse semver: MAJOR.MINOR.PATCH
if [[ "$CURRENT_VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    MAJOR="${BASH_REMATCH[1]}"
    MINOR="${BASH_REMATCH[2]}"
    # PATCH="${BASH_REMATCH[3]}"
    NEXT_MINOR=$((MINOR + 1))
    VERSION="${MAJOR}.${NEXT_MINOR}.0"
else
    error "Invalid version format in preset.yml: '$CURRENT_VERSION'. Expected semver: MAJOR.MINOR.PATCH"
fi

info "Next version: $VERSION"

# ---------------------------------------------------------------------------
# Tag collision check
# ---------------------------------------------------------------------------
TAG="v$VERSION"
if git rev-parse "$TAG" >/dev/null 2>&1; then
    error "Tag already exists: $TAG"
fi

# ---------------------------------------------------------------------------
# Update preset.yml and extension.yml
# ---------------------------------------------------------------------------
sed -i -E "s/^(  version: )\"[^\"]+\"/\\1\"$VERSION\"/" "$PRESET_FILE"
sed -i -E "s/^(  version: )\"[^\"]+\"/\\1\"$VERSION\"/" "$EXTENSION_FILE"

UPDATED_VERSION=$(grep -E '^  version:' "$PRESET_FILE" | sed -E 's/.*"([^"]+)".*/\1/')
[ "$UPDATED_VERSION" = "$VERSION" ] || error "Failed to update version in preset.yml"

UPDATED_EXT_VERSION=$(grep -E '^  version:' "$EXTENSION_FILE" | sed -E 's/.*"([^"]+)".*/\1/')
[ "$UPDATED_EXT_VERSION" = "$VERSION" ] || error "Failed to update version in extension.yml"

# ---------------------------------------------------------------------------
# Commit and tag
# ---------------------------------------------------------------------------
git add "$PRESET_FILE" "$EXTENSION_FILE"
git commit -m "chore(release): bump version to $VERSION"
git tag -a "$TAG" -m "Release $TAG"

# ---------------------------------------------------------------------------
# Push
# ---------------------------------------------------------------------------
info "Pushing $MAIN_BRANCH and tags to origin..."
if git remote get-url origin >/dev/null 2>&1; then
    git push origin "$MAIN_BRANCH" --tags
else
    info "No remote 'origin' configured. Skipping push."
    info "To push manually, run: git push origin $MAIN_BRANCH --tags"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "========================================"
echo "  Released version $VERSION"
echo "  Commit: $(git rev-parse --short HEAD)"
echo "  Tag:    $TAG"
echo "  Branch: $MAIN_BRANCH"
echo "========================================"
