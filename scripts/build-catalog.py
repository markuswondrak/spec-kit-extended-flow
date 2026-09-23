#!/usr/bin/env python3
"""Build deterministic catalog component archives and synchronize version pins."""

import json
import re
import stat
import sys
import tempfile
import zipfile
from datetime import datetime, timezone
from pathlib import Path


RUNTIME_SCRIPTS = (
    "resolve-spec.py",
    "create-branch.py",
    "check-converge.py",
    "extract-verdict.py",
    "resolve-bug-context.py",
    "check-bug-verdict.py",
    "verify-spec.py",
    "init-quick.py",
    "resolve-pr-template.py",
    "load-models.py",
)

ZIP_TIMESTAMP = (1980, 1, 1, 0, 0, 0)
VERSION_PATTERN = re.compile(r'^  version:.*"([^"]+)"')


def error(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def info(message: str) -> None:
    print(f"==> {message}")


def manifest_version(path: Path) -> str:
    for line in path.read_text(encoding="utf-8").splitlines():
        match = VERSION_PATTERN.match(line)
        if match:
            return "".join(match.group(1).split())
    return ""


def zip_info(name: str, mode: int, is_directory: bool) -> zipfile.ZipInfo:
    info = zipfile.ZipInfo(name, ZIP_TIMESTAMP)
    info.create_system = 3
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = (mode & 0xFFFF) << 16
    if is_directory:
        info.external_attr |= 0x10
    return info


def write_archive(archive: Path, entries: dict[str, Path]) -> None:
    directories = set()
    for name in entries:
        parent = Path(name).parent
        while parent != Path("."):
            directories.add(f"{parent.as_posix()}/")
            parent = parent.parent

    archive_entries: dict[str, Path | None] = {directory: None for directory in directories}
    archive_entries.update(entries)

    with zipfile.ZipFile(
        archive,
        "w",
        compression=zipfile.ZIP_DEFLATED,
        compresslevel=9,
        strict_timestamps=True,
    ) as output:
        for name in sorted(archive_entries):
            source = archive_entries[name]
            if source is None:
                output.writestr(zip_info(name, 0o40755, True), b"")
                continue
            mode = stat.S_IMODE(source.stat().st_mode)
            output.writestr(zip_info(name, stat.S_IFREG | mode, False), source.read_bytes())

    with zipfile.ZipFile(archive) as output:
        invalid_entry = output.testzip()
    if invalid_entry is not None:
        error(f"Generated archive failed integrity check: {archive}")


def update_catalog_entry(
    catalog_path: Path,
    section: str,
    component_id: str,
    version: str,
    artifact: str,
) -> None:
    with catalog_path.open(encoding="utf-8") as source:
        catalog = json.load(source)

    entries = catalog.get(section, {})
    if not isinstance(entries, dict) or component_id not in entries:
        error(f"catalog entry '{section}.{component_id}' not found in {catalog_path}")

    entry = entries[component_id]
    entry["version"] = version
    entry["download_url"] = (
        "https://github.com/markuswondrak/spec-kit-extended-flow/releases/download/"
        f"v{version}/{artifact}"
    )
    with catalog_path.open("w", encoding="utf-8") as destination:
        json.dump(catalog, destination, indent=2)
        destination.write("\n")


def update_workflow_catalog(root: Path) -> None:
    catalog_path = root / "catalog" / "workflow-catalog.json"
    with catalog_path.open(encoding="utf-8") as source:
        catalog = json.load(source)

    workflow_files = {
        "spec-kit-extended-flow": "workflow.yml",
        "spec-kit-bugfix-flow": "bugfix-workflow.yml",
        "spec-kit-quick-flow": "quick-flow.yml",
    }
    for workflow_id, filename in workflow_files.items():
        version = manifest_version(root / "workflows" / filename)
        if not version or workflow_id not in catalog.get("workflows", {}):
            error(f"Could not synchronize workflow catalog entry: {workflow_id}")
        catalog["workflows"][workflow_id]["version"] = version
    catalog["updated_at"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with catalog_path.open("w", encoding="utf-8") as destination:
        json.dump(catalog, destination, indent=2)
        destination.write("\n")


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    output_directory = root / "catalog" / "artifacts"

    extension_version = manifest_version(root / "extension.yml")
    preset_version = manifest_version(root / "preset.yml")
    bundle_version = manifest_version(root / "bundle.yml")
    if not extension_version:
        error("Could not read version from extension.yml")
    if not preset_version:
        error("Could not read version from preset.yml")
    if not bundle_version:
        error("Could not read version from bundle.yml")

    extension_artifact = f"extendedflow-{extension_version}.zip"
    preset_artifact = f"spec-kit-extended-flow-{preset_version}.zip"
    bundle_artifact = f"spec-kit-extended-flow-bundle-{bundle_version}.zip"

    extension_entries = {"extension.yml": root / "extension.yml"}
    extension_commands = sorted((root / "commands").glob("speckit.extendedflow.*.md"))
    if not extension_commands:
        error("No extension commands found under commands/")
    for command in extension_commands:
        extension_entries[f"commands/{command.name}"] = command

    preset_entries = {"preset.yml": root / "preset.yml"}
    preset_entries["model.config.json"] = root / "model.config.json"
    for template in sorted((root / "templates").glob("*.md")):
        preset_entries[f"templates/{template.name}"] = template
    for script in RUNTIME_SCRIPTS:
        source = root / "scripts" / script
        if not source.is_file():
            error(f"Missing runtime script: scripts/{script}")
        preset_entries[f"scripts/{script}"] = source
    preset_entries["commands/workflow-runtime.md"] = root / "commands" / "workflow-runtime.md"

    bundle_entries = {
        "bundle.yml": root / "bundle.yml",
        "README.md": root / "README.md",
    }

    output_directory.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=output_directory) as temporary_directory:
        temporary_path = Path(temporary_directory)
        artifacts = (
            ("extension", extension_artifact, extension_entries),
            ("preset", preset_artifact, preset_entries),
            ("bundle", bundle_artifact, bundle_entries),
        )
        for component, artifact, entries in artifacts:
            info(f"Building {component} archive: {artifact}")
            archive = temporary_path / artifact
            write_archive(archive, entries)
            archive.replace(output_directory / artifact)

    info("Updating catalog version pins")
    update_catalog_entry(
        root / "catalog" / "extension-catalog.json",
        "extensions",
        "extendedflow",
        extension_version,
        extension_artifact,
    )
    update_catalog_entry(
        root / "catalog" / "preset-catalog.json",
        "presets",
        "spec-kit-extended-flow",
        preset_version,
        preset_artifact,
    )
    update_catalog_entry(
        root / "catalog" / "bundle-catalog.json",
        "bundles",
        "spec-kit-extended-flow",
        bundle_version,
        bundle_artifact,
    )
    update_workflow_catalog(root)

    print("\nBuilt catalog artifacts:")
    for artifact in sorted(output_directory.iterdir()):
        print(artifact.name)
    return 0


if __name__ == "__main__":
    main()
