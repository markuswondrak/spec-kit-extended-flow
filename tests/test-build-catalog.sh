#!/usr/bin/env bash
set -euo pipefail

# Test suite: verify catalog artifacts are buildable and well-formed.

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"
SCRIPT_FILE="$PROJECT_DIR/scripts/build-catalog.sh"
CATALOG_DIR="$PROJECT_DIR/catalog"
ARTIFACTS_DIR="$CATALOG_DIR/artifacts"

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

assert_file_exists() {
    if [ -f "$1" ]; then
        pass "$2"
    else
        fail "$2" "File not found: $1"
    fi
}

assert_zip_contains() {
    if grep -Fxq "$2" "$1"; then
        pass "$3"
    else
        fail "$3" "Missing ZIP path: $2"
    fi
}

assert_zip_not_contains() {
    if grep -Fxq "$2" "$1"; then
        fail "$3" "Unwanted ZIP path: $2"
    else
        pass "$3"
    fi
}

manifest_version() {
    grep -m1 -E '^  version:' "$1" | sed -E 's/.*"([^"]+)".*/\1/' | tr -d '[:space:]'
}

echo "=== Test Suite: catalog build ==="
echo ""

assert_file_exists "$SCRIPT_FILE" "build-catalog script exists"
[ -x "$SCRIPT_FILE" ] && pass "build-catalog script is executable" || fail "build-catalog script is executable"

if ! bash "$SCRIPT_FILE" >/dev/null; then
    fail "build-catalog script runs successfully"
    echo ""
    echo "=== Results ==="
    echo "Passed: $PASSED"
    echo "Failed: $FAILED"
    exit 1
fi
pass "build-catalog script runs successfully"

EXT_VERSION="$(manifest_version "$PROJECT_DIR/extension.yml")"
PRESET_VERSION="$(manifest_version "$PROJECT_DIR/preset.yml")"
BUNDLE_VERSION="$(manifest_version "$PROJECT_DIR/bundle.yml")"

EXT_ARTIFACT="$ARTIFACTS_DIR/extendedflow-$EXT_VERSION.zip"
PRESET_ARTIFACT="$ARTIFACTS_DIR/spec-kit-extended-flow-$PRESET_VERSION.zip"
BUNDLE_ARTIFACT="$ARTIFACTS_DIR/spec-kit-extended-flow-bundle-$BUNDLE_VERSION.zip"

assert_file_exists "$EXT_ARTIFACT" "extension artifact built"
assert_file_exists "$PRESET_ARTIFACT" "preset artifact built"
assert_file_exists "$BUNDLE_ARTIFACT" "bundle artifact built"

for artifact in "$EXT_ARTIFACT" "$PRESET_ARTIFACT" "$BUNDLE_ARTIFACT"; do
    if unzip -t "$artifact" >/dev/null 2>&1; then
        pass "integrity check passes for $(basename "$artifact")"
    else
        fail "integrity check passes for $(basename "$artifact")"
    fi
done

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
EXT_LIST="$TMP_DIR/ext.txt"
PRESET_LIST="$TMP_DIR/preset.txt"
BUNDLE_LIST="$TMP_DIR/bundle.txt"
unzip -Z1 "$EXT_ARTIFACT" > "$EXT_LIST"
unzip -Z1 "$PRESET_ARTIFACT" > "$PRESET_LIST"
unzip -Z1 "$BUNDLE_ARTIFACT" > "$BUNDLE_LIST"

assert_zip_contains "$EXT_LIST" "extension.yml" "extension archive has root extension.yml"
assert_zip_contains "$EXT_LIST" "commands/speckit.extendedflow.documentation.md" "extension archive has documentation command"
assert_zip_not_contains "$EXT_LIST" "commands/workflow-runtime.md" "extension archive excludes runtime preamble"
assert_zip_not_contains "$EXT_LIST" "scripts/resolve-spec.sh" "extension archive excludes preset scripts"

assert_zip_contains "$PRESET_LIST" "preset.yml" "preset archive has root preset.yml"
assert_zip_contains "$PRESET_LIST" "commands/workflow-runtime.md" "preset archive has runtime preamble"
assert_zip_contains "$PRESET_LIST" "templates/review-findings.md" "preset archive has review-findings template"
assert_zip_contains "$PRESET_LIST" "scripts/resolve-spec.sh" "preset archive has runtime scripts"
assert_zip_not_contains "$PRESET_LIST" "scripts/build-catalog.sh" "preset archive excludes build tooling"
assert_zip_not_contains "$PRESET_LIST" "extension.yml" "preset archive excludes extension manifest"

assert_zip_contains "$BUNDLE_LIST" "bundle.yml" "bundle archive has root bundle.yml"
assert_zip_contains "$BUNDLE_LIST" "README.md" "bundle archive has README"

assert_catalog_entry() {
    local file="$1"
    local section="$2"
    local component="$3"
    local version="$4"
    local artifact="$5"
    local result
    result="$(python3 - "$file" "$section" "$component" "$version" "$artifact" <<'PY'
import json
import sys

path, section, component, version, artifact = sys.argv[1:6]
with open(path, encoding="utf-8") as fh:
    data = json.load(fh)
entry = data.get(section, {}).get(component, {})
ok = entry.get("version") == version and str(entry.get("download_url", "")).endswith(artifact)
print("ok" if ok else f"version={entry.get('version')} url={entry.get('download_url')}")
PY
)"
    if [ "$result" = "ok" ]; then
        pass "catalog $section/$component pins $version and $artifact"
    else
        fail "catalog $section/$component pins $version and $artifact" "$result"
    fi
}

assert_catalog_entry "$CATALOG_DIR/extension-catalog.json" "extensions" "extendedflow" "$EXT_VERSION" "extendedflow-$EXT_VERSION.zip"
assert_catalog_entry "$CATALOG_DIR/preset-catalog.json" "presets" "spec-kit-extended-flow" "$PRESET_VERSION" "spec-kit-extended-flow-$PRESET_VERSION.zip"
assert_catalog_entry "$CATALOG_DIR/bundle-catalog.json" "bundles" "spec-kit-extended-flow" "$BUNDLE_VERSION" "spec-kit-extended-flow-bundle-$BUNDLE_VERSION.zip"

echo ""
echo "=== Results ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
