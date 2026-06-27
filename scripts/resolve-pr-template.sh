#!/usr/bin/env bash
set -euo pipefail

# resolve-pr-template.sh
# Resolves the path to a pull-request template in the downstream project.
# Searches standard GitHub template locations in order of precedence.
#
# Usage:
#   bash resolve-pr-template.sh
#
# Output (stdout):
#   Absolute or relative path to the first found PR template, or empty string if none exists.
#   Exit code is always 0 on success (found or not found). Exit 1 only on unexpected errors.

resolve_pr_template() {
    local repo_root
    repo_root="$(pwd)"

    # 1. Variant-based templates inside .github/PULL_REQUEST_TEMPLATE/
    #    We pick the first .md file alphabetically. Downstream projects can
    #    name templates like feature.md / fix.md / default.md.
    local variant_dir="$repo_root/.github/PULL_REQUEST_TEMPLATE"
    if [ -d "$variant_dir" ]; then
        local first_variant
        first_variant=$(find "$variant_dir" -maxdepth 1 -type f -name "*.md" | sort | head -n 1 || true)
        if [ -n "$first_variant" ]; then
            echo "$first_variant"
            return 0
        fi
    fi

    # 2. Single template at .github/PULL_REQUEST_TEMPLATE.md
    local single_template="$repo_root/.github/PULL_REQUEST_TEMPLATE.md"
    if [ -f "$single_template" ]; then
        echo "$single_template"
        return 0
    fi

    # 3. docs/PULL_REQUEST_TEMPLATE.md
    local docs_template="$repo_root/docs/PULL_REQUEST_TEMPLATE.md"
    if [ -f "$docs_template" ]; then
        echo "$docs_template"
        return 0
    fi

    # 4. Top-level PULL_REQUEST_TEMPLATE.md
    local top_template="$repo_root/PULL_REQUEST_TEMPLATE.md"
    if [ -f "$top_template" ]; then
        echo "$top_template"
        return 0
    fi

    # No template found
    echo ""
    return 0
}

resolve_pr_template
