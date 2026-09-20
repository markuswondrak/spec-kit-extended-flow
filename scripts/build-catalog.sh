#!/usr/bin/env bash
set -euo pipefail

# build-catalog.sh — Build the project-owned HTTPS catalog artifacts.
#
# Produces deterministic component archives under catalog/artifacts/, one per
# installable component, plus the manifests that reference them. Versions are
# read from the component manifests, so a version bump only needs a rerun of
# this script (the matching catalog JSON download URLs are updated in place).
#
# The catalogs are integration-agnostic and install-allowed: this is the
# sanctioned mechanism for a repository to serve its own components over HTTPS
# (raw.githubusercontent.com) without --dev symlinks or a local HTTP server.

error() {
    echo "ERROR: $*" >&2
    exit 1
}

info() {
    echo "==> $*"
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/catalog/artifacts"

command -v zip >/dev/null 2>&1 || error "'zip' command is required to build catalog artifacts."

# Read the first 'version:' scalar from a manifest (skips 'speckit_version:').
manifest_version() {
    grep -m1 -E '^  version:' "$1" |
        sed -E 's/.*"([^"]+)".*/\1/' |
        tr -d '[:space:]'
}

EXT_VERSION="$(manifest_version "$ROOT/extension.yml")"
PRESET_VERSION="$(manifest_version "$ROOT/preset.yml")"
BUNDLE_VERSION="$(manifest_version "$ROOT/bundle.yml")"

[ -n "$EXT_VERSION" ] || error "Could not read version from extension.yml"
[ -n "$PRESET_VERSION" ] || error "Could not read version from preset.yml"
[ -n "$BUNDLE_VERSION" ] || error "Could not read version from bundle.yml"

EXT_ARTIFACT="extendedflow-$EXT_VERSION.zip"
PRESET_ARTIFACT="spec-kit-extended-flow-$PRESET_VERSION.zip"
BUNDLE_ARTIFACT="spec-kit-extended-flow-bundle-$BUNDLE_VERSION.zip"

RUNTIME_SCRIPTS=(
    resolve-spec.sh
    create-branch.sh
    check-converge.sh
    extract-verdict.sh
    resolve-bug-context.sh
    check-bug-verdict.sh
    verify-spec.sh
    init-quick.sh
    resolve-pr-template.sh
)

# --- Stage each component in an isolated tree so archives have a clean root. ---
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

EXT_STAGE="$tmp_dir/extension"
PRESET_STAGE="$tmp_dir/preset"
BUNDLE_STAGE="$tmp_dir/bundle"
mkdir -p "$EXT_STAGE/commands" "$PRESET_STAGE/templates" "$PRESET_STAGE/scripts" \
    "$PRESET_STAGE/commands" "$BUNDLE_STAGE"

# Extension: manifest + its namespaced commands (not the preset runtime preamble).
cp -p "$ROOT/extension.yml" "$EXT_STAGE/extension.yml"
for cmd in "$ROOT"/commands/speckit.extendedflow.*.md; do
    [ -e "$cmd" ] || error "No extension commands found under commands/"
    cp -p "$cmd" "$EXT_STAGE/commands/"
done

# Preset: manifest + templates + scripts + the unattended runtime preamble.
cp -p "$ROOT/preset.yml" "$PRESET_STAGE/preset.yml"
cp -p "$ROOT"/templates/*.md "$PRESET_STAGE/templates/"
for script in "${RUNTIME_SCRIPTS[@]}"; do
    [ -f "$ROOT/scripts/$script" ] || error "Missing runtime script: scripts/$script"
    cp -p "$ROOT/scripts/$script" "$PRESET_STAGE/scripts/"
done
cp -p "$ROOT/commands/workflow-runtime.md" "$PRESET_STAGE/commands/workflow-runtime.md"

# Bundle: manifest + README (the artifact contract wants a human-facing README).
cp -p "$ROOT/bundle.yml" "$BUNDLE_STAGE/bundle.yml"
cp -p "$ROOT/README.md" "$BUNDLE_STAGE/README.md"

# --- Build archives (zip preserves the executable bit on scripts). ---
mkdir -p "$OUT"
rm -f "$OUT/$EXT_ARTIFACT" "$OUT/$PRESET_ARTIFACT" "$OUT/$BUNDLE_ARTIFACT"

info "Building extension archive: $EXT_ARTIFACT"
(cd "$EXT_STAGE" && zip -qr "$OUT/$EXT_ARTIFACT" .)

info "Building preset archive: $PRESET_ARTIFACT"
(cd "$PRESET_STAGE" && zip -qr "$OUT/$PRESET_ARTIFACT" .)

info "Building bundle archive: $BUNDLE_ARTIFACT"
(cd "$BUNDLE_STAGE" && zip -qr "$OUT/$BUNDLE_ARTIFACT" .)

for artifact in "$OUT/$EXT_ARTIFACT" "$OUT/$PRESET_ARTIFACT" "$OUT/$BUNDLE_ARTIFACT"; do
    zip -T "$artifact" >/dev/null || error "Generated archive failed integrity check: $artifact"
done

# --- Keep the catalog version fields and download URLs in lockstep. ---
update_catalog_entry() {
    local catalog="$1"
    local section="$2"
    local component_id="$3"
    local version="$4"
    local artifact="$5"
    python3 - "$catalog" "$section" "$component_id" "$version" "$artifact" <<'PY'
import json
import sys

catalog_path, section, component_id, version, artifact = sys.argv[1:6]
with open(catalog_path, encoding="utf-8") as fh:
    data = json.load(fh)

entries = data.get(section, {})
if not isinstance(entries, dict) or component_id not in entries:
    raise SystemExit(
        f"ERROR: catalog entry '{section}.{component_id}' not found in {catalog_path}"
    )

entry = entries[component_id]
entry["version"] = version
entry["download_url"] = (
    "https://github.com/markuswondrak/spec-kit-extended-flow/releases/download/"
    f"v{version}/{artifact}"
)

with open(catalog_path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
PY
}

info "Updating catalog version pins"
update_catalog_entry "$ROOT/catalog/extension-catalog.json" "extensions" "extendedflow" "$EXT_VERSION" "$EXT_ARTIFACT"
update_catalog_entry "$ROOT/catalog/preset-catalog.json" "presets" "spec-kit-extended-flow" "$PRESET_VERSION" "$PRESET_ARTIFACT"
update_catalog_entry "$ROOT/catalog/bundle-catalog.json" "bundles" "spec-kit-extended-flow" "$BUNDLE_VERSION" "$BUNDLE_ARTIFACT"

echo ""
echo "Built catalog artifacts:"
ls -1 "$OUT"
