#!/usr/bin/env python3
"""Verify that one release version is consistent across every bundle component."""

import json
import re
import sys
import zipfile
from pathlib import Path


SEMVER_PATTERN = re.compile(r"^v?([0-9]+)\.([0-9]+)\.([0-9]+)$")
TOP_LEVEL_VERSION_PATTERN = re.compile(r'^  version:.*"([^"]+)"')
BUNDLE_SECTIONS = ("extensions", "presets", "workflows")
MANIFEST_FILES = ("preset.yml", "extension.yml", "bundle.yml")
WORKFLOW_FILES = {
    "workflows/workflow.yml": "spec-kit-extended-flow",
    "workflows/bugfix-workflow.yml": "spec-kit-bugfix-flow",
    "workflows/quick-flow.yml": "spec-kit-quick-flow",
}
BUNDLE_PINS = {
    "extensions": ("extendedflow",),
    "presets": ("spec-kit-extended-flow",),
    "workflows": ("spec-kit-extended-flow", "spec-kit-bugfix-flow", "spec-kit-quick-flow"),
}
CATALOG_ENTRIES = (
    ("catalog/extension-catalog.json", "extensions", "extendedflow"),
    ("catalog/preset-catalog.json", "presets", "spec-kit-extended-flow"),
    ("catalog/bundle-catalog.json", "bundles", "spec-kit-extended-flow"),
)
WORKFLOW_CATALOG_IDS = ("spec-kit-extended-flow", "spec-kit-bugfix-flow", "spec-kit-quick-flow")


def info(message: str) -> None:
    print(f"==> {message}")


def report(failures: list[str]) -> None:
    for failure in failures:
        print(f"ERROR: {failure}", file=sys.stderr)
    if failures:
        raise SystemExit(1)


def manifest_version(path: Path) -> str:
    for line in path.read_text(encoding="utf-8").splitlines():
        match = TOP_LEVEL_VERSION_PATTERN.match(line)
        if match:
            return "".join(match.group(1).split())
    return ""


def bundle_pins(path: Path) -> dict[str, dict[str, str]]:
    pins: dict[str, dict[str, str]] = {section: {} for section in BUNDLE_SECTIONS}
    section = ""
    component_id = ""
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if line.startswith("  ") and not line.startswith("    ") and stripped.endswith(":"):
            section = stripped.rstrip(":")
            continue
        if section in pins and line.startswith("    - id: "):
            component_id = line.split('"')[1]
            continue
        if section in pins and line.startswith("      version: ") and component_id:
            pins[section][component_id] = line.split('"')[1]
    return pins


def check_manifests(root: Path, version: str, failures: list[str]) -> None:
    for name in MANIFEST_FILES:
        actual = manifest_version(root / name)
        if actual != version:
            failures.append(f"{name}: version is '{actual}', expected '{version}'")

    for relative, _workflow_id in WORKFLOW_FILES.items():
        actual = manifest_version(root / relative)
        if actual != version:
            failures.append(f"{relative}: version is '{actual}', expected '{version}'")

    pins = bundle_pins(root / "bundle.yml")
    for section, identifiers in BUNDLE_PINS.items():
        for component_id in identifiers:
            actual = pins.get(section, {}).get(component_id, "")
            if actual != version:
                failures.append(
                    f"bundle.yml {section}:{component_id} pin is '{actual}', expected '{version}'"
                )


def check_catalogs(root: Path, version: str, failures: list[str]) -> None:
    for relative, section, component_id in CATALOG_ENTRIES:
        path = root / relative
        if not path.is_file():
            failures.append(f"{relative}: catalog file not found")
            continue
        catalog = json.loads(path.read_text(encoding="utf-8"))
        entry = catalog.get(section, {}).get(component_id)
        if not isinstance(entry, dict):
            failures.append(f"{relative}: entry {section}.{component_id} not found")
            continue
        if entry.get("version") != version:
            failures.append(
                f"{relative}: {component_id} version is '{entry.get('version')}', expected '{version}'"
            )
        if f"/v{version}/" not in entry.get("download_url", ""):
            failures.append(
                f"{relative}: {component_id} download_url does not reference v{version}"
            )

    workflow_catalog_path = root / "catalog" / "workflow-catalog.json"
    if not workflow_catalog_path.is_file():
        failures.append("catalog/workflow-catalog.json: catalog file not found")
        return
    workflow_catalog = json.loads(workflow_catalog_path.read_text(encoding="utf-8"))
    for workflow_id in WORKFLOW_CATALOG_IDS:
        entry = workflow_catalog.get("workflows", {}).get(workflow_id)
        if not isinstance(entry, dict):
            failures.append(f"catalog/workflow-catalog.json: workflow {workflow_id} not found")
            continue
        if entry.get("version") != version:
            failures.append(
                f"catalog/workflow-catalog.json: {workflow_id} version is "
                f"'{entry.get('version')}', expected '{version}'"
            )


def check_archive(path: Path, failures: list[str]) -> None:
    if not path.is_file():
        failures.append(f"artifact not found: {path}")
        return
    try:
        with zipfile.ZipFile(path) as archive:
            if archive.testzip() is not None:
                failures.append(f"artifact failed integrity check: {path}")
    except zipfile.BadZipFile:
        failures.append(f"artifact is not a valid zip archive: {path}")


def check_artifacts(root: Path, version: str, failures: list[str]) -> None:
    expected = (
        root / "catalog" / "artifacts" / f"extendedflow-{version}.zip",
        root / "catalog" / "artifacts" / f"spec-kit-extended-flow-{version}.zip",
        root / "catalog" / "artifacts" / f"spec-kit-extended-flow-bundle-{version}.zip",
        root / "dist" / "spec-kit-extended-flow.zip",
    )
    for archive in expected:
        check_archive(archive, failures)


def main(arguments: list[str]) -> int:
    artifact_check = "--artifacts" in arguments
    positional = [argument for argument in arguments if not argument.startswith("--")]
    if len(positional) != 1:
        print("Usage: check-release.py <version> [--artifacts]", file=sys.stderr)
        return 1

    match = SEMVER_PATTERN.fullmatch(positional[0])
    if match is None:
        print(
            f"ERROR: Invalid version format: '{positional[0]}'. Expected semver: MAJOR.MINOR.PATCH",
            file=sys.stderr,
        )
        return 1
    version = ".".join(match.groups())

    root = Path(__file__).resolve().parent.parent
    failures: list[str] = []
    check_manifests(root, version, failures)
    check_catalogs(root, version, failures)
    if artifact_check:
        check_artifacts(root, version, failures)
    report(failures)

    scope = "manifests, workflows, and catalogs"
    if artifact_check:
        scope = f"{scope}, and artifacts"
    info(f"Release version {version} is consistent across {scope}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
