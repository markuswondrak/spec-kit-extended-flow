#!/usr/bin/env bash
set -euo pipefail

# resolve-bug-context.sh — Resolve the bug directory created by speckit.bug.assess.
#
# Usage: resolve-bug-context.sh [slug]
#
# When a slug is supplied, verify that its assessment exists. Otherwise select
# the newest assessment directory. The selected directory is recorded in the
# feature pointer so the shared finish command can handle the bug flow.

BUGS_DIR=".specify/bugs"
REQUESTED_SLUG="${1:-}"
FEATURE_JSON=".specify/feature.json"

if [ ! -d "$BUGS_DIR" ]; then
    echo "ERROR: $BUGS_DIR not found. Has speckit.bug.assess run?" >&2
    exit 1
fi

bug_dir=""
if [ -n "$REQUESTED_SLUG" ]; then
    case "$REQUESTED_SLUG" in
        -*|*-|*/*|*..*|*[!a-z0-9-]*)
            echo "ERROR: Invalid bug slug: $REQUESTED_SLUG" >&2
            exit 1
            ;;
    esac
    bug_dir="$BUGS_DIR/$REQUESTED_SLUG"
    if [ ! -f "$bug_dir/assessment.md" ]; then
        echo "ERROR: Assessment not found for bug slug: $REQUESTED_SLUG" >&2
        exit 1
    fi
else
    newest_assessment=""
    newest_mtime=0
    for assessment in "$BUGS_DIR"/*/assessment.md; do
        [ -f "$assessment" ] || continue
        mtime=$(stat -c %Y "$assessment" 2>/dev/null || stat -f %m "$assessment" 2>/dev/null)
        if [ "$mtime" -ge "$newest_mtime" ]; then
            newest_mtime="$mtime"
            newest_assessment="$assessment"
        fi
    done

    if [ -z "$newest_assessment" ]; then
        echo "ERROR: No assessment.md found in $BUGS_DIR" >&2
        exit 1
    fi
    bug_dir=$(dirname "$newest_assessment")
fi

slug=$(basename "$bug_dir")
mkdir -p "$(dirname "$FEATURE_JSON")"
printf '{"feature_directory":"%s","type":"bug"}\n' "$bug_dir" > "$FEATURE_JSON"
printf '%s\n' "$slug"
