#!/usr/bin/env bash
set -euo pipefail

# create-branch.sh — Creates a feature branch from a GitHub issue
#
# Usage: create-branch.sh <issue_number>
#
# Fetches the issue title via gh CLI, slugifies it, creates a git branch
# named feature/<issue>-<slug>, and outputs the branch name to stdout.
#
# Exit codes:
#   0 — Success
#   1 — Error (missing issue, gh unavailable, issue fetch failed,
#       or branch already exists)

ISSUE="${1:-}"

if [ -z "$ISSUE" ]; then
    echo "ERROR: Issue number is required." >&2
    exit 1
fi

if ! command -v gh &> /dev/null; then
    echo "ERROR: GitHub CLI (gh) is required to create a branch from an issue. Install and authenticate with 'gh auth login'." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Fetch issue title
# ---------------------------------------------------------------------------
issue_title=$(gh issue view "$ISSUE" --json title --jq '.title' 2>&1) || {
    echo "ERROR: Failed to fetch issue #$ISSUE. Ensure the issue exists and gh is authenticated." >&2
    exit 1
}

# ---------------------------------------------------------------------------
# Slugify the title
# ---------------------------------------------------------------------------
# Lowercase, replace non-alphanumeric with hyphens, collapse multiple
# hyphens, and trim leading/trailing hyphens.
slug=$(echo "$issue_title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//')

# Limit slug length to avoid overly long branch names
if [ "${#slug}" -gt 50 ]; then
    slug="${slug:0:50}"
    slug=$(echo "$slug" | sed 's/-*$//')
fi

branch_name="feature/${ISSUE}-${slug}"

# ---------------------------------------------------------------------------
# Create branch
# ---------------------------------------------------------------------------
if git show-ref --verify --quiet "refs/heads/$branch_name" 2>/dev/null; then
    echo "ERROR: Branch '$branch_name' already exists." >&2
    exit 1
fi

git checkout -b "$branch_name"

echo "$branch_name"
