#!/usr/bin/env bash
set -euo pipefail

# commit-and-pr.sh — Commits all changes and creates a pull request from a GitHub issue
#
# Usage: commit-and-pr.sh <issue_number>
#
# Stages all remaining changes, commits with a message derived from the
# issue title, and opens a PR via gh CLI.
#
# Exit codes:
#   0 — Success (or no changes to commit)
#   1 — Error (missing issue, gh unavailable, issue fetch failed)

ISSUE="${1:-}"

if [ -z "$ISSUE" ]; then
    echo "ERROR: Issue number is required." >&2
    exit 1
fi

if ! command -v gh &> /dev/null; then
    echo "ERROR: GitHub CLI (gh) is required to create a PR. Install and authenticate with 'gh auth login'." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Fetch issue title
# ---------------------------------------------------------------------------
issue_title=$(gh issue view "$ISSUE" --json title --jq '.title' 2>&1) || {
    echo "ERROR: Failed to fetch issue #$ISSUE. Ensure the issue exists and gh is authenticated." >&2
    exit 1
}

commit_message="feat: ${issue_title} (#${ISSUE})"

# ---------------------------------------------------------------------------
# Stage and commit
# ---------------------------------------------------------------------------
git add -A

if git diff --cached --quiet; then
    echo "No changes to commit."
    exit 0
fi

git commit -m "$commit_message"

# ---------------------------------------------------------------------------
# Create pull request
# ---------------------------------------------------------------------------
pr_title="feat: ${issue_title}"
pr_body="Closes #${ISSUE}"

gh pr create --title "$pr_title" --body "$pr_body" --base main

echo "PR created for issue #$ISSUE"
