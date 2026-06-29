#!/usr/bin/env bash
set -euo pipefail

# release-version.sh — Bumps the version in preset.yml and extension.yml and creates a git tag.
#
# Usage: release-version.sh <version>
#
# Arguments:
#   version — Semver version to release (e.g., 1.2.3 or v1.2.3)
#
# The script:
#   1. Validates the version format (semver: MAJOR.MINOR.PATCH)
#   2. Checks the working tree is clean
#   3. Updates the version field in preset.yml and extension.yml
#   4. Commits the version bump
#   5. Creates an annotated git tag (v<version>)
#
# Exit codes:
#   0 — Success
#   1 — Error (invalid version, not a git repo, dirty working tree,
#       version unchanged, tag already exists, etc.)

error() {
    echo "ERROR: $*" >&2
    exit 1
}

# ---------------------------------------------------------------------------
# Argument validation
# ---------------------------------------------------------------------------
[ "$#" -eq 1 ] || error "Usage: release-version.sh <version>"

VERSION_INPUT="$1"

# Validate semver format (allow optional v prefix in input)
if [[ "$VERSION_INPUT" =~ ^v?([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    VERSION="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
else
    error "Invalid version format: '$VERSION_INPUT'. Expected semver: MAJOR.MINOR.PATCH (e.g., 1.2.3 or v1.2.3)"
fi

# ---------------------------------------------------------------------------
# Discover project root from git
# ---------------------------------------------------------------------------
PROJECT_DIR=""
if command -v git >/dev/null 2>&1; then
    PROJECT_DIR=$(git rev-parse --show-toplevel 2>/dev/null) || true
fi
[ -n "$PROJECT_DIR" ] || error "Not a git repository. Run from inside a git repository."
[ -d "$PROJECT_DIR/.git" ] || error "Not a git repository. Run from inside a git repository."

PRESET_FILE="$PROJECT_DIR/preset.yml"
EXTENSION_FILE="$PROJECT_DIR/extension.yml"
BUNDLE_FILE="$PROJECT_DIR/bundle.yml"

# ---------------------------------------------------------------------------
# Git repository checks
# ---------------------------------------------------------------------------
if [ -n "$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null)" ]; then
    error "Working tree is not clean. Commit or stash changes before releasing."
fi

# ---------------------------------------------------------------------------
# Preset file checks
# ---------------------------------------------------------------------------
[ -f "$PRESET_FILE" ] || error "preset.yml not found at $PRESET_FILE"
[ -f "$EXTENSION_FILE" ] || error "extension.yml not found at $EXTENSION_FILE"
[ -f "$BUNDLE_FILE" ] || error "bundle.yml not found at $BUNDLE_FILE"

CURRENT_VERSION=$(grep -E '^  version:' "$PRESET_FILE" | sed -E 's/.*"([^"]+)".*/\1/')
[ -n "$CURRENT_VERSION" ] || error "Could not extract current version from preset.yml"

if [ "$CURRENT_VERSION" = "$VERSION" ]; then
    error "Version is already $VERSION. Nothing to release."
fi

# ---------------------------------------------------------------------------
# Tag collision check
# ---------------------------------------------------------------------------
TAG="v$VERSION"
if git -C "$PROJECT_DIR" rev-parse "$TAG" >/dev/null 2>&1; then
    error "Tag already exists: $TAG"
fi

# ---------------------------------------------------------------------------
# Update preset.yml and extension.yml
# ---------------------------------------------------------------------------
sed -i -E "s/^(  version: )\"[^\"]+\"/\\1\"$VERSION\"/" "$PRESET_FILE"
sed -i -E "s/^(  version: )\"[^\"]+\"/\\1\"$VERSION\"/" "$EXTENSION_FILE"
sed -i -E "s/^(  version: )\"[^\"]+\"/\\1\"$VERSION\"/" "$BUNDLE_FILE"

UPDATED_VERSION=$(grep -E '^  version:' "$PRESET_FILE" | sed -E 's/.*"([^"]+)".*/\1/')
[ "$UPDATED_VERSION" = "$VERSION" ] || error "Failed to update version in preset.yml"

UPDATED_EXT_VERSION=$(grep -E '^  version:' "$EXTENSION_FILE" | sed -E 's/.*"([^"]+)".*/\1/')
[ "$UPDATED_EXT_VERSION" = "$VERSION" ] || error "Failed to update version in extension.yml"

UPDATED_BUNDLE_VERSION=$(grep -E '^  version:' "$BUNDLE_FILE" | sed -E 's/.*"([^"]+)".*/\1/')
[ "$UPDATED_BUNDLE_VERSION" = "$VERSION" ] || error "Failed to update version in bundle.yml"

# ---------------------------------------------------------------------------
# Commit and tag
# ---------------------------------------------------------------------------
git -C "$PROJECT_DIR" add "$PRESET_FILE" "$EXTENSION_FILE" "$BUNDLE_FILE"
git -C "$PROJECT_DIR" commit -m "chore(release): bump version to $VERSION"
git -C "$PROJECT_DIR" tag -a "$TAG" -m "Release $TAG"

echo "Released version $VERSION"
echo "  Commit: $(git -C "$PROJECT_DIR" rev-parse --short HEAD)"
echo "  Tag:    $TAG"
echo ""
echo "Next steps:"
echo "  git push origin main --tags"
