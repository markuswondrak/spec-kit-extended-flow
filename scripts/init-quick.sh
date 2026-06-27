#!/usr/bin/env bash
set -euo pipefail

# init-quick.sh — Initializes a Quick Flow feature directory and feature.json pointer.
#
# Usage: init-quick.sh <issue> <spec_text>
#
# Arguments:
#   issue     — GitHub issue number (optional, may be empty string)
#   spec_text — Plain-text specification (optional, may be empty string)
#
# At least one argument must be non-empty. Creates a feature directory under
# specs/ and writes .specify/feature.json with type "quick".
#
# Directory naming:
#   With issue:    specs/<issue>-quick-<slug>/   (slug from issue title via gh)
#   Without issue: specs/quick-<slug>/           (slug from spec text, truncated)
#
# Exit codes:
#   0 — Success
#   1 — Error (no inputs, gh unavailable, issue fetch failed, directory exists)

ISSUE="${1:-}"
SPEC_TEXT="${2:-}"

if [ -z "$ISSUE" ] && [ -z "$SPEC_TEXT" ]; then
    echo "ERROR: At least one of issue or spec text is required." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Slugify helper
# ---------------------------------------------------------------------------
slugify() {
    local input="$1"
    local max_len="${2:-50}"

    # Lowercase, replace non-alphanumeric with hyphens, collapse, trim
    local slug
    slug=$(echo "$input" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//')

    # Truncate
    if [ "${#slug}" -gt "$max_len" ]; then
        slug="${slug:0:$max_len}"
        slug=$(echo "$slug" | sed 's/-*$//')
    fi

    echo "$slug"
}

# ---------------------------------------------------------------------------
# Determine directory name
# ---------------------------------------------------------------------------
dir_name=""

if [ -n "$ISSUE" ]; then
    # Fetch issue title for slug
    if ! command -v gh &> /dev/null; then
        echo "ERROR: GitHub CLI (gh) is required to create a directory from an issue. Install and authenticate with 'gh auth login'." >&2
        exit 1
    fi

    issue_title=$(gh issue view "$ISSUE" --json title --jq '.title' 2>&1) || {
        echo "ERROR: Failed to fetch issue #$ISSUE. Ensure the issue exists and gh is authenticated." >&2
        exit 1
    }

    slug=$(slugify "$issue_title" 50)
    dir_name="${ISSUE}-quick-${slug}"
else
    # Derive slug from spec text (first 30 chars)
    truncated="${SPEC_TEXT:0:30}"
    slug=$(slugify "$truncated" 30)

    if [ -z "$slug" ]; then
        slug="change"
    fi

    dir_name="quick-${slug}"
fi

FEATURE_DIR="specs/${dir_name}"

# ---------------------------------------------------------------------------
# Check for existing directory
# ---------------------------------------------------------------------------
if [ -d "$FEATURE_DIR" ]; then
    echo "ERROR: Feature directory already exists: $FEATURE_DIR" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Create directory and feature.json
# ---------------------------------------------------------------------------
mkdir -p "$FEATURE_DIR"
mkdir -p .specify

cat > .specify/feature.json << EOF
{"feature_directory": "$FEATURE_DIR", "type": "quick"}
EOF

echo "$FEATURE_DIR"
