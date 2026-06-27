#!/usr/bin/env bash
set -euo pipefail

error() {
    echo "ERROR: $*" >&2
    exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DIST_DIR="${DIST_DIR:-$PROJECT_DIR/dist}"
PACKAGE_NAME="${PACKAGE_NAME:-spec-kit-extended-flow.zip}"
PACKAGE_PATH="$DIST_DIR/$PACKAGE_NAME"

command -v zip >/dev/null 2>&1 || error "zip command is required to build the preset package."

required_paths=(
    "preset.yml"
    "extension.yml"
    "workflows/workflow.yml"
    "workflows/bugfix-workflow.yml"
    "workflows/quick-flow.yml"
    "commands/speckit.extendedflow.documentation-init.md"
    "commands/speckit.extendedflow.documentation.md"
    "commands/speckit.extendedflow.review.md"
    "commands/speckit.extendedflow.project-init.md"
    "templates/documentation.md"
    "templates/review-findings.md"
    "scripts/resolve-spec.sh"
    "scripts/create-branch.sh"
    "scripts/extract-verdict.sh"
    "scripts/verify-spec.sh"
    "scripts/init-quick.sh"
    "scripts/resolve-pr-template.sh"
)

for path in "${required_paths[@]}"; do
    [ -e "$PROJECT_DIR/$path" ] || error "Required package path missing: $path"
done

for script in scripts/resolve-spec.sh scripts/create-branch.sh scripts/extract-verdict.sh scripts/verify-spec.sh scripts/init-quick.sh scripts/resolve-pr-template.sh; do
    [ -x "$PROJECT_DIR/$script" ] || error "Required script is not executable: $script"
done

tmp_dir="$(mktemp -d)"
tmp_zip="$tmp_dir/$PACKAGE_NAME"
stage_dir="$tmp_dir/package"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$stage_dir/commands" "$stage_dir/templates" "$stage_dir/scripts" "$stage_dir/workflows"

cp -p "$PROJECT_DIR/preset.yml" "$stage_dir/preset.yml"
cp -p "$PROJECT_DIR/extension.yml" "$stage_dir/extension.yml"
cp -p "$PROJECT_DIR/workflows/workflow.yml" "$stage_dir/workflows/workflow.yml"
cp -p "$PROJECT_DIR/workflows/bugfix-workflow.yml" "$stage_dir/workflows/bugfix-workflow.yml"
cp -p "$PROJECT_DIR/workflows/quick-flow.yml" "$stage_dir/workflows/quick-flow.yml"
cp -p "$PROJECT_DIR/README.md" "$stage_dir/README.md"
cp -p "$PROJECT_DIR"/commands/*.md "$stage_dir/commands/"
cp -p "$PROJECT_DIR"/templates/*.md "$stage_dir/templates/"
cp -p "$PROJECT_DIR/scripts/resolve-spec.sh" "$stage_dir/scripts/"
cp -p "$PROJECT_DIR/scripts/create-branch.sh" "$stage_dir/scripts/"
cp -p "$PROJECT_DIR/scripts/extract-verdict.sh" "$stage_dir/scripts/"
cp -p "$PROJECT_DIR/scripts/verify-spec.sh" "$stage_dir/scripts/"
cp -p "$PROJECT_DIR/scripts/init-quick.sh" "$stage_dir/scripts/"
cp -p "$PROJECT_DIR/scripts/resolve-pr-template.sh" "$stage_dir/scripts/"

package_entries=(preset.yml extension.yml workflows README.md commands templates scripts)
for license_file in LICENSE LICENSE.md; do
    if [ -f "$PROJECT_DIR/$license_file" ]; then
        cp -p "$PROJECT_DIR/$license_file" "$stage_dir/$license_file"
        package_entries+=("$license_file")
    fi
done

mkdir -p "$DIST_DIR"
rm -f "$PACKAGE_PATH"

(
    cd "$stage_dir"
    zip -qr "$tmp_zip" "${package_entries[@]}"
)

zip -T "$tmp_zip" >/dev/null || error "Generated ZIP failed integrity check."
mv "$tmp_zip" "$PACKAGE_PATH"

printf '%s\n' "$PACKAGE_PATH"
